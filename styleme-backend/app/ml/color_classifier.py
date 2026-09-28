# StyleMe - Wrapper del modelo KMeans para clasificación de color
import logging
from typing import Optional

import numpy as np
import joblib
from pathlib import Path
from PIL import Image
from sklearn.cluster import KMeans

logger = logging.getLogger(__name__)

# Clasificación C2 del RGB dominante (versión de color 2).
# Umbrales calibrados con 31 prendas reales el 28-sep-2026 (fase P6b). La
# prueba de referencia (RGB del diagnóstico + colores puros) está en la
# verificación (b) de P6b: si se cambia un umbral, se debe volver a correr.
# L y croma en CIELAB (D65); tono = ángulo de (a, b) en grados.
COLOR_VERSION = 2
C2_NEGRO_L_MAX = 30         # a) L < 30 y croma < 16 → negro (negro fotografiado ≈ gris carbón)
C2_NEGRO_CROMA_MAX = 16
C2_ACROMATICO_CROMA_MAX = 10  # b) croma < 10 → acromático:
C2_BLANCO_L_MIN = 72        #    blanco si L ≥ 72,
C2_NEGRO_ACROM_L_MAX = 35   #    negro si L < 35, si no gris
C2_VERDE_TONO_MIN = 110     # c) croma ≥ 10 y tono en [110°, 200°] → verde
C2_VERDE_TONO_MAX = 200
C2_COLORES_ACROMATICOS = ("negro", "blanco", "gris")  # d) resto: ΔE2000 contra los demás centroides


def _srgb_a_lab(rgb01) -> np.ndarray:
    """sRGB en [0, 1] (…, 3) → CIELAB D65 (…, 3)."""
    c = np.asarray(rgb01, dtype=float)
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    m = np.array([
        [0.4124564, 0.3575761, 0.1804375],
        [0.2126729, 0.7151522, 0.0721750],
        [0.0193339, 0.1191920, 0.9503041],
    ])
    xyz = c @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 216 / 24389, np.cbrt(xyz), (24389 / 27 * xyz + 16) / 116)
    return np.stack([
        116 * f[..., 1] - 16,
        500 * (f[..., 0] - f[..., 1]),
        200 * (f[..., 1] - f[..., 2]),
    ], axis=-1)


def _delta_e2000(lab: np.ndarray, labs: np.ndarray) -> np.ndarray:
    """ΔE2000 entre un color Lab (3,) y varios (n, 3)."""
    l1, a1, b1 = lab
    l2, a2, b2 = labs[:, 0], labs[:, 1], labs[:, 2]
    c_media = (np.hypot(a1, b1) + np.hypot(a2, b2)) / 2
    g = 0.5 * (1 - np.sqrt(c_media ** 7 / (c_media ** 7 + 25 ** 7)))
    a1p, a2p = (1 + g) * a1, (1 + g) * a2
    c1p, c2p = np.hypot(a1p, b1), np.hypot(a2p, b2)
    h1p = np.degrees(np.arctan2(b1, a1p)) % 360
    h2p = np.degrees(np.arctan2(b2, a2p)) % 360
    sin_croma = (c1p * c2p) == 0

    dl = l2 - l1
    dc = c2p - c1p
    dh = h2p - h1p
    dh = np.where(dh > 180, dh - 360, np.where(dh < -180, dh + 360, dh))
    dh = np.where(sin_croma, 0, dh)
    dh_big = 2 * np.sqrt(c1p * c2p) * np.sin(np.radians(dh / 2))

    l_media = (l1 + l2) / 2
    cp_media = (c1p + c2p) / 2
    suma_h = h1p + h2p
    hp_media = np.where(
        sin_croma, suma_h,
        np.where(np.abs(h1p - h2p) > 180,
                 np.where(suma_h < 360, (suma_h + 360) / 2, (suma_h - 360) / 2),
                 suma_h / 2)
    )
    t = (1 - 0.17 * np.cos(np.radians(hp_media - 30))
         + 0.24 * np.cos(np.radians(2 * hp_media))
         + 0.32 * np.cos(np.radians(3 * hp_media + 6))
         - 0.20 * np.cos(np.radians(4 * hp_media - 63)))
    sl = 1 + 0.015 * (l_media - 50) ** 2 / np.sqrt(20 + (l_media - 50) ** 2)
    sc = 1 + 0.045 * cp_media
    sh = 1 + 0.015 * cp_media * t
    rt = (-2 * np.sqrt(cp_media ** 7 / (cp_media ** 7 + 25 ** 7))
          * np.sin(np.radians(60 * np.exp(-((hp_media - 275) / 25) ** 2))))
    return np.sqrt((dl / sl) ** 2 + (dc / sc) ** 2 + (dh_big / sh) ** 2
                   + rt * (dc / sc) * (dh_big / sh))


class ClasificadorColor:
    """
    Clasifica el color dominante de una prenda en 13 colores.
    Modelo: modelo_color.pkl (sus centroides son la paleta de referencia)
    13 colores: negro, blanco, gris, rojo, rosa, azul, azul marino,
                verde, amarillo, naranja, morado, beige, cafe

    Dos pasos:
    1. RGB dominante de la prenda (KMeans local de 3 clusters)
    2. RGB → nombre con la clasificación C2 (clasificar_rgb): reglas
       acromáticas y de tono en Lab + ΔE2000 contra los centroides
       cromáticos del .pkl. Reemplaza al predict() en RGB del .pkl, que
       mandaba el negro fotografiado a cafe y los blancos sombreados a beige.
    """

    # 13 colores que puede clasificar el modelo
    COLORES = [
        "negro", "blanco", "gris", "rojo", "rosa", "azul",
        "azul marino", "verde", "amarillo", "naranja", "morado",
        "beige", "cafe"
    ]

    def __init__(self):
        self.modelo_data = None
        self.cargado = False
        self._nombres_cromaticos = []
        self._lab_cromaticos = None

    def cargar(self, ruta_modelo: str):
        """Carga el modelo KMeans serializado con joblib."""
        try:
            ruta = Path(ruta_modelo)
            if not ruta.exists():
                raise FileNotFoundError(f"Modelo de color no encontrado en: {ruta_modelo}")

            self.modelo_data = joblib.load(str(ruta))

            # Paleta cromática en Lab para el paso d) de C2 (una sola vez)
            centroides = self.modelo_data["kmeans"].cluster_centers_
            mapa = self.modelo_data["cluster_a_color"]
            indices = [
                i for i in range(len(centroides))
                if mapa.get(i) not in C2_COLORES_ACROMATICOS
            ]
            self._nombres_cromaticos = [mapa[i] for i in indices]
            self._lab_cromaticos = _srgb_a_lab(centroides[indices])

            self.cargado = True

            logger.info(f"✅ Modelo Color cargado: {ruta_modelo}")
            logger.info(f"   Versión: {self.modelo_data.get('version', 'N/A')}")
            logger.info(f"   Colores: {self.modelo_data.get('n_clusters', 13)}")
            logger.info(f"   Clasificación: C2 (versión de color {COLOR_VERSION})")

        except Exception as e:
            logger.error(f"❌ Error cargando modelo de color: {e}")
            raise

    def clasificar_rgb(self, rgb01) -> str:
        """
        Clasificación C2 de un RGB en [0, 1] a uno de los 13 colores.
        Orden: a) negro oscuro → b) acromático → c) verde por tono →
        d) ΔE2000 contra los centroides cromáticos del .pkl.
        """
        if not self.cargado:
            raise RuntimeError("El modelo de color no está cargado")

        lab = _srgb_a_lab(np.clip(np.asarray(rgb01, dtype=float), 0.0, 1.0))
        l, a, b = lab
        croma = float(np.hypot(a, b))
        tono = float(np.degrees(np.arctan2(b, a)) % 360)

        if l < C2_NEGRO_L_MAX and croma < C2_NEGRO_CROMA_MAX:
            return "negro"
        if croma < C2_ACROMATICO_CROMA_MAX:
            if l >= C2_BLANCO_L_MIN:
                return "blanco"
            return "negro" if l < C2_NEGRO_ACROM_L_MAX else "gris"
        if C2_VERDE_TONO_MIN <= tono <= C2_VERDE_TONO_MAX:
            return "verde"
        distancias = _delta_e2000(lab, self._lab_cromaticos)
        return self._nombres_cromaticos[int(np.argmin(distancias))]

    def color_dominante(self, imagen_pil: Image.Image) -> np.ndarray:
        """
        RGB dominante [0, 1] de un recorte sin máscara (respaldo).

        Proceso:
        1. Redimensionar imagen a 80x80
        2. Filtrar píxeles de fondo blanco
        3. KMeans con 3 clusters; centro del cluster más grande
        """
        img = imagen_pil.convert("RGB").resize((80, 80))
        pixels = np.array(img).reshape(-1, 3) / 255.0

        # Filtrar fondo blanco (píxeles muy claros)
        mask = ~(
            (pixels[:, 0] > 0.88) &
            (pixels[:, 1] > 0.88) &
            (pixels[:, 2] > 0.88)
        )
        pixels_filtrados = pixels[mask] if mask.sum() > 10 else pixels

        # KMeans local con 3 clusters para encontrar colores dominantes
        km_local = KMeans(
            n_clusters=3,
            random_state=42,
            n_init=5,
            max_iter=100
        )
        km_local.fit(pixels_filtrados)

        # Encontrar el cluster más grande (color dominante)
        conteos = np.bincount(km_local.labels_)
        return km_local.cluster_centers_[np.argmax(conteos)]

    def color_dominante_mascara(
        self,
        imagen_rgba: Image.Image,
        umbral_alfa: int = 128,
        lado_max: int = 100,
        min_fraccion: float = 0.03,
        min_pixeles: int = 300
    ) -> Optional[np.ndarray]:
        """
        RGB dominante [0, 1] usando solo los píxeles de la prenda según el
        canal alfa (recorte de ML Kit o de rembg), sin fondo ni sombras.

        Proceso:
        1. Validar la máscara (alfa > umbral_alfa) a resolución completa
        2. Reducir a máx. lado_max px con NEAREST (no mezcla el RGB
           indefinido de los píxeles transparentes con los de la prenda)
        3. KMeans con 3 clusters SOLO sobre los píxeles enmascarados,
           sin excluir los casi blancos (una prenda blanca es blanca)

        Returns:
            RGB del centro del cluster mayor, o None si la máscara tiene
            menos de min_fraccion del área o menos de min_pixeles (el
            llamador debe usar el recorte como respaldo).
        """
        img = imagen_rgba.convert("RGBA")
        alfa = np.array(img.getchannel("A"))
        n_mascara = int((alfa > umbral_alfa).sum())
        if n_mascara < min_pixeles or n_mascara < min_fraccion * alfa.size:
            return None

        img = img.copy()
        img.thumbnail((lado_max, lado_max), Image.NEAREST)
        rgba = np.array(img).reshape(-1, 4)
        pixels = rgba[rgba[:, 3] > umbral_alfa][:, :3] / 255.0
        if len(pixels) < 3:
            return None

        km_local = KMeans(
            n_clusters=3,
            random_state=42,
            n_init=5,
            max_iter=100
        )
        km_local.fit(pixels)

        conteos = np.bincount(km_local.labels_)
        return km_local.cluster_centers_[np.argmax(conteos)]

    def predecir(self, imagen_pil: Image.Image) -> str:
        """
        Color de una prenda a partir de un recorte sin máscara (respaldo del
        alta y modo invitado): color_dominante() → clasificar_rgb() (C2).

        Returns:
            str: Nombre del color clasificado ("negro" si hay error)
        """
        if not self.cargado:
            raise RuntimeError("El modelo de color no está cargado")

        try:
            return self.clasificar_rgb(self.color_dominante(imagen_pil))
        except Exception as e:
            logger.error(f"❌ Error en clasificación de color: {e}")
            return "negro"  # Color por defecto si hay error

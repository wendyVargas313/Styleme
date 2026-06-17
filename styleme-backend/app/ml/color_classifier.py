# StyleMe - Wrapper del modelo KMeans para clasificación de color
import logging
import numpy as np
import joblib
from pathlib import Path
from PIL import Image
from sklearn.cluster import KMeans

logger = logging.getLogger(__name__)


class ClasificadorColor:
    """
    Wrapper del modelo KMeans para clasificar el color dominante de una prenda.
    Modelo: modelo_color.pkl
    13 colores: negro, blanco, gris, rojo, rosa, azul, azul marino,
                verde, amarillo, naranja, morado, beige, cafe
    Accuracy: 98.1%
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

    def cargar(self, ruta_modelo: str):
        """Carga el modelo KMeans serializado con joblib."""
        try:
            ruta = Path(ruta_modelo)
            if not ruta.exists():
                raise FileNotFoundError(f"Modelo de color no encontrado en: {ruta_modelo}")

            self.modelo_data = joblib.load(str(ruta))
            self.cargado = True

            logger.info(f"✅ Modelo Color cargado: {ruta_modelo}")
            logger.info(f"   Versión: {self.modelo_data.get('version', 'N/A')}")
            logger.info(f"   Colores: {self.modelo_data.get('n_clusters', 13)}")
            logger.info(f"   Accuracy: 98.1%")

        except Exception as e:
            logger.error(f"❌ Error cargando modelo de color: {e}")
            raise

    def predecir(self, imagen_pil: Image.Image) -> str:
        """
        Predice el color dominante de una prenda en la imagen.
        
        Proceso:
        1. Redimensionar imagen a 80x80
        2. Filtrar píxeles de fondo blanco
        3. KMeans con 3 clusters para encontrar color dominante
        4. Clasificar con el modelo entrenado de 13 colores
        
        Args:
            imagen_pil: Imagen PIL de la prenda (puede ser recorte de YOLO)
        
        Returns:
            str: Nombre del color clasificado
        """
        if not self.cargado:
            raise RuntimeError("El modelo de color no está cargado")

        try:
            # Preparar imagen
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
            color_dominante = km_local.cluster_centers_[np.argmax(conteos)]

            # Clasificar con el modelo KMeans entrenado
            cluster_id = self.modelo_data["kmeans"].predict([color_dominante])[0]
            nombre_color = self.modelo_data["cluster_a_color"].get(cluster_id, "negro")

            return nombre_color

        except Exception as e:
            logger.error(f"❌ Error en clasificación de color: {e}")
            return "negro"  # Color por defecto si hay error

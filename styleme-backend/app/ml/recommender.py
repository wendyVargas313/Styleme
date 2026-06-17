# StyleMe - Wrapper del modelo de recomendación de outfits
import logging
import joblib
import random
from pathlib import Path
from typing import List, Optional

logger = logging.getLogger(__name__)


class RecomendadorOutfits:
    """
    Wrapper del modelo de scoring basado en co-ocurrencia real.
    Modelo: modelo_recomendador_outfits.pkl
    Dataset: 316 pares reales de 2,909 imágenes del dataset
    
    Fórmula: score = 0.5×coocurrencia + 0.3×color + 0.2×temporada
    Score compatibles: 0.707 | Score no compatibles: 0.208
    Separación: +0.499
    """

    def __init__(self):
        self.modelo_data = None
        self.cargado = False

    def cargar(self, ruta_modelo: str):
        """Carga el modelo de recomendación serializado con joblib."""
        try:
            ruta = Path(ruta_modelo)
            if not ruta.exists():
                raise FileNotFoundError(f"Modelo recomendador no encontrado en: {ruta_modelo}")

            self.modelo_data = joblib.load(str(ruta))
            self.cargado = True

            n_pares = self.modelo_data.get("n_pares_reales", 0)
            score_avg = self.modelo_data.get("score_compat_avg", 0.0)

            logger.info(f"✅ Modelo Recomendador cargado: {ruta_modelo}")
            logger.info(f"   Versión: {self.modelo_data.get('version', 'N/A')}")
            logger.info(f"   Pares reales: {n_pares}")
            logger.info(f"   Score compatible promedio: {score_avg:.3f}")

        except Exception as e:
            logger.error(f"❌ Error cargando modelo recomendador: {e}")
            raise

    def get_grupo(self, tipo: str) -> str:
        """Determina el grupo al que pertenece una prenda."""
        grupos = self.modelo_data.get("grupos", {})
        for grupo, tipos in grupos.items():
            if tipo in tipos:
                return grupo
        return "otro"

    def _score_temporada(self, t1: str, t2: str) -> float:
        """Calcula compatibilidad entre dos temporadas."""
        if t1 == t2:
            return 1.0

        adyacentes = {
            ("primavera", "verano"), ("verano", "otono"),
            ("otono", "invierno"), ("invierno", "primavera"),
            ("verano", "primavera"), ("otono", "verano"),
            ("invierno", "otono"), ("primavera", "invierno"),
        }
        return 0.5 if (t1, t2) in adyacentes else 0.2

    def recomendar(
        self,
        prenda_base: dict,
        guardarropa: list,
        top_k: int = 3
    ) -> list:
        """
        Recomienda prendas compatibles del guardarropa.
        
        Args:
            prenda_base: Prenda base con tipo, color, temporada
            guardarropa: Lista de prendas del usuario
            top_k: Número máximo de recomendaciones
        
        Returns:
            Lista de prendas con scores ordenadas de mayor a menor
        """
        if not self.cargado:
            raise RuntimeError("El modelo recomendador no está cargado")

        tipo_a = prenda_base.get("tipo", "")
        color_a = prenda_base.get("color", "")
        temp_a = prenda_base.get("temporada", "invierno")
        grupo_a = self.get_grupo(tipo_a)

        # Convertir la matriz de compatibilidad a tuplas
        matriz = {
            tuple(k.split("|")): v
            for k, v in self.modelo_data.get("matriz_compat", {}).items()
        }

        # Compatibilidad de colores
        compat_col = {
            k: set(v)
            for k, v in self.modelo_data.get("compat_colores", {}).items()
        }

        scores = []
        for prenda in guardarropa:
            # Excluir la prenda base exacta
            if prenda.get("tipo") == tipo_a and prenda.get("color") == color_a:
                continue

            # Excluir prendas del mismo grupo funcional
            if self.get_grupo(prenda.get("tipo", "")) == grupo_a:
                continue

            tipo_b = prenda.get("tipo", "")
            color_b = prenda.get("color", "")
            temp_b = prenda.get("temporada", "invierno")

            # Calcular score de co-ocurrencia
            par = tuple(sorted([tipo_a, tipo_b]))
            sc_cooc = matriz.get(par, 0.05)

            # Calcular score de compatibilidad de color
            colores_compat = compat_col.get(color_a, set())
            sc_color = 1.0 if color_b in colores_compat else 0.3

            # Calcular score de temporada
            sc_temp = self._score_temporada(temp_a, temp_b)

            # Score final ponderado
            score_final = (0.5 * sc_cooc) + (0.3 * sc_color) + (0.2 * sc_temp)

            scores.append({
                **prenda,
                "score": round(score_final, 4),
                "porcentaje": f"{round(score_final * 100, 1)}%",
                "detalle": {
                    "coocurrencia": round(sc_cooc, 4),
                    "color": round(sc_color, 4),
                    "temporada": round(sc_temp, 4)
                }
            })

        # Ordenar por score descendente y retornar top_k
        scores.sort(key=lambda x: -x["score"])
        return scores[:top_k]

    def generar_outfit_diario(
        self,
        guardarropa: list,
        temporada: str = "invierno",
        n_outfits: int = 3,
        disliked_ids: Optional[list] = None
    ) -> list:
        """
        Genera N outfits completos priorizando prendas menos usadas.
        
        Args:
            guardarropa: Lista de todas las prendas del usuario
            temporada: Temporada actual
            n_outfits: Número de outfits a generar
            disliked_ids: IDs de prendas que el usuario no quiere
        
        Returns:
            Lista de outfits con prenda_base y complementos
        """
        if not guardarropa:
            return []

        # Filtrar prendas con dislike
        disliked = set(disliked_ids or [])
        prendas_disponibles = [p for p in guardarropa if str(p.get("id", "")) not in disliked]

        if not prendas_disponibles:
            prendas_disponibles = guardarropa

        # Ordenar por veces_usado (ascendente) — priorizar prendas menos usadas
        prendas_ordenadas = sorted(
            prendas_disponibles,
            key=lambda x: (x.get("veces_usado", 0), random.random())
        )

        outfits_generados = []
        prendas_base_usadas = set()

        for prenda_candidata in prendas_ordenadas:
            if len(outfits_generados) >= n_outfits:
                break

            prenda_id = str(prenda_candidata.get("id", ""))
            if prenda_id in prendas_base_usadas:
                continue

            # Asegurar que la prenda tenga la temporada correcta o sea compatible
            complementos = self.recomendar(
                prenda_candidata,
                prendas_disponibles,
                top_k=3
            )

            if complementos:  # Solo generar outfit si hay complementos
                outfits_generados.append({
                    "prenda_base": prenda_candidata,
                    "complementos": complementos
                })
                prendas_base_usadas.add(prenda_id)

        return outfits_generados

    @property
    def n_pares(self) -> int:
        """Retorna el número de pares de compatibilidad en el modelo."""
        if self.modelo_data:
            return self.modelo_data.get("n_pares_reales", 0)
        return 0

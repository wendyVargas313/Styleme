# StyleMe - Agente ML Central (Singleton)
# Orquesta los 3 modelos: YOLO + KMeans Color + Recomendador
import logging
import os
from datetime import datetime
from pathlib import Path
from typing import Optional

from app.ml.detector import DetectorPrendas
from app.ml.color_classifier import ClasificadorColor
from app.ml.recommender import RecomendadorOutfits
from app.config.settings import settings

logger = logging.getLogger(__name__)


class StyleMeAgent:
    """
    Agente ML central de StyleMe.
    Singleton que orquesta los 3 modelos ML.
    Se inicializa al arrancar FastAPI (lifespan).
    NUNCA recargar los modelos por request — demasiado lento.
    """

    _instance = None
    _initialized = False

    def __new__(cls):
        """Implementación del patrón Singleton."""
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        """Constructor — solo se ejecuta una vez por el Singleton."""
        if not self._initialized:
            self.detector = DetectorPrendas()
            self.color_clf = ClasificadorColor()
            self.recomendador = RecomendadorOutfits()
            self.inicializado_en = None
            StyleMeAgent._initialized = True

    async def initialize(self):
        """
        Carga los 3 modelos en memoria al arrancar el servidor.
        Se llama desde el lifespan de FastAPI.
        """
        logger.info("🤖 Iniciando StyleMe ML Agent...")
        modelos_path = Path(settings.ML_MODELS_PATH)

        try:
            # Cargar YOLO (detección de prendas)
            logger.info("📦 Cargando modelo YOLO...")
            self.detector.cargar(str(modelos_path / "styleme_detector.pt"))

            # Cargar KMeans de color
            logger.info("🎨 Cargando modelo de colores...")
            self.color_clf.cargar(str(modelos_path / "modelo_color.pkl"))

            # Cargar recomendador de outfits
            logger.info("👗 Cargando modelo recomendador...")
            self.recomendador.cargar(str(modelos_path / "modelo_recomendador_outfits.pkl"))

            self.inicializado_en = datetime.utcnow()

            logger.info("✅ StyleMe ML Agent inicializado correctamente")
            logger.info(f"   YOLO: {len(self.detector.modelo.names)} clases de prendas")
            logger.info(f"   Color: {self.color_clf.modelo_data.get('n_clusters', 13)} colores")
            logger.info(f"   Recomendador: {self.recomendador.n_pares} pares reales")

        except Exception as e:
            logger.error(f"❌ Error inicializando ML Agent: {e}")
            raise

    async def procesar_imagen(self, imagen_bytes: bytes) -> dict:
        """
        Pipeline completo de procesamiento de imagen.
        imagen → YOLO (detección) → recorte → KMeans (color) → resultado
        
        Args:
            imagen_bytes: Imagen en bytes (JPG/PNG)
        
        Returns:
            dict con tipo, color, confianza, bbox
        """
        # Paso 1: Detección con YOLO
        resultado_yolo = self.detector.detectar(imagen_bytes, conf=0.25)

        tipo = resultado_yolo.get("tipo", "not sure")
        confianza = resultado_yolo.get("confianza", 0.0)
        bbox = resultado_yolo.get("bbox", [])
        imagen_pil = resultado_yolo.get("imagen_pil")

        # Paso 2: Recortar la prenda si hay bbox
        if bbox and imagen_pil:
            imagen_recortada = self.detector.recortar_prenda(imagen_pil, bbox)
        elif imagen_pil:
            imagen_recortada = imagen_pil
        else:
            from PIL import Image
            import io
            imagen_recortada = Image.open(io.BytesIO(imagen_bytes)).convert("RGB")

        # Paso 3: Clasificar color de la prenda recortada
        color = self.color_clf.predecir(imagen_recortada)

        return {
            "tipo": tipo,
            "color": color,
            "confianza": confianza,
            "bbox": bbox,
            "detectado": resultado_yolo.get("detectado", False),
            "todas_detecciones": resultado_yolo.get("todas_detecciones", [])
        }

    async def recomendar_outfit(
        self,
        prenda_base: dict,
        guardarropa: list,
        top_k: int = 3
    ) -> list:
        """
        Calcula compatibilidad y retorna top_k recomendaciones de prendas.
        
        Args:
            prenda_base: Prenda principal con tipo, color, temporada
            guardarropa: Lista de prendas disponibles del usuario
            top_k: Número de recomendaciones
        
        Returns:
            Lista de dicts con tipo, color, temporada, score, porcentaje, detalle
        """
        return self.recomendador.recomendar(prenda_base, guardarropa, top_k)

    async def generar_outfit_diario(
        self,
        guardarropa: list,
        temporada: str = "invierno",
        disliked_ids: Optional[list] = None
    ) -> list:
        """
        Genera 3 outfits completos del día.
        Selecciona prendas base priorizando las menos usadas.
        
        Args:
            guardarropa: Lista de todas las prendas del usuario
            temporada: Temporada actual
            disliked_ids: IDs de prendas no deseadas
        
        Returns:
            Lista de 3 outfits con prenda_base y complementos
        """
        return self.recomendador.generar_outfit_diario(
            guardarropa,
            temporada=temporada,
            n_outfits=3,
            disliked_ids=disliked_ids
        )

    def get_status(self) -> dict:
        """
        Retorna el estado del agente para el health check.
        
        Returns:
            dict con estado de cada modelo y metadata
        """
        return {
            "yolo_loaded": self.detector.cargado,
            "color_loaded": self.color_clf.cargado,
            "rec_loaded": self.recomendador.cargado,
            "yolo_classes": len(self.detector.modelo.names) if self.detector.cargado else 0,
            "color_classes": self.color_clf.modelo_data.get("n_clusters", 0) if self.color_clf.cargado else 0,
            "rec_pairs": self.recomendador.n_pares,
            "initialized_at": self.inicializado_en.isoformat() if self.inicializado_en else None
        }


# Instancia global del agente (Singleton)
ml_agent = StyleMeAgent()

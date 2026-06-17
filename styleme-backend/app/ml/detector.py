# StyleMe - Wrapper del modelo YOLO para detección de prendas
import logging
import io
from pathlib import Path
from PIL import Image
from ultralytics import YOLO

logger = logging.getLogger(__name__)


class DetectorPrendas:
    """
    Wrapper del modelo YOLOv8 para detección y clasificación de prendas.
    Modelo: styleme_detector.pt
    Dataset: Clothing-Detection-6 (8,359 imágenes)
    20 clases de prendas de vestir
    """

    # 20 clases del modelo YOLO entrenado
    CLASES = [
        "T-shirt", "blazer", "blouse", "body", "dress", "glove",
        "hat", "hoodie", "long sleeve", "not sure", "other",
        "outwear", "pants", "polo", "shirt", "shoe", "shorts",
        "skirt", "top", "undershirt"
    ]

    def __init__(self):
        self.modelo = None
        self.cargado = False

    def cargar(self, ruta_modelo: str):
        """Carga el modelo YOLO desde el archivo .pt"""
        try:
            ruta = Path(ruta_modelo)
            if not ruta.exists():
                raise FileNotFoundError(f"Modelo YOLO no encontrado en: {ruta_modelo}")

            self.modelo = YOLO(str(ruta))
            self.cargado = True

            logger.info(f"✅ Modelo YOLO cargado: {ruta_modelo}")
            logger.info(f"   Clases: {len(self.modelo.names)} tipos de prenda")
            logger.info(f"   mAP50: 65.9% | Precision: 72.4% | Recall: 63.9%")

        except Exception as e:
            logger.error(f"❌ Error cargando modelo YOLO: {e}")
            raise

    def detectar(self, imagen_bytes: bytes, conf: float = 0.25) -> dict:
        """
        Detecta prendas en una imagen.
        
        Args:
            imagen_bytes: Imagen en bytes (JPG/PNG)
            conf: Umbral de confianza mínimo (0.25 por defecto)
        
        Returns:
            dict con tipo, confianza, bbox y todas las detecciones
        """
        if not self.cargado:
            raise RuntimeError("El modelo YOLO no está cargado")

        try:
            # Convertir bytes a imagen PIL
            imagen_pil = Image.open(io.BytesIO(imagen_bytes)).convert("RGB")

            # Ejecutar predicción (verbose=False para no llenar logs)
            resultados = self.modelo.predict(imagen_pil, conf=conf, verbose=False)

            # Procesar resultados
            if not resultados or len(resultados[0].boxes) == 0:
                # Si no detecta nada, retornar resultado vacío
                return {
                    "detectado": False,
                    "tipo": "not sure",
                    "color": "negro",
                    "confianza": 0.0,
                    "bbox": [],
                    "todas_detecciones": []
                }

            # Tomar la detección con mayor confianza
            boxes = resultados[0].boxes
            mejor_idx = boxes.conf.argmax().item()

            tipo = self.modelo.names[int(boxes.cls[mejor_idx])]
            confianza = float(boxes.conf[mejor_idx])
            bbox = boxes.xyxy[mejor_idx].tolist()

            # Todas las detecciones ordenadas por confianza
            todas = []
            for i in range(len(boxes)):
                todas.append({
                    "tipo": self.modelo.names[int(boxes.cls[i])],
                    "confianza": round(float(boxes.conf[i]), 4),
                    "bbox": boxes.xyxy[i].tolist()
                })
            todas.sort(key=lambda x: -x["confianza"])

            return {
                "detectado": True,
                "tipo": tipo,
                "confianza": round(confianza, 4),
                "bbox": bbox,
                "todas_detecciones": todas,
                "imagen_pil": imagen_pil  # Para uso interno del color classifier
            }

        except Exception as e:
            logger.error(f"❌ Error en detección YOLO: {e}")
            raise

    def recortar_prenda(self, imagen_pil: Image.Image, bbox: list) -> Image.Image:
        """
        Recorta la región de la prenda detectada de la imagen.
        
        Args:
            imagen_pil: Imagen PIL original
            bbox: Bounding box [x1, y1, x2, y2]
        
        Returns:
            Imagen PIL recortada con la prenda
        """
        if not bbox:
            return imagen_pil

        try:
            x1, y1, x2, y2 = [int(v) for v in bbox]
            # Asegurar que los valores sean válidos
            x1 = max(0, x1)
            y1 = max(0, y1)
            x2 = min(imagen_pil.width, x2)
            y2 = min(imagen_pil.height, y2)

            return imagen_pil.crop((x1, y1, x2, y2))
        except Exception:
            return imagen_pil

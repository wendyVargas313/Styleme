# app/services/imagen_service.py
import io
import logging

from PIL import Image, ImageOps

logger = logging.getLogger(__name__)


def normalizar_orientacion(datos: bytes) -> bytes:
    """
    Corrige la orientación EXIF de una imagen recién subida por el cliente.
    Muchas fotos de celular guardan la rotación real solo en los metadatos
    EXIF y dejan los píxeles "acostados"; sin esta corrección, YOLO recibía
    prendas giradas y fallaba la detección/el recorte.
    """
    try:
        img = Image.open(io.BytesIO(datos))
        orientacion = img.getexif().get(0x0112)

        if orientacion is None or orientacion == 1:
            return datos

        img = ImageOps.exif_transpose(img)
        if img.mode != "RGB":
            img = img.convert("RGB")

        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=95)
        return buf.getvalue()

    except Exception as e:
        logger.warning(f"No se pudo normalizar la orientación EXIF: {e}")
        return datos

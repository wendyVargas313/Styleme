# StyleMe - Controlador de Guardarropa
import io
import logging
import os
import uuid
from pathlib import Path
from datetime import datetime
from PIL import Image
from bson import ObjectId
from fastapi import HTTPException, status, UploadFile

from app.config.database import get_db
from app.config.settings import settings
from app.models.prenda_model import PrendaModel
from app.ml.ml_agent import ml_agent

logger = logging.getLogger(__name__)

# Extensiones permitidas
EXTENSIONES_PERMITIDAS = {".jpg", ".jpeg", ".png"}
TIPOS_MIME_PERMITIDOS = {"image/jpeg", "image/jpg", "image/png"}


async def validar_imagen(imagen: UploadFile) -> bytes:
    """
    Valida que la imagen tenga el formato correcto y no exceda el tamaño máximo.
    
    Returns:
        bytes: Contenido de la imagen si es válida
    
    Raises:
        HTTPException: Si la imagen no es válida
    """
    # Verificar tipo MIME
    content_type = imagen.content_type or ""
    if content_type not in TIPOS_MIME_PERMITIDOS:
        extension = Path(imagen.filename or "").suffix.lower()
        if extension not in EXTENSIONES_PERMITIDAS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Formato no permitido. Solo se acepta JPG/PNG"
            )

    # Leer contenido
    contenido = await imagen.read()

    # Verificar tamaño
    tamanio_mb = len(contenido) / (1024 * 1024)
    if tamanio_mb > settings.MAX_IMAGE_SIZE_MB:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Imagen demasiado grande. Máximo {settings.MAX_IMAGE_SIZE_MB}MB"
        )

    return contenido


def generar_imagen_tarjeta(imagen_bytes: bytes, bbox: list, padding_pct: float = 0.12) -> bytes:
    """
    Recorta la prenda detectada por YOLO, elimina el fondo
    con rembg y la centra sobre fondo blanco 512x512.

    Flujo:
    1. Abrir imagen original
    2. Recortar bbox de YOLO con margen
    3. Quitar fondo con rembg (imagen RGBA con transparencia)
    4. Pegar sobre fondo blanco 512x512
    """
    from rembg import remove as rembg_remove

    # Paso 1: abrir imagen
    img = Image.open(io.BytesIO(imagen_bytes)).convert("RGB")

    # Paso 2: recortar bbox de YOLO con margen
    if bbox and len(bbox) == 4:
        x1, y1, x2, y2 = [int(v) for v in bbox]
        pad_x = int((x2 - x1) * padding_pct)
        pad_y = int((y2 - y1) * padding_pct)
        x1 = max(0, x1 - pad_x)
        y1 = max(0, y1 - pad_y)
        x2 = min(img.width, x2 + pad_x)
        y2 = min(img.height, y2 + pad_y)
        img = img.crop((x1, y1, x2, y2))

    # Paso 3: quitar fondo con rembg
    # rembg recibe bytes PNG y devuelve imagen PNG con canal alpha
    try:
        buf_entrada = io.BytesIO()
        img.save(buf_entrada, format="PNG")
        buf_entrada.seek(0)

        resultado_bytes = rembg_remove(buf_entrada.read())
        img_sin_fondo = Image.open(io.BytesIO(resultado_bytes)).convert("RGBA")

    except Exception as e:
        # Si rembg falla, usar imagen recortada sin quitar fondo
        logger.warning(f"rembg falló, usando recorte simple: {e}")
        img_sin_fondo = img.convert("RGBA")

    # Paso 4: centrar sobre fondo blanco 512x512
    size = 512
    fondo = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    img_sin_fondo.thumbnail((size, size), Image.LANCZOS)
    offset_x = (size - img_sin_fondo.width) // 2
    offset_y = (size - img_sin_fondo.height) // 2

    # Pegar usando el canal alpha como máscara para bordes suaves
    fondo.paste(img_sin_fondo, (offset_x, offset_y), mask=img_sin_fondo.split()[3])

    # Convertir a RGB y guardar como JPEG
    fondo_rgb = fondo.convert("RGB")
    buf_salida = io.BytesIO()
    fondo_rgb.save(buf_salida, format="JPEG", quality=92)
    return buf_salida.getvalue()


async def guardar_imagen_local(
    contenido: bytes,
    usuario_id: str,
    nombre_original: str
) -> str:
    """
    Guarda la imagen en el sistema de archivos local.
    Organizada por usuario: /uploads/{usuario_id}/
    
    Returns:
        str: URL relativa de la imagen guardada
    """
    # Crear directorio del usuario si no existe
    directorio_usuario = Path(settings.UPLOADS_PATH) / usuario_id
    directorio_usuario.mkdir(parents=True, exist_ok=True)

    # Generar nombre único para la imagen (siempre .jpg tras el procesado)
    nombre_archivo = f"prenda_{uuid.uuid4().hex[:12]}.jpg"
    ruta_completa = directorio_usuario / nombre_archivo

    # Guardar imagen
    with open(ruta_completa, "wb") as f:
        f.write(contenido)

    # Retornar URL relativa
    return f"/uploads/{usuario_id}/{nombre_archivo}"


async def agregar_prenda(
    usuario_id: str,
    imagen_bytes: bytes,
    nombre_imagen: str,
    temporada: str,
    notas: str,
    db
) -> dict:
    """
    Agrega una nueva prenda al guardarropa del usuario.
    
    Proceso:
    1. Procesar imagen con el agente ML (YOLO + KMeans)
    2. Guardar imagen en /uploads/
    3. Crear documento en MongoDB
    
    Returns:
        dict con éxito y datos de la prenda detectada
    """
    # Procesar imagen con ML
    logger.info(f"🔍 Procesando imagen con ML para usuario {usuario_id}")
    resultado_ml = await ml_agent.procesar_imagen(imagen_bytes)

    tipo = resultado_ml.get("tipo", "other")
    color = resultado_ml.get("color", "negro")
    confianza = resultado_ml.get("confianza", 0.0)
    bbox = resultado_ml.get("bbox", [])

    logger.info(f"   Tipo detectado: {tipo} ({confianza:.1%})")
    logger.info(f"   Color detectado: {color}")

    # Recortar prenda y colocar en tarjeta fondo blanco
    imagen_tarjeta = generar_imagen_tarjeta(imagen_bytes, bbox)
    logger.info("   Imagen procesada: recorte + fondo blanco 512x512")

    # Guardar imagen procesada localmente
    imagen_url = await guardar_imagen_local(imagen_tarjeta, usuario_id, nombre_imagen)

    # Crear documento de prenda
    nueva_prenda = PrendaModel.crear(
        usuario_id=usuario_id,
        tipo=tipo,
        color=color,
        temporada=temporada,
        confianza_yolo=confianza,
        imagen_url=imagen_url,
        notas=notas
    )

    # Insertar en MongoDB
    resultado = await db.prendas.insert_one(nueva_prenda)
    prenda_id = str(resultado.inserted_id)

    logger.info(f"✅ Prenda guardada: {prenda_id}")

    return {
        "success": True,
        "prenda": {
            "id": prenda_id,
            "tipo": tipo,
            "color": color,
            "temporada": temporada,
            "confianza_yolo": confianza,
            "imagen_url": imagen_url,
            "notas": notas,
            "creado_en": nueva_prenda["creado_en"].isoformat()
        }
    }


async def listar_prendas(
    usuario_id: str,
    tipo: str = None,
    color: str = None,
    temporada: str = None,
    page: int = 1,
    limit: int = 20,
    db=None
) -> dict:
    """
    Lista las prendas del guardarropa con filtros opcionales y paginación.
    
    Returns:
        dict con total, página actual y lista de prendas
    """
    # Construir filtro
    filtro = {
        "usuario_id": ObjectId(usuario_id),
        "activa": True
    }

    if tipo:
        filtro["tipo"] = tipo
    if color:
        filtro["color"] = color
    if temporada:
        filtro["temporada"] = temporada

    # Limitar el máximo de prendas por página
    limit = min(limit, 50)
    skip = (page - 1) * limit

    # Contar total
    total = await db.prendas.count_documents(filtro)

    # Obtener prendas
    cursor = db.prendas.find(filtro).sort("creado_en", -1).skip(skip).limit(limit)
    prendas_raw = await cursor.to_list(length=limit)

    prendas = [PrendaModel.serializar(p) for p in prendas_raw]

    return {
        "success": True,
        "total": total,
        "page": page,
        "prendas": prendas
    }


async def eliminar_prenda(prenda_id: str, usuario_id: str, db) -> dict:
    """
    Elimina una prenda del guardarropa (soft delete).
    Solo el propietario puede eliminar sus prendas.
    
    Returns:
        dict con éxito y mensaje
    """
    # Verificar que la prenda pertenece al usuario
    prenda = await db.prendas.find_one({
        "_id": ObjectId(prenda_id),
        "usuario_id": ObjectId(usuario_id),
        "activa": True
    })

    if not prenda:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prenda no encontrada o no tienes permiso para eliminarla"
        )

    # Soft delete — marcar como inactiva
    await db.prendas.update_one(
        {"_id": ObjectId(prenda_id)},
        {"$set": {"activa": False}}
    )

    logger.info(f"✅ Prenda eliminada: {prenda_id}")

    return {
        "success": True,
        "mensaje": "Prenda eliminada correctamente"
    }


async def obtener_stats(usuario_id: str, db) -> dict:
    """
    Obtiene estadísticas del guardarropa del usuario.
    
    Returns:
        dict con estadísticas detalladas del armario
    """
    filtro_base = {"usuario_id": ObjectId(usuario_id), "activa": True}

    # Contar total
    total = await db.prendas.count_documents(filtro_base)

    if total == 0:
        return {
            "total_prendas": 0,
            "por_tipo": {},
            "por_color": {},
            "por_temporada": {},
            "prenda_mas_usada": None,
            "prendas_nunca_usadas": 0
        }

    # Obtener todas las prendas para agrupar
    cursor = db.prendas.find(filtro_base)
    prendas = await cursor.to_list(length=1000)

    # Agrupar por tipo
    por_tipo = {}
    por_color = {}
    por_temporada = {}
    prenda_mas_usada = None
    max_usos = -1
    nunca_usadas = 0

    for p in prendas:
        # Por tipo
        tipo = p.get("tipo", "other")
        por_tipo[tipo] = por_tipo.get(tipo, 0) + 1

        # Por color
        color = p.get("color", "negro")
        por_color[color] = por_color.get(color, 0) + 1

        # Por temporada
        temporada = p.get("temporada", "")
        if temporada:
            por_temporada[temporada] = por_temporada.get(temporada, 0) + 1

        # Prenda más usada
        usos = p.get("veces_usado", 0)
        if usos > max_usos:
            max_usos = usos
            prenda_mas_usada = PrendaModel.serializar(p)

        # Nunca usadas
        if usos == 0:
            nunca_usadas += 1

    return {
        "total_prendas": total,
        "por_tipo": por_tipo,
        "por_color": por_color,
        "por_temporada": por_temporada,
        "prenda_mas_usada": prenda_mas_usada if max_usos > 0 else None,
        "prendas_nunca_usadas": nunca_usadas
    }

# StyleMe - Controlador de Guardarropa
import io
import logging
import os
import threading
import time
import uuid
from pathlib import Path
from datetime import datetime
from typing import Optional
from PIL import Image
from bson import ObjectId
from fastapi import HTTPException, status, UploadFile
from fastapi.concurrency import run_in_threadpool

from app.config.database import get_db
from app.config.settings import settings
from app.models.prenda_model import PrendaModel
from app.models.momento import (
    MOMENTOS_VALIDOS,
    MAPEO_TEMPORADA_A_MOMENTO,
    MOMENTO_DEFAULT,
    momento_de_prenda,
    normalizar_momento,
)
from app.ml.ml_agent import ml_agent, ml_lock
from app.services.imagen_service import normalizar_orientacion

logger = logging.getLogger(__name__)

# Extensiones permitidas
EXTENSIONES_PERMITIDAS = {".jpg", ".jpeg", ".png"}
TIPOS_MIME_PERMITIDOS = {"image/jpeg", "image/jpg", "image/png"}

# Sesión u2net de rembg: perezosa, creada una sola vez y reutilizada
# (evita recargar el modelo ONNX en cada subida de prenda).
_rembg_session = None
_rembg_session_lock = threading.Lock()


def _obtener_rembg_session():
    global _rembg_session
    if _rembg_session is None:
        with _rembg_session_lock:
            if _rembg_session is None:
                from rembg import new_session
                _rembg_session = new_session("u2net")
    return _rembg_session


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
    contenido = normalizar_orientacion(contenido)

    # Verificar tamaño
    tamanio_mb = len(contenido) / (1024 * 1024)
    if tamanio_mb > settings.MAX_IMAGE_SIZE_MB:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Imagen demasiado grande. Máximo {settings.MAX_IMAGE_SIZE_MB}MB"
        )

    return contenido


def _centrar_en_tarjeta_blanca(img_rgba: Image.Image, size: int = 512) -> bytes:
    """
    Centra una imagen RGBA sobre un fondo blanco size x size y la codifica
    a JPEG. Compartida por el flujo con rembg y el flujo con recorte hecho
    en el dispositivo.
    """
    fondo = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    img_rgba.thumbnail((size, size), Image.LANCZOS)
    offset_x = (size - img_rgba.width) // 2
    offset_y = (size - img_rgba.height) // 2

    # Pegar usando el canal alpha como máscara para bordes suaves
    fondo.paste(img_rgba, (offset_x, offset_y), mask=img_rgba.split()[3])

    # Convertir a RGB y guardar como JPEG
    fondo_rgb = fondo.convert("RGB")
    buf_salida = io.BytesIO()
    fondo_rgb.save(buf_salida, format="JPEG", quality=92)
    return buf_salida.getvalue()


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

        with ml_lock:
            resultado_bytes = rembg_remove(buf_entrada.read(), session=_obtener_rembg_session())
        img_sin_fondo = Image.open(io.BytesIO(resultado_bytes)).convert("RGBA")

    except Exception as e:
        # Si rembg falla, usar imagen recortada sin quitar fondo
        logger.warning(f"rembg falló, usando recorte simple: {e}")
        img_sin_fondo = img.convert("RGBA")

    # Paso 4: centrar sobre fondo blanco 512x512
    return _centrar_en_tarjeta_blanca(img_sin_fondo)


def generar_tarjeta_desde_recorte(png_bytes: bytes, padding_pct: float = 0.12) -> bytes:
    """
    Genera la tarjeta 512x512 a partir de un recorte PNG con transparencia
    hecho en el dispositivo (p. ej. ML Kit Subject Segmentation), sin pasar
    por rembg. No toma ml_lock: no hay inferencia de modelo, solo PIL.

    Raises:
        ValueError: si el canal alfa no tiene un sujeto detectable.
    """
    img = Image.open(io.BytesIO(png_bytes)).convert("RGBA")

    # Contorno del sujeto a partir del canal alfa (umbral > 10)
    alfa = img.split()[3]
    bbox_alfa = alfa.point(lambda a: 255 if a > 10 else 0).getbbox()

    if bbox_alfa is None:
        raise ValueError("El recorte no tiene un sujeto detectable (canal alfa vacío)")

    x1, y1, x2, y2 = bbox_alfa
    area_sujeto = (x2 - x1) * (y2 - y1)
    area_total = img.width * img.height
    if area_total == 0 or (area_sujeto / area_total) < 0.01:
        raise ValueError("El área del sujeto en el recorte es menor al 1% de la imagen")

    # Recorte al contorno con el mismo margen que usa el flujo con rembg
    pad_x = int((x2 - x1) * padding_pct)
    pad_y = int((y2 - y1) * padding_pct)
    x1 = max(0, x1 - pad_x)
    y1 = max(0, y1 - pad_y)
    x2 = min(img.width, x2 + pad_x)
    y2 = min(img.height, y2 + pad_y)
    img = img.crop((x1, y1, x2, y2))

    return _centrar_en_tarjeta_blanca(img)


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
    momento: str,
    notas: str,
    db,
    imagen_sin_fondo: Optional[UploadFile] = None
) -> dict:
    """
    Agrega una nueva prenda al guardarropa del usuario.

    Proceso:
    1. Procesar imagen con el agente ML (YOLO + KMeans) — siempre sobre `imagen`
    2. Generar tarjeta 512x512 (desde imagen_sin_fondo si llega y es válida,
       si no con el flujo actual de rembg)
    3. Guardar imagen en /uploads/
    4. Crear documento en MongoDB

    Returns:
        dict con éxito y datos de la prenda detectada
    """
    momento = normalizar_momento(momento)
    if momento is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Momento debe ser uno de: {MOMENTOS_VALIDOS}"
        )

    # Procesar imagen con ML — siempre sobre la foto original
    logger.info(f"🔍 Procesando imagen con ML para usuario {usuario_id}")
    resultado_ml = await ml_agent.procesar_imagen(imagen_bytes)

    tipo = resultado_ml.get("tipo", "other")
    color = resultado_ml.get("color", "negro")
    confianza = resultado_ml.get("confianza", 0.0)
    bbox = resultado_ml.get("bbox", [])

    logger.info(f"   Tipo detectado: {tipo} ({confianza:.1%})")
    logger.info(f"   Color detectado: {color}")

    # Generar tarjeta: preferir el recorte del dispositivo si llega y es válido
    t_inicio_tarjeta = time.perf_counter()
    imagen_tarjeta = None
    ruta_usada = None

    if imagen_sin_fondo is not None:
        contenido_sin_fondo = await imagen_sin_fondo.read()
        content_type_sf = imagen_sin_fondo.content_type or ""
        extension_sf = Path(imagen_sin_fondo.filename or "").suffix.lower()
        es_png = (content_type_sf in {"image/png"}) or (extension_sf == ".png")
        tamanio_mb_sf = len(contenido_sin_fondo) / (1024 * 1024)

        if not es_png or tamanio_mb_sf > settings.MAX_IMAGE_SIZE_MB:
            logger.warning(
                f"imagen_sin_fondo inválida (tipo={content_type_sf!r}, "
                f"tamaño={tamanio_mb_sf:.2f}MB) — usando flujo rembg"
            )
        else:
            try:
                imagen_tarjeta = await run_in_threadpool(
                    generar_tarjeta_desde_recorte, contenido_sin_fondo
                )
                ruta_usada = "tarjeta desde recorte del dispositivo"
            except Exception as e:
                logger.warning(f"generar_tarjeta_desde_recorte falló ({e}) — usando flujo rembg")
                imagen_tarjeta = None

    if imagen_tarjeta is None:
        imagen_tarjeta = await run_in_threadpool(generar_imagen_tarjeta, imagen_bytes, bbox)
        ruta_usada = "tarjeta con rembg"

    duracion_ms = (time.perf_counter() - t_inicio_tarjeta) * 1000
    logger.info(f"   Imagen procesada: {ruta_usada} ({duracion_ms:.0f} ms)")

    # Guardar imagen procesada localmente
    imagen_url = await guardar_imagen_local(imagen_tarjeta, usuario_id, nombre_imagen)

    # Crear documento de prenda
    nueva_prenda = PrendaModel.crear(
        usuario_id=usuario_id,
        tipo=tipo,
        color=color,
        momento=momento,
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
            "momento": momento,
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
    momento: str = None,
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
    if momento:
        momento_normalizado = normalizar_momento(momento)
        if momento_normalizado is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Momento debe ser uno de: {MOMENTOS_VALIDOS}"
            )
        # Las prendas "ambos" (versátiles) aparecen en cualquier filtro de
        # soleado/lluvioso, además de en el filtro "ambos".
        momentos_objetivo = {momento_normalizado, MOMENTO_DEFAULT}

        # Prendas ya migradas: coincidencia directa por "momento".
        # Prendas sin migrar (solo tienen "temporada"): se incluyen si su
        # temporada mapea a alguno de los momentos objetivo (MAPEO_TEMPORADA_A_MOMENTO).
        temporadas_legacy = [
            t for t, m in MAPEO_TEMPORADA_A_MOMENTO.items() if m in momentos_objetivo
        ]
        or_clauses = [
            {"momento": {"$in": list(momentos_objetivo)}},
            {"momento": {"$exists": False}, "temporada": {"$in": temporadas_legacy}}
        ]
        # Prendas sin "momento" ni "temporada" (dato incompleto): caen al
        # default, así que solo aparecen cuando el default está entre los
        # momentos objetivo (siempre, dado que MOMENTO_DEFAULT = "ambos").
        if MOMENTO_DEFAULT in momentos_objetivo:
            or_clauses.append({"momento": {"$exists": False}, "temporada": {"$exists": False}})
        filtro["$or"] = or_clauses

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
            "por_momento": {},
            "prenda_mas_usada": None,
            "prendas_nunca_usadas": 0
        }

    # Obtener todas las prendas para agrupar
    cursor = db.prendas.find(filtro_base)
    prendas = await cursor.to_list(length=1000)

    # Agrupar por tipo
    por_tipo = {}
    por_color = {}
    por_momento = {}
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

        # Por momento
        momento = momento_de_prenda(p)
        por_momento[momento] = por_momento.get(momento, 0) + 1

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
        "por_momento": por_momento,
        "prenda_mas_usada": prenda_mas_usada if max_usos > 0 else None,
        "prendas_nunca_usadas": nunca_usadas
    }

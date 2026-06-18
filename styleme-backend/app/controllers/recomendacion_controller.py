# StyleMe - Controlador de Recomendaciones de Outfits
import logging
from datetime import datetime, date
from pathlib import Path
from bson import ObjectId
from fastapi import HTTPException, status

from app.config.settings import settings
from app.models.prenda_model import PrendaModel
from app.models.outfit_model import OutfitModel
from app.ml.ml_agent import ml_agent

logger = logging.getLogger(__name__)


def _tipo_a_categoria(tipo: str) -> str:
    """Mapea el tipo de prenda detectado por YOLO a la categoría CatVTON."""
    t = tipo.lower()
    if any(k in t for k in ["dress", "vestido"]):
        return "dresses"
    if any(k in t for k in ["pant", "jean", "short", "trouser", "falda", "skirt", "legging"]):
        return "lower"
    return "upper"


async def recomendar_outfit(
    prenda_id: str,
    temporada: str,
    top_k: int,
    usuario_id: str,
    db
) -> dict:
    """
    Genera recomendaciones de outfit basadas en una prenda seleccionada.
    
    Proceso:
    1. Cargar prenda base desde MongoDB
    2. Cargar guardarropa completo del usuario
    3. Agente ML: calcular scores de compatibilidad
    4. Guardar outfit generado en historial
    
    Returns:
        dict con prenda_base, recomendaciones, outfit_id
    """
    # Cargar prenda base
    prenda_doc = await db.prendas.find_one({
        "_id": ObjectId(prenda_id),
        "usuario_id": ObjectId(usuario_id),
        "activa": True
    })

    if not prenda_doc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prenda no encontrada"
        )

    prenda_base = PrendaModel.serializar(prenda_doc)

    # Cargar guardarropa completo del usuario
    cursor = db.prendas.find({
        "usuario_id": ObjectId(usuario_id),
        "activa": True
    })
    guardarropa_raw = await cursor.to_list(length=500)
    guardarropa = [PrendaModel.serializar(p) for p in guardarropa_raw]

    if len(guardarropa) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Necesitas al menos 2 prendas en tu guardarropa para generar outfits"
        )

    # Preparar prenda base para el agente ML
    prenda_base_ml = {
        "tipo": prenda_base["tipo"],
        "color": prenda_base["color"],
        "temporada": temporada or prenda_base["temporada"],
        "id": prenda_base["id"]
    }

    # Obtener recomendaciones del agente ML
    recomendaciones_raw = await ml_agent.recomendar_outfit(
        prenda_base_ml,
        guardarropa,
        top_k=top_k
    )

    # Formatear recomendaciones para la respuesta
    recomendaciones = []
    complementos_para_db = []

    for rec in recomendaciones_raw:
        prenda_rec = {
            "id": rec.get("id", ""),
            "tipo": rec.get("tipo", ""),
            "color": rec.get("color", ""),
            "temporada": rec.get("temporada", ""),
            "confianza_yolo": rec.get("confianza_yolo", 0.0),
            "imagen_url": rec.get("imagen_url", ""),
            "notas": rec.get("notas", ""),
            "veces_usado": rec.get("veces_usado", 0),
            "creado_en": rec.get("creado_en", "")
        }

        recomendaciones.append({
            "prenda": prenda_rec,
            "score": rec.get("score", 0.0),
            "porcentaje": rec.get("porcentaje", "0%"),
            "detalle": rec.get("detalle", {})
        })

        complementos_para_db.append({
            "prenda_id": ObjectId(rec["id"]) if rec.get("id") else None,
            "score": rec.get("score", 0.0),
            "porcentaje": rec.get("porcentaje", "0%"),
            "detalle": rec.get("detalle", {})
        })

    # Guardar outfit en historial
    nuevo_outfit = OutfitModel.crear(
        usuario_id=usuario_id,
        prenda_base_id=prenda_id,
        complementos=complementos_para_db,
        temporada=temporada,
        tipo_generacion="manual"
    )

    resultado = await db.outfits.insert_one(nuevo_outfit)
    outfit_id = str(resultado.inserted_id)

    # Actualizar contador de usos de las prendas
    ids_usadas = [prenda_id] + [r.get("id") for r in recomendaciones_raw if r.get("id")]
    for pid in ids_usadas:
        if pid:
            try:
                await db.prendas.update_one(
                    {"_id": ObjectId(pid)},
                    {"$inc": {"veces_usado": 1}}
                )
            except Exception:
                pass

    # Actualizar contador de outfits del usuario
    await db.usuarios.update_one(
        {"_id": ObjectId(usuario_id)},
        {"$inc": {"total_outfits_generados": 1}}
    )

    logger.info(f"✅ Outfit generado: {outfit_id} para usuario {usuario_id}")

    return {
        "success": True,
        "prenda_base": prenda_base,
        "recomendaciones": recomendaciones,
        "outfit_id": outfit_id,
        "generado_en": nuevo_outfit["generado_en"].isoformat()
    }


async def obtener_outfits_diarios(
    temporada: str,
    usuario_id: str,
    db
) -> dict:
    """
    Genera los outfits del día para el usuario.
    Selecciona 3 prendas base distintas priorizando las menos usadas.
    
    Returns:
        dict con fecha, temporada y 3 outfits del día
    """
    # Cargar guardarropa completo
    cursor = db.prendas.find({
        "usuario_id": ObjectId(usuario_id),
        "activa": True
    })
    guardarropa_raw = await cursor.to_list(length=500)
    guardarropa = [PrendaModel.serializar(p) for p in guardarropa_raw]

    if not guardarropa:
        return {
            "success": True,
            "fecha": date.today().isoformat(),
            "temporada": temporada,
            "outfits_del_dia": []
        }

    # Obtener IDs de outfits con dislike para evitarlos
    disliked_cursor = db.outfits.find({
        "usuario_id": ObjectId(usuario_id),
        "feedback": "disliked"
    })
    disliked_outfits = await disliked_cursor.to_list(length=100)

    disliked_prenda_ids = []
    for outfit in disliked_outfits:
        disliked_prenda_ids.append(str(outfit.get("prenda_base_id", "")))

    # Generar outfits con el agente ML
    outfits_raw = await ml_agent.generar_outfit_diario(
        guardarropa,
        temporada=temporada,
        disliked_ids=disliked_prenda_ids
    )

    outfits_del_dia = []
    for outfit in outfits_raw:
        prenda_base = outfit["prenda_base"]
        complementos_raw = outfit["complementos"]

        # Formatear complementos
        complementos_formateados = []
        complementos_para_db = []

        for comp in complementos_raw:
            complementos_formateados.append({
                "prenda": {
                    "id": comp.get("id", ""),
                    "tipo": comp.get("tipo", ""),
                    "color": comp.get("color", ""),
                    "temporada": comp.get("temporada", ""),
                    "imagen_url": comp.get("imagen_url", ""),
                    "confianza_yolo": comp.get("confianza_yolo", 0.0)
                },
                "score": comp.get("score", 0.0),
                "porcentaje": comp.get("porcentaje", "0%"),
                "detalle": comp.get("detalle", {})
            })

            complementos_para_db.append({
                "prenda_id": ObjectId(comp["id"]) if comp.get("id") else None,
                "score": comp.get("score", 0.0),
                "porcentaje": comp.get("porcentaje", "0%"),
                "detalle": comp.get("detalle", {})
            })

        # Guardar outfit en historial
        nuevo_outfit_doc = OutfitModel.crear(
            usuario_id=usuario_id,
            prenda_base_id=prenda_base.get("id", ""),
            complementos=complementos_para_db,
            temporada=temporada,
            tipo_generacion="diario"
        )

        resultado = await db.outfits.insert_one(nuevo_outfit_doc)
        outfit_id = str(resultado.inserted_id)

        outfits_del_dia.append({
            "outfit_id": outfit_id,
            "prenda_base": prenda_base,
            "complementos": complementos_formateados
        })

    # Actualizar contador de outfits del usuario
    if outfits_del_dia:
        await db.usuarios.update_one(
            {"_id": ObjectId(usuario_id)},
            {"$inc": {"total_outfits_generados": len(outfits_del_dia)}}
        )

    logger.info(f"✅ Outfits diarios generados: {len(outfits_del_dia)} para usuario {usuario_id}")

    return {
        "success": True,
        "fecha": date.today().isoformat(),
        "temporada": temporada,
        "total_outfits": len(outfits_del_dia),
        "outfits_del_dia": outfits_del_dia
    }


async def generar_outfits_ia(usuario: dict, temporada: str, db) -> dict:
    """
    Genera outfits del día con imagen IA del usuario usando CatVTON.

    Proceso:
    1. Verificar que el usuario tiene foto de perfil
    2. Obtener outfits del día del recomendador KNN
    3. Para cada outfit, llamar a CatVTON con la foto de perfil y la prenda base
    4. Retornar lista de outfits con imagen generada

    Returns:
        dict con lista de outfits con imagen generada en base64
    """
    from app.services.virtual_tryon_service import VirtualTryOnService

    # 1. Verificar foto de perfil
    foto_perfil_url = usuario.get("foto_perfil_url")
    if not foto_perfil_url:
        raise HTTPException(
            status_code=400,
            detail="Agrega tu foto de perfil para ver outfits con IA"
        )

    # 2. Cargar bytes de la foto de perfil desde disco
    foto_path = Path(".") / foto_perfil_url.lstrip("/")
    if not foto_path.exists():
        raise HTTPException(
            status_code=400,
            detail="Agrega tu foto de perfil para ver outfits con IA"
        )

    persona_bytes = foto_path.read_bytes()
    usuario_id = str(usuario["_id"])

    # 3. Obtener outfits del día del recomendador
    diarios = await obtener_outfits_diarios(temporada, usuario_id, db)
    outfits = diarios.get("outfits_del_dia", [])

    if not outfits:
        return {"success": True, "total": 0, "outfits_ia": []}

    # 4. Llamar CatVTON para cada outfit
    service = VirtualTryOnService(db)
    resultados = []

    for outfit in outfits:
        prenda_base = outfit["prenda_base"]
        tipo = prenda_base.get("tipo", "")
        categoria = _tipo_a_categoria(tipo)
        imagen_url = prenda_base.get("imagen_url", "")

        prenda_path = Path(".") / imagen_url.lstrip("/")
        if not prenda_path.exists():
            logger.warning(f"Imagen de prenda no encontrada: {prenda_path}")
            continue

        try:
            prenda_bytes = prenda_path.read_bytes()
            resultado = await service.generar_tryon_desde_bytes(
                persona_bytes, prenda_bytes, categoria
            )
            resultados.append({
                "outfit_id": outfit["outfit_id"],
                "imagen_generada": resultado["imagen_resultado"],
                "prenda_base": prenda_base,
                "complementos": outfit["complementos"],
                "tiempo_generacion": resultado.get("tiempo_total_backend", 0)
            })
        except Exception as e:
            logger.error(f"CatVTON falló para outfit {outfit.get('outfit_id')}: {e}")

    logger.info(f"✅ Outfits IA generados: {len(resultados)} para usuario {usuario_id}")

    return {
        "success": True,
        "total": len(resultados),
        "outfits_ia": resultados
    }

# StyleMe - Controlador del Agente de Recomendación (LLM)
import logging
from datetime import datetime
from bson import ObjectId
from fastapi import HTTPException, status

from app.models.outfit_model import OutfitModel
from app.models.momento import momento_de_prenda, MOMENTO_DEFAULT
from app.services import clima_service, groq_service, prompt_agente

logger = logging.getLogger(__name__)


async def _guardar_recomendacion(
    usuario_id: str,
    descripcion_evento: str,
    lugar: str,
    fecha: str,
    respuesta: dict,
    descartados: list,
    db,
) -> str | None:
    """
    Persiste la recomendación generada en recomendaciones_evento.

    Se envuelve en try/except: un fallo al guardar no puede convertirse
    en un error para el usuario, porque la recomendación ya se generó
    y ya se pagaron los tokens del LLM. Si falla, retorna None.
    """
    try:
        resultado = await db.recomendaciones_evento.insert_one({
            "usuario_id": ObjectId(usuario_id),
            "descripcion_evento": descripcion_evento,
            "lugar": lugar,
            "fecha": fecha,
            "clima": respuesta["clima"],
            "outfits": respuesta["outfits"],
            "notas": respuesta["notas"],
            "meta": respuesta["meta"],
            "outfits_descartados": descartados,
            "activa": True,
            "creado_en": datetime.utcnow(),
        })
        return str(resultado.inserted_id)
    except Exception as e:
        logger.warning(f"No se pudo persistir la recomendación de evento: {e}")
        return None


async def recomendar_para_evento(
    usuario_id: str,
    descripcion_evento: str,
    lugar: str,
    fecha: str,
    db,
) -> dict:
    """
    Genera 3 outfits recomendados para un evento, combinando el guardarropa
    del usuario, el clima esperado y un LLM (Groq) que arma las combinaciones.

    Args:
        descripcion_evento: descripción libre del evento (ej. "Grado universitario")
        lugar: ciudad/lugar del evento
        fecha: fecha objetivo del evento, formato YYYY-MM-DD

    Returns:
        dict con evento, clima, outfits resueltos, notas y metadata de la llamada al LLM
    """
    # Guardarropa del usuario: query directa, no la paginada de guardarropa_controller
    cursor = db.prendas.find(
        {"usuario_id": ObjectId(usuario_id), "activa": True},
        {"_id": 1, "tipo": 1, "color": 1, "momento": 1, "temporada": 1, "veces_usado": 1, "imagen_url": 1},
    )
    prendas = await cursor.to_list(length=None)

    if len(prendas) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Necesitas al menos 3 prendas activas en tu guardarropa para recibir recomendaciones",
        )

    clima = await clima_service.obtener_clima(lugar, fecha)

    prendas_filtradas = prompt_agente.filtrar_prendas(prendas, clima)

    mensajes = [
        {"role": "system", "content": prompt_agente.SYSTEM_PROMPT},
        {"role": "user", "content": prompt_agente.construir_mensaje_usuario(
            descripcion_evento, clima, prendas_filtradas
        )},
    ]

    resultado = await groq_service.completar(
        mensajes=mensajes,
        json_mode=True,
        temperatura=0.5,
        # 2048: con modelos de razonamiento (gpt-oss/qwen) los tokens de
        # razonamiento comparten el mismo presupuesto que la respuesta final;
        # 1024 alcanzaba justo para el JSON (~300-450 tokens para 3 outfits +
        # notas) sin dejar margen para el razonamiento previo.
        max_tokens=2048,
    )

    outfits_validos, descartados = prompt_agente.validar_outfits(
        resultado["contenido_json"], len(prendas_filtradas)
    )

    if not outfits_validos:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="El modelo devolvió referencias inválidas a prendas; no se pudo generar ningún outfit",
        )

    outfits_resueltos = []
    for outfit in outfits_validos:
        prendas_resueltas = []
        for indice in outfit["prendas"]:
            prenda = prendas_filtradas[indice]
            prendas_resueltas.append({
                "id": str(prenda["_id"]),
                "tipo": prenda["tipo"],
                "color": prenda["color"],
                "imagen_url": prenda.get("imagen_url"),
            })
        outfits_resueltos.append({
            "nombre": outfit["nombre"],
            "prendas": prendas_resueltas,
            "justificacion": outfit["justificacion"],
            "outfit_guardado_id": None,
        })

    logger.info(f"✅ {len(outfits_resueltos)} outfits generados para usuario {usuario_id}")

    respuesta = {
        "evento": descripcion_evento,
        "clima": clima,
        "outfits": outfits_resueltos,
        "notas": resultado["contenido_json"].get("notas", []),
        "meta": {
            "prendas_consideradas": len(prendas_filtradas),
            "prendas_totales": len(prendas),
            "outfits_descartados": len(descartados),
            "modelo": resultado["modelo"],
            "tokens_prompt": resultado["tokens_prompt"],
            "latencia_ms": resultado["latencia_ms"],
        },
    }

    recomendacion_id = await _guardar_recomendacion(
        usuario_id=usuario_id,
        descripcion_evento=descripcion_evento,
        lugar=lugar,
        fecha=fecha,
        respuesta=respuesta,
        descartados=descartados,
        db=db,
    )
    respuesta["id"] = recomendacion_id

    return respuesta


async def listar_recomendaciones(
    usuario_id: str,
    page: int = 1,
    limit: int = 20,
    db=None,
) -> dict:
    """
    Lista las recomendaciones de evento del usuario con paginación.

    Returns:
        dict con total, página actual y lista compacta de recomendaciones
    """
    filtro = {
        "usuario_id": ObjectId(usuario_id),
        "activa": True,
    }

    # Limitar el máximo de recomendaciones por página
    limit = min(limit, 50)
    skip = (page - 1) * limit

    # Contar total
    total = await db.recomendaciones_evento.count_documents(filtro)

    # Obtener recomendaciones: proyección compacta, total_outfits vía $size
    cursor = db.recomendaciones_evento.aggregate([
        {"$match": filtro},
        {"$sort": {"creado_en": -1}},
        {"$skip": skip},
        {"$limit": limit},
        {"$project": {
            "descripcion_evento": 1,
            "lugar": 1,
            "fecha": 1,
            "creado_en": 1,
            "total_outfits": {"$size": "$outfits"},
        }},
    ])
    docs = await cursor.to_list(length=limit)

    recomendaciones = [
        {
            "id": str(doc["_id"]),
            "descripcion_evento": doc.get("descripcion_evento", ""),
            "lugar": doc.get("lugar", ""),
            "fecha": doc.get("fecha", ""),
            "creado_en": doc.get("creado_en", datetime.utcnow()).isoformat(),
            "total_outfits": doc.get("total_outfits", 0),
        }
        for doc in docs
    ]

    return {
        "success": True,
        "total": total,
        "page": page,
        "recomendaciones": recomendaciones,
    }


async def obtener_recomendacion(
    usuario_id: str,
    recomendacion_id: str,
    db=None,
) -> dict:
    """
    Obtiene el detalle completo de una recomendación de evento.
    Solo el propietario puede consultar su recomendación.

    Returns:
        dict con el documento completo (sin outfits_descartados)
    """
    doc = await db.recomendaciones_evento.find_one({
        "_id": ObjectId(recomendacion_id),
        "usuario_id": ObjectId(usuario_id),
        "activa": True,
    })

    if not doc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recomendacion no encontrada",
        )

    return {
        "evento": doc.get("descripcion_evento", ""),
        "clima": doc.get("clima", {}),
        "outfits": doc.get("outfits", []),
        "notas": doc.get("notas", []),
        "meta": doc.get("meta", {}),
    }


async def alternar_guardado_outfit(
    usuario_id: str,
    recomendacion_id: str,
    indice_outfit: int,
    db,
) -> dict:
    """
    Toggle de "me gusta" sobre un outfit de una recomendación de evento.

    Sin outfit_guardado_id: copia el outfit a db.outfits (mismo esquema que
    usa el historial normal) con feedback="liked" y tipo_generacion="evento".
    Con outfit_guardado_id: borra esa copia y limpia la referencia.
    """
    doc = await db.recomendaciones_evento.find_one({
        "_id": ObjectId(recomendacion_id),
        "usuario_id": ObjectId(usuario_id),
        "activa": True,
    })

    if not doc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recomendacion no encontrada",
        )

    outfits = doc.get("outfits", [])
    if indice_outfit < 0 or indice_outfit >= len(outfits):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Indice de outfit fuera de rango",
        )

    outfit = outfits[indice_outfit]
    outfit_guardado_id = outfit.get("outfit_guardado_id")

    if outfit_guardado_id is None:
        prendas = outfit.get("prendas", [])
        prenda_base_id = prendas[0]["id"]
        complementos = [
            {
                "prenda_id": ObjectId(p["id"]),
                "score": 0.0,
                "porcentaje": None,
                "detalle": {},
            }
            for p in prendas[1:]
        ]

        # Mismo "momento" que ve el usuario en su guardarropa: el de la prenda base.
        prenda_base_doc = await db.prendas.find_one({"_id": ObjectId(prenda_base_id)})
        momento = momento_de_prenda(prenda_base_doc) if prenda_base_doc else MOMENTO_DEFAULT

        nuevo_outfit = OutfitModel.crear(
            usuario_id=usuario_id,
            prenda_base_id=prenda_base_id,
            complementos=complementos,
            momento=momento,
            tipo_generacion="evento",
        )
        nuevo_outfit["feedback"] = "liked"

        resultado = await db.outfits.insert_one(nuevo_outfit)
        nuevo_id = str(resultado.inserted_id)

        await db.recomendaciones_evento.update_one(
            {"_id": ObjectId(recomendacion_id)},
            {"$set": {f"outfits.{indice_outfit}.outfit_guardado_id": nuevo_id}},
        )

        logger.info(f"✅ Outfit del agente guardado en historial: {nuevo_id}")

        return {"guardado": True, "outfit_guardado_id": nuevo_id}

    await db.outfits.delete_one({
        "_id": ObjectId(outfit_guardado_id),
        "usuario_id": ObjectId(usuario_id),
    })

    await db.recomendaciones_evento.update_one(
        {"_id": ObjectId(recomendacion_id)},
        {"$set": {f"outfits.{indice_outfit}.outfit_guardado_id": None}},
    )

    logger.info(f"✅ Outfit del agente removido del historial: {outfit_guardado_id}")

    return {"guardado": False, "outfit_guardado_id": None}


async def eliminar_outfit_recomendacion(
    usuario_id: str,
    recomendacion_id: str,
    indice_outfit: int,
    db,
) -> dict:
    """
    Elimina un outfit del array de una recomendación de evento.
    No toca db.outfits: si el outfit tenía "me gusta", su copia en el
    historial se mantiene intacta.
    """
    doc = await db.recomendaciones_evento.find_one({
        "_id": ObjectId(recomendacion_id),
        "usuario_id": ObjectId(usuario_id),
        "activa": True,
    })

    if not doc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recomendacion no encontrada",
        )

    outfits = doc.get("outfits", [])
    if indice_outfit < 0 or indice_outfit >= len(outfits):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Indice de outfit fuera de rango",
        )

    outfits.pop(indice_outfit)

    await db.recomendaciones_evento.update_one(
        {"_id": ObjectId(recomendacion_id)},
        {"$set": {"outfits": outfits}},
    )

    logger.info(f"✅ Outfit {indice_outfit} eliminado de recomendacion {recomendacion_id}")

    return {"success": True, "outfits_restantes": len(outfits)}

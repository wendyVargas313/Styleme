# StyleMe - Controlador de Historial y Feedback
import logging
from bson import ObjectId
from fastapi import HTTPException, status

from app.models.prenda_model import PrendaModel
from app.models.outfit_model import OutfitModel

logger = logging.getLogger(__name__)


async def obtener_historial(
    usuario_id: str,
    filtro: str,
    page: int,
    limit: int,
    db
) -> dict:
    """
    Obtiene el historial de outfits del usuario con filtros opcionales.
    
    Args:
        filtro: all/liked/saved/disliked
        page: Página actual
        limit: Cantidad de items por página
    
    Returns:
        dict con total y lista de outfits
    """
    # Construir filtro MongoDB
    query = {"usuario_id": ObjectId(usuario_id)}

    if filtro != "all":
        query["feedback"] = filtro

    limit = min(limit, 50)
    skip = (page - 1) * limit

    # Contar total
    total = await db.outfits.count_documents(query)

    # Obtener outfits
    cursor = db.outfits.find(query).sort("generado_en", -1).skip(skip).limit(limit)
    outfits_raw = await cursor.to_list(length=limit)

    outfits_serializados = []
    for outfit_doc in outfits_raw:
        # Serializar outfit base
        outfit = OutfitModel.serializar(outfit_doc)

        # Obtener prenda base
        prenda_base_doc = await db.prendas.find_one({
            "_id": outfit_doc.get("prenda_base_id")
        })
        outfit["prenda_base"] = PrendaModel.serializar(prenda_base_doc) if prenda_base_doc else {}

        # Obtener complementos con datos de prenda
        complementos_detalle = []
        for comp in outfit_doc.get("complementos", []):
            prenda_id = comp.get("prenda_id")
            if prenda_id:
                prenda_doc = await db.prendas.find_one({"_id": prenda_id})
                if prenda_doc:
                    complementos_detalle.append({
                        "prenda": PrendaModel.serializar(prenda_doc),
                        "score": comp.get("score", 0.0),
                        "porcentaje": comp.get("porcentaje", "0%"),
                        "detalle": comp.get("detalle", {})
                    })

        outfit["complementos"] = complementos_detalle
        outfits_serializados.append(outfit)

    return {
        "success": True,
        "total": total,
        "outfits": outfits_serializados
    }


async def registrar_feedback(
    outfit_id: str,
    feedback: str,
    usuario_id: str,
    db
) -> dict:
    """
    Registra el feedback del usuario sobre un outfit.
    
    Args:
        outfit_id: ID del outfit
        feedback: liked/saved/disliked
        usuario_id: ID del usuario (para verificar propiedad)
    
    Returns:
        dict con éxito y mensaje
    """
    # Verificar que el outfit pertenece al usuario
    outfit = await db.outfits.find_one({
        "_id": ObjectId(outfit_id),
        "usuario_id": ObjectId(usuario_id)
    })

    if not outfit:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Outfit no encontrado"
        )

    # Actualizar feedback
    await db.outfits.update_one(
        {"_id": ObjectId(outfit_id)},
        {"$set": {"feedback": feedback}}
    )

    logger.info(f"✅ Feedback '{feedback}' registrado para outfit {outfit_id}")

    return {
        "success": True,
        "mensaje": "Feedback registrado"
    }


async def eliminar_outfit(outfit_id: str, usuario_id: str, db) -> dict:
    """
    Elimina un outfit del historial del usuario.
    Solo el propietario puede eliminar sus outfits.
    
    Returns:
        dict con éxito y mensaje
    """
    # Verificar propiedad
    outfit = await db.outfits.find_one({
        "_id": ObjectId(outfit_id),
        "usuario_id": ObjectId(usuario_id)
    })

    if not outfit:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Outfit no encontrado o no tienes permiso para eliminarlo"
        )

    # Eliminar el outfit
    await db.outfits.delete_one({"_id": ObjectId(outfit_id)})

    logger.info(f"✅ Outfit eliminado del historial: {outfit_id}")

    return {
        "success": True,
        "mensaje": "Outfit eliminado del historial"
    }

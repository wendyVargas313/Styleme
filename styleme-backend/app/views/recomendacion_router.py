# StyleMe - Router de Recomendaciones de Outfits
from fastapi import APIRouter, Depends, status
from typing import Optional

from app.config.database import get_db
from app.middleware.auth_middleware import get_usuario_actual
from app.schemas.outfit_schema import RecomendarOutfitRequest
from app.controllers.recomendacion_controller import (
    recomendar_outfit,
    obtener_outfits_diarios
)

router = APIRouter(prefix="/recomendar", tags=["Recomendaciones"])


@router.post("/outfit", status_code=status.HTTP_200_OK)
async def recomendar(
    datos: RecomendarOutfitRequest,
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db)
):
    """
    Genera recomendaciones de outfit basadas en una prenda base seleccionada.
    El agente ML calcula scores de compatibilidad con el guardarropa completo.
    """
    usuario_id = str(usuario_actual["_id"])
    return await recomendar_outfit(
        prenda_id=datos.prenda_id,
        temporada=datos.temporada,
        top_k=datos.top_k,
        usuario_id=usuario_id,
        db=db
    )


@router.get("/diario", status_code=status.HTTP_200_OK)
async def diario(
    temporada: str = "invierno",
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db)
):
    """
    Genera los 3 outfits del día automáticamente.
    Prioriza prendas menos usadas del guardarropa.
    """
    usuario_id = str(usuario_actual["_id"])
    return await obtener_outfits_diarios(
        temporada=temporada,
        usuario_id=usuario_id,
        db=db
    )

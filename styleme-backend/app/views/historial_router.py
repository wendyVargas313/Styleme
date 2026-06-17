# StyleMe - Router de Historial y Feedback
from fastapi import APIRouter, Depends, status
from typing import Optional

from app.config.database import get_db
from app.middleware.auth_middleware import get_usuario_actual
from app.schemas.feedback_schema import FeedbackRequest
from app.controllers.historial_controller import (
    obtener_historial,
    registrar_feedback,
    eliminar_outfit
)

router = APIRouter(prefix="/historial", tags=["Historial"])


@router.get("", status_code=status.HTTP_200_OK)
async def historial(
    filtro: str = "all",
    page: int = 1,
    limit: int = 20,
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db)
):
    """
    Retorna el historial de outfits generados.
    Filtros: all/liked/saved/disliked
    """
    usuario_id = str(usuario_actual["_id"])
    return await obtener_historial(
        usuario_id=usuario_id,
        filtro=filtro,
        page=page,
        limit=limit,
        db=db
    )


@router.post("/feedback", status_code=status.HTTP_200_OK)
async def feedback(
    datos: FeedbackRequest,
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db)
):
    """
    Registra el feedback del usuario sobre un outfit (liked/saved/disliked).
    """
    usuario_id = str(usuario_actual["_id"])
    return await registrar_feedback(
        outfit_id=datos.outfit_id,
        feedback=datos.feedback,
        usuario_id=usuario_id,
        db=db
    )


@router.delete("/{outfit_id}", status_code=status.HTTP_200_OK)
async def eliminar(
    outfit_id: str,
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db)
):
    """
    Elimina un outfit del historial del usuario.
    """
    usuario_id = str(usuario_actual["_id"])
    return await eliminar_outfit(
        outfit_id=outfit_id,
        usuario_id=usuario_id,
        db=db
    )

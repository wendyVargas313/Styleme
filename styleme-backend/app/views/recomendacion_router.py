# StyleMe - Router de Recomendaciones de Outfits
from fastapi import APIRouter, Depends, HTTPException, status
from typing import Optional

from app.config.database import get_db
from app.middleware.auth_middleware import get_usuario_actual
from app.models.momento import MOMENTOS_VALIDOS
from app.schemas.outfit_schema import RecomendarOutfitRequest
from app.controllers.recomendacion_controller import (
    recomendar_outfit,
    obtener_outfits_diarios,
    generar_outfits_ia,
)


def _validar_momento_query(momento: Optional[str]) -> None:
    if momento is not None and momento not in MOMENTOS_VALIDOS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Momento debe ser uno de: {MOMENTOS_VALIDOS}"
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
        momento=datos.momento,
        top_k=datos.top_k,
        usuario_id=usuario_id,
        db=db
    )


@router.get("/diario", status_code=status.HTTP_200_OK)
async def diario(
    momento: Optional[str] = None,
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db)
):
    """
    Genera los 3 outfits del día automáticamente.
    Prioriza prendas menos usadas del guardarropa.
    """
    _validar_momento_query(momento)
    usuario_id = str(usuario_actual["_id"])
    return await obtener_outfits_diarios(
        momento=momento,
        usuario_id=usuario_id,
        db=db
    )


@router.post("/outfits-ia", status_code=status.HTTP_200_OK)
async def outfits_ia(
    momento: Optional[str] = None,
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db)
):
    """
    Genera 3 outfits del día y para cada uno llama a CatVTON
    con la foto de perfil del usuario para producir la imagen IA.
    Requiere que el usuario haya subido su foto de perfil.
    """
    _validar_momento_query(momento)
    return await generar_outfits_ia(
        usuario=usuario_actual,
        momento=momento,
        db=db
    )

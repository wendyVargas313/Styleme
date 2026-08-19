# StyleMe - Router del Agente de Recomendación (LLM)
from fastapi import APIRouter, Depends, status

from app.config.database import get_db
from app.middleware.auth_middleware import get_usuario_actual
from app.schemas.agente_schema import RecomendacionEventoRequest, RecomendacionEventoResponse
from app.controllers.agente_controller import (
    recomendar_para_evento,
    listar_recomendaciones,
    obtener_recomendacion,
    alternar_guardado_outfit,
    eliminar_outfit_recomendacion,
)

router = APIRouter(prefix="/agente", tags=["Agente IA"])


@router.post("/recomendar-evento", response_model=RecomendacionEventoResponse, status_code=status.HTTP_200_OK)
async def recomendar_evento(
    payload: RecomendacionEventoRequest,
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db),
):
    """
    Genera 3 outfits recomendados para un evento, combinando el guardarropa
    del usuario, el clima esperado y un LLM.
    """
    usuario_id = str(usuario_actual["_id"])
    return await recomendar_para_evento(
        usuario_id=usuario_id,
        descripcion_evento=payload.descripcion_evento,
        lugar=payload.lugar,
        fecha=payload.fecha,
        db=db,
    )


@router.get("/recomendaciones", status_code=status.HTTP_200_OK)
async def listar_recomendaciones_evento(
    page: int = 1,
    limit: int = 20,
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db),
):
    """
    Lista las recomendaciones de evento del usuario con paginación.
    """
    usuario_id = str(usuario_actual["_id"])
    return await listar_recomendaciones(
        usuario_id=usuario_id,
        page=page,
        limit=limit,
        db=db,
    )


@router.get("/recomendaciones/{recomendacion_id}", response_model=RecomendacionEventoResponse, status_code=status.HTTP_200_OK)
async def obtener_recomendacion_evento(
    recomendacion_id: str,
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db),
):
    """
    Obtiene el detalle completo de una recomendación de evento.
    """
    usuario_id = str(usuario_actual["_id"])
    return await obtener_recomendacion(
        usuario_id=usuario_id,
        recomendacion_id=recomendacion_id,
        db=db,
    )


@router.post("/recomendaciones/{recomendacion_id}/outfits/{indice}/guardar", status_code=status.HTTP_200_OK)
async def guardar_outfit_evento(
    recomendacion_id: str,
    indice: int,
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db),
):
    """
    Alterna el "me gusta" de un outfit de la recomendación: lo copia a
    db.outfits (historial) o quita esa copia si ya estaba guardado.
    """
    usuario_id = str(usuario_actual["_id"])
    return await alternar_guardado_outfit(
        usuario_id=usuario_id,
        recomendacion_id=recomendacion_id,
        indice_outfit=indice,
        db=db,
    )


@router.delete("/recomendaciones/{recomendacion_id}/outfits/{indice}", status_code=status.HTTP_200_OK)
async def eliminar_outfit_evento(
    recomendacion_id: str,
    indice: int,
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db),
):
    """
    Elimina un outfit del array de la recomendación de evento.
    """
    usuario_id = str(usuario_actual["_id"])
    return await eliminar_outfit_recomendacion(
        usuario_id=usuario_id,
        recomendacion_id=recomendacion_id,
        indice_outfit=indice,
        db=db,
    )

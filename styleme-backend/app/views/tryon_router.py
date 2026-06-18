# StyleMe - Router de Virtual Try-On
import base64

from fastapi import APIRouter, Depends, HTTPException, status

from app.config.database import get_db
from app.middleware.auth_middleware import get_usuario_actual
from app.schemas.virtual_tryon_schema import VirtualTryOnRequest, VirtualTryOnResponse
from app.controllers.virtual_tryon_controller import (
    generar_tryon_multipart,
    health_virtual_tryon,
)

router = APIRouter(prefix="/tryon", tags=["Virtual Try-On"])


@router.post("", response_model=VirtualTryOnResponse, status_code=status.HTTP_200_OK)
async def tryon(
    request_data: VirtualTryOnRequest,
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db),
):
    """
    Genera el resultado visual de virtual try-on usando CatVTON.
    Requiere autenticación JWT.
    Body JSON: imagen_persona (base64), imagen_prenda (base64), categoria.
    """
    try:
        persona_bytes = base64.b64decode(request_data.imagen_persona)
        prenda_bytes  = base64.b64decode(request_data.imagen_prenda)
    except Exception:
        raise HTTPException(status_code=400, detail="Las imágenes deben ser base64 válido")

    return await generar_tryon_multipart(
        persona_bytes, prenda_bytes, request_data.categoria, db
    )


@router.get("/health", status_code=status.HTTP_200_OK)
async def health():
    """
    Verifica que el módulo de virtual try-on está activo.
    No requiere autenticación.
    """
    return await health_virtual_tryon()

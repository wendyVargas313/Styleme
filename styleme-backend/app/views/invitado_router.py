# StyleMe - Router del Modo Invitado
from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from typing import List, Optional

from app.config.database import get_db
from app.controllers.invitado_controller import probar_como_invitado

router = APIRouter(prefix="/invitado", tags=["Modo Invitado"])


@router.post("/probar", status_code=status.HTTP_200_OK)
async def probar(
    imagenes: List[UploadFile] = File(..., description="Imágenes de prendas (máx 10)"),
    device_id: str = Form(..., description="Identificador único del dispositivo"),
    temporada: str = Form("invierno", description="Temporada para el outfit"),
    db=Depends(get_db)
):
    """
    Modo invitado: prueba StyleMe sin registrarte.
    Límite: 1 uso por dispositivo cada 24 horas.
    Las imágenes se eliminan al finalizar.
    """
    return await probar_como_invitado(
        imagenes=imagenes,
        device_id=device_id,
        temporada=temporada,
        db=db
    )

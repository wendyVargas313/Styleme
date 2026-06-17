# StyleMe - Router de Guardarropa
from fastapi import APIRouter, Depends, UploadFile, File, Form, status
from typing import Optional

from app.config.database import get_db
from app.middleware.auth_middleware import get_usuario_actual
from app.controllers.guardarropa_controller import (
    agregar_prenda,
    listar_prendas,
    eliminar_prenda,
    obtener_stats,
    validar_imagen
)

router = APIRouter(prefix="/guardarropa", tags=["Guardarropa"])


@router.post("/agregar", status_code=status.HTTP_201_CREATED)
async def agregar(
    imagen: UploadFile = File(..., description="Imagen JPG/PNG de la prenda (máx 5MB)"),
    temporada: str = Form(..., description="primavera/verano/otono/invierno"),
    notas: Optional[str] = Form("", description="Notas opcionales sobre la prenda"),
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db)
):
    """
    Agrega una nueva prenda al guardarropa.
    Proceso automático: imagen → YOLO detecta tipo → KMeans detecta color → guarda.
    """
    # Validar imagen
    imagen_bytes = await validar_imagen(imagen)

    usuario_id = str(usuario_actual["_id"])
    nombre_imagen = imagen.filename or "prenda.jpg"

    return await agregar_prenda(
        usuario_id=usuario_id,
        imagen_bytes=imagen_bytes,
        nombre_imagen=nombre_imagen,
        temporada=temporada,
        notas=notas or "",
        db=db
    )


@router.get("/listar", status_code=status.HTTP_200_OK)
async def listar(
    tipo: Optional[str] = None,
    color: Optional[str] = None,
    temporada: Optional[str] = None,
    page: int = 1,
    limit: int = 20,
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db)
):
    """
    Lista las prendas del guardarropa con filtros opcionales.
    Soporta filtro por tipo, color, temporada y paginación.
    """
    usuario_id = str(usuario_actual["_id"])
    return await listar_prendas(
        usuario_id=usuario_id,
        tipo=tipo,
        color=color,
        temporada=temporada,
        page=page,
        limit=limit,
        db=db
    )


@router.get("/stats", status_code=status.HTTP_200_OK)
async def stats(
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db)
):
    """
    Retorna estadísticas completas del guardarropa del usuario.
    """
    usuario_id = str(usuario_actual["_id"])
    return await obtener_stats(usuario_id=usuario_id, db=db)


@router.delete("/{prenda_id}", status_code=status.HTTP_200_OK)
async def eliminar(
    prenda_id: str,
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db)
):
    """
    Elimina una prenda del guardarropa.
    Solo el propietario puede eliminar sus prendas.
    """
    usuario_id = str(usuario_actual["_id"])
    return await eliminar_prenda(
        prenda_id=prenda_id,
        usuario_id=usuario_id,
        db=db
    )

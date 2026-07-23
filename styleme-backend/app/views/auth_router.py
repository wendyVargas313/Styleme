# StyleMe - Router de Autenticación
from fastapi import APIRouter, Depends, File, Request, UploadFile, status

from app.config.database import get_db
from app.config.settings import settings
from app.schemas.user_schema import RegistroRequest, LoginRequest
from app.controllers.auth_controller import (
    registrar_usuario,
    login_usuario,
    obtener_perfil,
    subir_foto_perfil,
    obtener_foto_perfil,
    subir_avatar,
    obtener_avatar,
)
from app.middleware.auth_middleware import get_usuario_actual
from app.middleware.ratelimit_middleware import limiter

router = APIRouter(prefix="/auth", tags=["Autenticación"])


@router.post("/registro", status_code=status.HTTP_201_CREATED)
async def registro(datos: RegistroRequest, db=Depends(get_db)):
    """
    Registra un nuevo usuario en StyleMe.
    Retorna el JWT token para autenticación inmediata.
    """
    return await registrar_usuario(datos, db)


@router.post("/login", status_code=status.HTTP_200_OK)
@limiter.limit(f"{settings.MAX_REQUESTS_PER_MINUTE}/minute")
async def login(request: Request, datos: LoginRequest, db=Depends(get_db)):
    """
    Autentica al usuario y retorna el JWT token.
    """
    return await login_usuario(datos, db)


@router.get("/perfil", status_code=status.HTTP_200_OK)
async def perfil(
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db)
):
    """
    Retorna el perfil completo del usuario autenticado con estadísticas.
    Requiere: Authorization: Bearer JWT_TOKEN
    """
    return await obtener_perfil(usuario_actual, db)


@router.post("/foto-perfil", status_code=status.HTTP_200_OK)
async def subir_foto(
    foto: UploadFile = File(..., description="Foto de perfil JPG/PNG (máx 5MB)"),
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db)
):
    """
    Sube o actualiza la foto de perfil del usuario.
    Guarda en /uploads/{usuario_id}/perfil.jpg y actualiza MongoDB.
    """
    imagen_bytes = await foto.read()
    return await subir_foto_perfil(usuario_actual, imagen_bytes, db)


@router.get("/foto-perfil", status_code=status.HTTP_200_OK)
async def obtener_foto(
    usuario_actual=Depends(get_usuario_actual),
):
    """
    Retorna la URL de la foto de perfil del usuario (null si no tiene).
    """
    return await obtener_foto_perfil(usuario_actual)


@router.post("/foto-avatar", status_code=status.HTTP_200_OK)
async def subir_foto_avatar(
    foto: UploadFile = File(..., description="Avatar JPG/PNG (máx 5MB)"),
    usuario_actual=Depends(get_usuario_actual),
    db=Depends(get_db)
):
    """
    Sube o actualiza el avatar del usuario.
    Guarda en /uploads/{usuario_id}/avatar.jpg y actualiza MongoDB.
    """
    imagen_bytes = await foto.read()
    return await subir_avatar(usuario_actual, imagen_bytes, db)


@router.get("/foto-avatar", status_code=status.HTTP_200_OK)
async def obtener_foto_avatar(
    usuario_actual=Depends(get_usuario_actual),
):
    """
    Retorna la URL del avatar del usuario (null si no tiene).
    """
    return await obtener_avatar(usuario_actual)

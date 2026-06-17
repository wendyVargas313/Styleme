# StyleMe - Router de Autenticación
from fastapi import APIRouter, Depends, status

from app.config.database import get_db
from app.schemas.user_schema import RegistroRequest, LoginRequest
from app.controllers.auth_controller import (
    registrar_usuario,
    login_usuario,
    obtener_perfil
)
from app.middleware.auth_middleware import get_usuario_actual

router = APIRouter(prefix="/auth", tags=["Autenticación"])


@router.post("/registro", status_code=status.HTTP_201_CREATED)
async def registro(datos: RegistroRequest, db=Depends(get_db)):
    """
    Registra un nuevo usuario en StyleMe.
    Retorna el JWT token para autenticación inmediata.
    """
    return await registrar_usuario(datos, db)


@router.post("/login", status_code=status.HTTP_200_OK)
async def login(datos: LoginRequest, db=Depends(get_db)):
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

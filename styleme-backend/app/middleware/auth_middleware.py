# StyleMe - Middleware de autenticación JWT
import logging
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from bson import ObjectId
from datetime import datetime

from app.config.settings import settings
from app.config.database import get_db

logger = logging.getLogger(__name__)

# Esquema de autenticación Bearer
security = HTTPBearer()


def crear_token(usuario_id: str, email: str) -> str:
    """
    Crea un JWT token para el usuario.
    
    Args:
        usuario_id: ID del usuario en MongoDB
        email: Email del usuario
    
    Returns:
        str: JWT token firmado
    """
    from datetime import timedelta

    payload = {
        "sub": usuario_id,
        "email": email,
        "exp": datetime.utcnow() + timedelta(days=settings.JWT_EXPIRE_DAYS),
        "iat": datetime.utcnow()
    }

    token = jwt.encode(
        payload,
        settings.JWT_SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM
    )
    return token


def verificar_token(token: str) -> dict:
    """
    Verifica y decodifica un JWT token.
    
    Args:
        token: JWT token a verificar
    
    Returns:
        dict: Payload decodificado con usuario_id y email
    
    Raises:
        HTTPException: Si el token es inválido o expirado
    """
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM]
        )
        usuario_id = payload.get("sub")
        email = payload.get("email")

        if not usuario_id or not email:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token inválido: datos incompletos"
            )

        return {"usuario_id": usuario_id, "email": email}

    except JWTError as e:
        logger.warning(f"Token JWT inválido: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado",
            headers={"WWW-Authenticate": "Bearer"}
        )


async def get_usuario_actual(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db=Depends(get_db)
) -> dict:
    """
    Dependencia FastAPI para obtener el usuario actual desde el JWT.
    Valida el token y verifica que el usuario existe en MongoDB.
    
    Returns:
        dict: Documento del usuario en MongoDB
    
    Raises:
        HTTPException 401: Si el token es inválido
        HTTPException 404: Si el usuario no existe
    """
    # Verificar token JWT
    datos_token = verificar_token(credentials.credentials)
    usuario_id = datos_token["usuario_id"]

    try:
        # Buscar usuario en MongoDB
        usuario = await db.usuarios.find_one({
            "_id": ObjectId(usuario_id),
            "activo": True
        })

        if not usuario:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Usuario no encontrado o inactivo"
            )

        # Actualizar último acceso
        await db.usuarios.update_one(
            {"_id": ObjectId(usuario_id)},
            {"$set": {"ultimo_acceso": datetime.utcnow()}}
        )

        return usuario

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error obteniendo usuario actual: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Error de autenticación"
        )

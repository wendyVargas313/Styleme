# StyleMe - Controlador de Autenticación
import logging
from datetime import datetime
from bson import ObjectId
from fastapi import HTTPException, status
from passlib.context import CryptContext

from app.models.user_model import UserModel
from app.schemas.user_schema import RegistroRequest, LoginRequest
from app.middleware.auth_middleware import crear_token

logger = logging.getLogger(__name__)

# Contexto para hashear contraseñas con bcrypt
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto", bcrypt__rounds=12)


async def registrar_usuario(datos: RegistroRequest, db) -> dict:
    """
    Registra un nuevo usuario en la base de datos.
    
    Proceso:
    1. Verificar que el email no esté registrado
    2. Hashear la contraseña con bcrypt
    3. Crear documento en MongoDB
    4. Generar JWT token
    
    Returns:
        dict con success, mensaje, usuario y token
    """
    # Verificar si el email ya está registrado
    usuario_existente = await db.usuarios.find_one({"email": datos.email.lower()})
    if usuario_existente:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El email ya está registrado"
        )

    # Hashear contraseña
    password_hash = pwd_context.hash(datos.password)

    # Crear documento de usuario
    nuevo_usuario = UserModel.crear(
        nombre=datos.nombre,
        email=datos.email,
        password_hash=password_hash,
        genero=datos.genero or "otro"
    )

    # Insertar en MongoDB
    resultado = await db.usuarios.insert_one(nuevo_usuario)
    usuario_id = str(resultado.inserted_id)

    # Generar JWT token
    token = crear_token(usuario_id, datos.email.lower())

    logger.info(f"✅ Usuario registrado: {datos.email}")

    return {
        "success": True,
        "mensaje": "Usuario registrado exitosamente",
        "usuario": {
            "id": usuario_id,
            "nombre": datos.nombre,
            "email": datos.email.lower(),
            "genero": datos.genero or "otro",
            "creado_en": nuevo_usuario["creado_en"].isoformat()
        },
        "token": token
    }


async def login_usuario(datos: LoginRequest, db) -> dict:
    """
    Autentica un usuario y retorna el JWT token.
    
    Proceso:
    1. Buscar usuario por email
    2. Verificar contraseña con bcrypt
    3. Actualizar último acceso
    4. Generar y retornar JWT token
    
    Returns:
        dict con success, token y datos del usuario
    """
    # Buscar usuario por email
    usuario = await db.usuarios.find_one({
        "email": datos.email.lower(),
        "activo": True
    })

    if not usuario:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales incorrectas"
        )

    # Verificar contraseña
    if not pwd_context.verify(datos.password, usuario["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales incorrectas"
        )

    usuario_id = str(usuario["_id"])

    # Actualizar último acceso
    await db.usuarios.update_one(
        {"_id": usuario["_id"]},
        {"$set": {"ultimo_acceso": datetime.utcnow()}}
    )

    # Generar JWT token
    token = crear_token(usuario_id, datos.email.lower())

    logger.info(f"✅ Login exitoso: {datos.email}")

    return {
        "success": True,
        "token": token,
        "usuario": {
            "id": usuario_id,
            "nombre": usuario["nombre"],
            "email": usuario["email"]
        }
    }


async def obtener_perfil(usuario: dict, db) -> dict:
    """
    Obtiene el perfil completo del usuario con estadísticas.
    
    Returns:
        dict con datos del usuario y estadísticas
    """
    usuario_id = usuario["_id"]

    # Contar prendas activas
    total_prendas = await db.prendas.count_documents({
        "usuario_id": usuario_id,
        "activa": True
    })

    return {
        "id": str(usuario_id),
        "nombre": usuario.get("nombre", ""),
        "email": usuario.get("email", ""),
        "genero": usuario.get("genero", "otro"),
        "total_prendas": total_prendas,
        "total_outfits_generados": usuario.get("total_outfits_generados", 0),
        "creado_en": usuario.get("creado_en", datetime.utcnow()).isoformat()
    }

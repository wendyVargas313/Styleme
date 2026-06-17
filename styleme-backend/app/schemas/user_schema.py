# StyleMe - Schemas Pydantic para Usuario
from pydantic import BaseModel, EmailStr, Field, validator
from typing import Optional
import re


class RegistroRequest(BaseModel):
    """Schema para solicitud de registro de nuevo usuario."""
    nombre: str = Field(..., min_length=2, max_length=100, description="Nombre completo")
    email: EmailStr = Field(..., description="Correo electrónico")
    password: str = Field(..., min_length=8, description="Contraseña (mínimo 8 caracteres)")
    genero: Optional[str] = Field("otro", description="Género: masculino/femenino/otro")

    @validator("genero")
    def validar_genero(cls, v):
        opciones = ["masculino", "femenino", "otro"]
        if v not in opciones:
            raise ValueError(f"Género debe ser uno de: {opciones}")
        return v

    @validator("password")
    def validar_password(cls, v):
        if len(v) < 8:
            raise ValueError("La contraseña debe tener al menos 8 caracteres")
        return v


class LoginRequest(BaseModel):
    """Schema para solicitud de inicio de sesión."""
    email: EmailStr = Field(..., description="Correo electrónico")
    password: str = Field(..., description="Contraseña")


class UsuarioResponse(BaseModel):
    """Schema de respuesta con datos del usuario."""
    id: str
    nombre: str
    email: str
    genero: str
    total_outfits_generados: int = 0
    creado_en: str


class PerfilResponse(BaseModel):
    """Schema de respuesta para el perfil del usuario."""
    id: str
    nombre: str
    email: str
    genero: str
    total_prendas: int
    total_outfits_generados: int
    creado_en: str

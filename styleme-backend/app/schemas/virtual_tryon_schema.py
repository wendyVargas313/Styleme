# app/schemas/virtual_tryon_schema.py

from pydantic import BaseModel, Field
from typing import Literal


class VirtualTryOnRequest(BaseModel):
    """
    Esquema de entrada para solicitar virtual try-on desde Flutter.
    Las imágenes se envían como base64 JPG directamente en el body JSON.
    """

    imagen_persona: str = Field(
        ...,
        description="Foto de la persona en base64 (JPG/PNG)"
    )

    imagen_prenda: str = Field(
        ...,
        description="Foto de la prenda en base64 (JPG/PNG)"
    )

    categoria: Literal["upper", "lower", "dresses"] = Field(
        ...,
        description="Categoría de la prenda: upper, lower o dresses"
    )


class VirtualTryOnResponse(BaseModel):
    """
    Esquema de salida para Flutter.
    """

    ok: bool = True

    imagen_resultado: str = Field(
        ...,
        description="Imagen generada por CatVTON en base64 JPG"
    )

    tiempo_inferencia_catvton: float | None = Field(
        default=None,
        description="Tiempo de inferencia reportado por CatVTON en Colab"
    )

    tiempo_total_backend: float | None = Field(
        default=None,
        description="Tiempo total del flujo desde FastAPI"
    )


class VirtualTryOnErrorResponse(BaseModel):
    """
    Esquema de error estándar para virtual try-on.
    """

    ok: bool = False
    error: str
# StyleMe - Schemas Pydantic para Prenda
from pydantic import BaseModel, Field, validator
from typing import Optional


TEMPORADAS_VALIDAS = ["primavera", "verano", "otono", "invierno"]


class AgregarPrendaRequest(BaseModel):
    """Schema para agregar una prenda (datos del form junto a la imagen)."""
    temporada: str = Field(..., description="Temporada: primavera/verano/otono/invierno")
    notas: Optional[str] = Field("", max_length=500, description="Notas opcionales")

    @validator("temporada")
    def validar_temporada(cls, v):
        if v not in TEMPORADAS_VALIDAS:
            raise ValueError(f"Temporada debe ser una de: {TEMPORADAS_VALIDAS}")
        return v


class PrendaResponse(BaseModel):
    """Schema de respuesta con datos de una prenda."""
    id: str
    tipo: str
    color: str
    temporada: str
    confianza_yolo: float
    imagen_url: str
    notas: str
    veces_usado: int
    creado_en: str


class ListarPrendasResponse(BaseModel):
    """Schema de respuesta para listar prendas con paginación."""
    success: bool
    total: int
    page: int
    prendas: list


class StatsGuardarropaResponse(BaseModel):
    """Schema de respuesta para estadísticas del guardarropa."""
    total_prendas: int
    por_tipo: dict
    por_color: dict
    por_temporada: dict
    prenda_mas_usada: Optional[dict]
    prendas_nunca_usadas: int

# StyleMe - Schemas Pydantic para Outfit y Recomendaciones
from pydantic import BaseModel, Field, validator
from typing import Optional, List


TEMPORADAS_VALIDAS = ["primavera", "verano", "otono", "invierno"]


class RecomendarOutfitRequest(BaseModel):
    """Schema para solicitar recomendación de outfit."""
    prenda_id: str = Field(..., description="ID de la prenda base")
    temporada: str = Field("invierno", description="Temporada para el outfit")
    top_k: int = Field(3, ge=1, le=5, description="Número de recomendaciones")

    @validator("temporada")
    def validar_temporada(cls, v):
        if v not in TEMPORADAS_VALIDAS:
            raise ValueError(f"Temporada debe ser una de: {TEMPORADAS_VALIDAS}")
        return v


class DetalleCompatibilidad(BaseModel):
    """Detalle del score de compatibilidad."""
    coocurrencia: float
    color: float
    temporada: float


class RecomendacionItem(BaseModel):
    """Un ítem de recomendación con prenda y score."""
    prenda: dict
    score: float
    porcentaje: str
    detalle: dict


class OutfitResponse(BaseModel):
    """Schema de respuesta para un outfit generado."""
    success: bool
    prenda_base: dict
    recomendaciones: List[dict]
    outfit_id: str
    generado_en: str


class OutfitDiarioResponse(BaseModel):
    """Schema de respuesta para los outfits del día."""
    success: bool
    fecha: str
    temporada: str
    outfits_del_dia: List[dict]

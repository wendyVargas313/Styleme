# StyleMe - Schemas Pydantic para Outfit y Recomendaciones
from pydantic import BaseModel, Field, validator
from typing import Optional, List

from app.models.momento import MOMENTOS_VALIDOS, normalizar_momento


class RecomendarOutfitRequest(BaseModel):
    """Schema para solicitar recomendación de outfit."""
    prenda_id: str = Field(..., description="ID de la prenda base")
    momento: Optional[str] = Field(
        None, description="Momento para limitar candidatos: soleado/lluvioso/ambos. None = sin filtrar"
    )
    top_k: int = Field(3, ge=1, le=5, description="Número de recomendaciones")

    @validator("momento")
    def validar_momento(cls, v):
        if v is None:
            return v
        normalizado = normalizar_momento(v)
        if normalizado is None:
            raise ValueError(f"Momento debe ser uno de: {MOMENTOS_VALIDOS}")
        return normalizado


class DetalleCompatibilidad(BaseModel):
    """Detalle del score de compatibilidad."""
    coocurrencia: float
    color: float
    momento: float


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
    momento: Optional[str] = None
    outfits_del_dia: List[dict]

# StyleMe - Schemas Pydantic para Prenda
from pydantic import BaseModel, Field, validator
from typing import Optional

from app.models.momento import MOMENTOS_VALIDOS, MOMENTO_DEFAULT


class AgregarPrendaRequest(BaseModel):
    """Schema para agregar una prenda (datos del form junto a la imagen)."""
    momento: str = Field(MOMENTO_DEFAULT, description="Momento: dia/noche/ambos")
    notas: Optional[str] = Field("", max_length=500, description="Notas opcionales")

    @validator("momento")
    def validar_momento(cls, v):
        if v not in MOMENTOS_VALIDOS:
            raise ValueError(f"Momento debe ser uno de: {MOMENTOS_VALIDOS}")
        return v


class PrendaResponse(BaseModel):
    """Schema de respuesta con datos de una prenda."""
    id: str
    tipo: str
    color: str
    momento: str
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
    por_momento: dict
    prenda_mas_usada: Optional[dict]
    prendas_nunca_usadas: int

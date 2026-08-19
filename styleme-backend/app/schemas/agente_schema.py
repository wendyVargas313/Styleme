# app/schemas/agente_schema.py
"""Schemas Pydantic para el agente de recomendación de outfits (LLM)."""
from pydantic import BaseModel, ConfigDict, Field
from typing import List


class RecomendacionEventoRequest(BaseModel):
    """Schema para solicitar una recomendación de outfits para un evento."""
    descripcion_evento: str = Field(..., min_length=3, max_length=200, description="Descripción del evento")
    lugar: str = Field(..., min_length=2, max_length=100, description="Lugar del evento")
    fecha: str = Field(..., pattern=r"^\d{4}-\d{2}-\d{2}$", description="Fecha del evento (YYYY-MM-DD)")

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "descripcion_evento": "Grado universitario",
                "lugar": "Bogotá",
                "fecha": "2026-12-15",
            }
        }
    )


class PrendaEnOutfit(BaseModel):
    """Una prenda resuelta dentro de un outfit recomendado."""
    id: str
    tipo: str
    color: str
    imagen_url: str | None = None


class OutfitRecomendado(BaseModel):
    """Un outfit recomendado por el agente."""
    nombre: str
    prendas: List[PrendaEnOutfit]
    justificacion: str
    outfit_guardado_id: str | None = None


class MetaRecomendacion(BaseModel):
    """Metadata de la llamada al agente."""
    prendas_consideradas: int
    prendas_totales: int
    outfits_descartados: int
    modelo: str
    tokens_prompt: int
    latencia_ms: float


class RecomendacionEventoResponse(BaseModel):
    """Schema de respuesta de la recomendación de outfits para un evento."""
    evento: str
    clima: dict
    outfits: List[OutfitRecomendado]
    notas: List[str]
    meta: MetaRecomendacion
    id: str | None = None

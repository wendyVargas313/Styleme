# StyleMe - Schemas Pydantic para Feedback
from pydantic import BaseModel, Field, validator


class FeedbackRequest(BaseModel):
    """Schema para registrar feedback sobre un outfit."""
    outfit_id: str = Field(..., description="ID del outfit")
    feedback: str = Field(..., description="Tipo de feedback: liked/saved/disliked")

    @validator("feedback")
    def validar_feedback(cls, v):
        opciones = ["liked", "saved", "disliked"]
        if v not in opciones:
            raise ValueError(f"Feedback debe ser uno de: {opciones}")
        return v

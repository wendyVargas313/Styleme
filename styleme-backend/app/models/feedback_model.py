# StyleMe - Modelo de datos para Feedback en MongoDB
from datetime import datetime
from bson import ObjectId


class FeedbackModel:
    """
    El feedback se almacena dentro del documento outfit.
    Este modelo provee utilidades para manejar el feedback.
    """

    TIPOS_VALIDOS = ["liked", "saved", "disliked", "none"]

    @staticmethod
    def es_valido(feedback: str) -> bool:
        """Verifica si el tipo de feedback es válido."""
        return feedback in FeedbackModel.TIPOS_VALIDOS

    @staticmethod
    def crear_registro(
        outfit_id: str,
        usuario_id: str,
        feedback: str
    ) -> dict:
        """Crea un registro de feedback para logging/analytics."""
        return {
            "outfit_id": ObjectId(outfit_id),
            "usuario_id": ObjectId(usuario_id),
            "feedback": feedback,
            "registrado_en": datetime.utcnow()
        }

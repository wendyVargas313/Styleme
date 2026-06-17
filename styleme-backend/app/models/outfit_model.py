# StyleMe - Modelo de datos para Outfit en MongoDB
from datetime import datetime
from bson import ObjectId
from typing import List, Optional


class OutfitModel:
    """
    Estructura del documento de outfit en MongoDB.
    Colección: outfits
    """

    @staticmethod
    def crear(
        usuario_id: str,
        prenda_base_id: str,
        complementos: list,
        temporada: str,
        tipo_generacion: str = "manual"
    ) -> dict:
        """Crea un nuevo documento de outfit para insertar en MongoDB."""
        return {
            "usuario_id": ObjectId(usuario_id),
            "prenda_base_id": ObjectId(prenda_base_id),
            "complementos": complementos,
            "feedback": "none",
            "temporada": temporada,
            "tipo_generacion": tipo_generacion,
            "generado_en": datetime.utcnow()
        }

    @staticmethod
    def serializar(doc: dict) -> dict:
        """Convierte un documento MongoDB a dict serializable para JSON."""
        if not doc:
            return {}
        return {
            "id": str(doc["_id"]),
            "usuario_id": str(doc.get("usuario_id", "")),
            "prenda_base_id": str(doc.get("prenda_base_id", "")),
            "complementos": doc.get("complementos", []),
            "feedback": doc.get("feedback", "none"),
            "temporada": doc.get("temporada", ""),
            "tipo_generacion": doc.get("tipo_generacion", "manual"),
            "generado_en": doc.get("generado_en", datetime.utcnow()).isoformat()
        }

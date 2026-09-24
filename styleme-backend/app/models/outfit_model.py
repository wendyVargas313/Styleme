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
        momento: Optional[str],
        tipo_generacion: str = "manual"
    ) -> dict:
        """Crea un nuevo documento de outfit para insertar en MongoDB."""
        return {
            "usuario_id": ObjectId(usuario_id),
            "prenda_base_id": ObjectId(prenda_base_id),
            "complementos": complementos,
            "feedback": "none",
            "momento": momento,
            "tipo_generacion": tipo_generacion,
            "generado_en": datetime.utcnow()
        }

    @staticmethod
    def serializar(doc: dict) -> dict:
        """
        Convierte un documento MongoDB a dict serializable para JSON.

        "momento" se expone tal cual está guardado, sin derivar nada de la
        vieja "temporada": los outfits históricos (previos a esta migración)
        no tienen "momento" y quedan en None a propósito.
        """
        if not doc:
            return {}
        return {
            "id": str(doc["_id"]),
            "usuario_id": str(doc.get("usuario_id", "")),
            "prenda_base_id": str(doc.get("prenda_base_id", "")),
            "complementos": doc.get("complementos", []),
            "feedback": doc.get("feedback", "none"),
            "momento": doc.get("momento"),
            "tipo_generacion": doc.get("tipo_generacion", "manual"),
            "generado_en": doc.get("generado_en", datetime.utcnow()).isoformat()
        }

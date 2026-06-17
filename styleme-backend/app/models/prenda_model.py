# StyleMe - Modelo de datos para Prenda en MongoDB
from datetime import datetime
from bson import ObjectId
from typing import Optional


class PrendaModel:
    """
    Estructura del documento de prenda en MongoDB.
    Colección: prendas
    """

    @staticmethod
    def crear(
        usuario_id: str,
        tipo: str,
        color: str,
        temporada: str,
        confianza_yolo: float,
        imagen_url: str,
        notas: str = ""
    ) -> dict:
        """Crea un nuevo documento de prenda para insertar en MongoDB."""
        return {
            "usuario_id": ObjectId(usuario_id),
            "tipo": tipo,
            "color": color,
            "temporada": temporada,
            "confianza_yolo": round(confianza_yolo, 4),
            "imagen_url": imagen_url,
            "notas": notas,
            "veces_usado": 0,
            "activa": True,
            "creado_en": datetime.utcnow()
        }

    @staticmethod
    def serializar(doc: dict) -> dict:
        """Convierte un documento MongoDB a dict serializable para JSON."""
        if not doc:
            return {}
        return {
            "id": str(doc["_id"]),
            "usuario_id": str(doc.get("usuario_id", "")),
            "tipo": doc.get("tipo", ""),
            "color": doc.get("color", ""),
            "temporada": doc.get("temporada", ""),
            "confianza_yolo": doc.get("confianza_yolo", 0.0),
            "imagen_url": doc.get("imagen_url", ""),
            "notas": doc.get("notas", ""),
            "veces_usado": doc.get("veces_usado", 0),
            "activa": doc.get("activa", True),
            "creado_en": doc.get("creado_en", datetime.utcnow()).isoformat()
        }

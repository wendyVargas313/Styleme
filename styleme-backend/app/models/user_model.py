# StyleMe - Modelo de datos para Usuario en MongoDB
from datetime import datetime
from bson import ObjectId
from typing import Optional


class UserModel:
    """
    Estructura del documento de usuario en MongoDB.
    Colección: usuarios
    """

    @staticmethod
    def crear(
        nombre: str,
        email: str,
        password_hash: str,
        genero: str = "otro"
    ) -> dict:
        """Crea un nuevo documento de usuario para insertar en MongoDB."""
        return {
            "nombre": nombre,
            "email": email.lower().strip(),
            "password_hash": password_hash,
            "genero": genero,
            "activo": True,
            "total_outfits_generados": 0,
            "foto_perfil_url": None,
            "creado_en": datetime.utcnow(),
            "ultimo_acceso": datetime.utcnow()
        }

    @staticmethod
    def serializar(doc: dict) -> dict:
        """Convierte un documento MongoDB a dict serializable para JSON."""
        if not doc:
            return {}
        return {
            "id": str(doc["_id"]),
            "nombre": doc.get("nombre", ""),
            "email": doc.get("email", ""),
            "genero": doc.get("genero", "otro"),
            "activo": doc.get("activo", True),
            "total_outfits_generados": doc.get("total_outfits_generados", 0),
            "foto_perfil_url": doc.get("foto_perfil_url", None),
            "creado_en": doc.get("creado_en", datetime.utcnow()).isoformat(),
            "ultimo_acceso": doc.get("ultimo_acceso", datetime.utcnow()).isoformat()
        }

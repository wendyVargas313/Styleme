# StyleMe - Modelo de datos para Prenda en MongoDB
from datetime import datetime
from bson import ObjectId
from typing import List, Optional

from app.models.momento import momento_de_prenda


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
        momento: str,
        confianza_yolo: float,
        imagen_url: str,
        notas: str = "",
        color_metodo: Optional[str] = None,
        color_rgb: Optional[List[int]] = None,
        color_version: Optional[int] = None
    ) -> dict:
        """
        Crea un nuevo documento de prenda para insertar en MongoDB.
        color_metodo ("mascara_mlkit" | "mascara_rembg" | "recorte"),
        color_rgb ([r, g, b] 0–255 del color dominante) y color_version
        (clasificación usada; 2 = C2) son solo registro interno: no se
        incluyen en serializar().
        """
        return {
            "usuario_id": ObjectId(usuario_id),
            "tipo": tipo,
            "color": color,
            "color_metodo": color_metodo,
            "color_rgb": color_rgb,
            "color_version": color_version,
            "momento": momento,
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
            "momento": momento_de_prenda(doc),
            "confianza_yolo": doc.get("confianza_yolo", 0.0),
            "imagen_url": doc.get("imagen_url", ""),
            "notas": doc.get("notas", ""),
            "veces_usado": doc.get("veces_usado", 0),
            "activa": doc.get("activa", True),
            "editado_por_usuario": doc.get("editado_por_usuario", False),
            "creado_en": doc.get("creado_en", datetime.utcnow()).isoformat()
        }

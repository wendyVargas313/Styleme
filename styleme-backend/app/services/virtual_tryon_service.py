# app/services/virtual_tryon_service.py

import base64
import io
import os
import time
from typing import Any

import httpx
from bson import ObjectId
from bson.errors import InvalidId
from motor.motor_asyncio import AsyncIOMotorDatabase, AsyncIOMotorGridFSBucket
from PIL import Image


class VirtualTryOnService:
    """
    Servicio async para virtual try-on.

    Responsabilidades:
    - Descargar imágenes desde MongoDB GridFS usando Motor.
    - Convertir imágenes a base64 JPG.
    - Llamar al microservicio CatVTON en Colab/ngrok.
    - Retornar la imagen generada para Flutter.
    """

    def __init__(self, db: AsyncIOMotorDatabase):
        self.db = db
        self.fs = AsyncIOMotorGridFSBucket(db)

        self.tryon_url = os.getenv("CATVTON_TRYON_URL", "").strip()

        if not self.tryon_url:
            raise ValueError(
                "No se encontró la variable de entorno CATVTON_TRYON_URL"
            )

    async def _descargar_imagen_gridfs(self, file_id: str) -> bytes:
        """
        Descarga una imagen desde GridFS usando su ObjectId.
        """

        try:
            object_id = ObjectId(file_id)
        except InvalidId as e:
            raise ValueError(f"ID de archivo inválido: {file_id}") from e

        try:
            grid_out = await self.fs.open_download_stream(object_id)
            image_bytes = await grid_out.read()
            return image_bytes

        except Exception as e:
            raise ValueError(
                f"No se pudo descargar la imagen desde GridFS con id: {file_id}"
            ) from e

    def _bytes_a_base64_jpg(self, image_bytes: bytes) -> str:
        """
        Convierte bytes de imagen a base64 JPG.
        Esto normaliza PNG, WEBP u otros formatos a JPG.
        """

        try:
            image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        except Exception as e:
            raise ValueError("El archivo descargado no es una imagen válida") from e

        buffer = io.BytesIO()
        image.save(buffer, format="JPEG", quality=95)

        return base64.b64encode(buffer.getvalue()).decode("utf-8")

    async def _llamar_microservicio_tryon(
        self,
        imagen_persona_b64: str,
        imagen_prenda_b64: str,
        categoria: str
    ) -> dict[str, Any]:
        """
        Llama al microservicio CatVTON expuesto por ngrok.
        """

        payload = {
            "imagen_persona": imagen_persona_b64,
            "imagen_prenda": imagen_prenda_b64,
            "categoria": categoria
        }

        headers = {
            "Content-Type": "application/json",
            "ngrok-skip-browser-warning": "true"
        }

        async with httpx.AsyncClient(timeout=300.0) as client:
            response = await client.post(
                self.tryon_url,
                json=payload,
                headers=headers
            )

        if response.status_code != 200:
            raise RuntimeError(
                f"Error al llamar CatVTON. "
                f"Status: {response.status_code}. "
                f"Respuesta: {response.text}"
            )

        data = response.json()

        if not data.get("ok"):
            raise RuntimeError(
                f"CatVTON respondió ok=False. Respuesta: {data}"
            )

        return data

    async def generar_tryon_desde_bytes(
        self,
        persona_bytes: bytes,
        prenda_bytes: bytes,
        categoria: str
    ) -> dict[str, Any]:
        """
        Flujo directo desde bytes de imagen (sin GridFS).
        Usado cuando Flutter sube las imágenes como multipart.
        """
        if categoria not in ["upper", "lower", "dresses"]:
            raise ValueError("La categoría debe ser 'upper', 'lower' o 'dresses'")

        start_time = time.time()

        imagen_persona_b64 = self._bytes_a_base64_jpg(persona_bytes)
        imagen_prenda_b64 = self._bytes_a_base64_jpg(prenda_bytes)

        resultado = await self._llamar_microservicio_tryon(
            imagen_persona_b64=imagen_persona_b64,
            imagen_prenda_b64=imagen_prenda_b64,
            categoria=categoria
        )

        total_time = time.time() - start_time
        return {
            "imagen_resultado": resultado["imagen_resultado"],
            "tiempo_inferencia_catvton": resultado.get("tiempo_inferencia"),
            "tiempo_total_backend": round(total_time, 2)
        }

    async def generar_tryon(
        self,
        persona_file_id: str,
        prenda_file_id: str,
        categoria: str
    ) -> dict[str, Any]:
        """
        Flujo completo:
        1. Descarga foto de persona desde GridFS.
        2. Descarga imagen de prenda desde GridFS.
        3. Convierte ambas a base64.
        4. Llama a CatVTON en Colab.
        5. Retorna imagen resultado base64.
        """

        if categoria not in ["upper", "lower", "dresses"]:
            raise ValueError(
                "La categoría debe ser 'upper', 'lower' o 'dresses'"
            )

        start_time = time.time()

        persona_bytes = await self._descargar_imagen_gridfs(persona_file_id)
        prenda_bytes = await self._descargar_imagen_gridfs(prenda_file_id)

        imagen_persona_b64 = self._bytes_a_base64_jpg(persona_bytes)
        imagen_prenda_b64 = self._bytes_a_base64_jpg(prenda_bytes)

        resultado = await self._llamar_microservicio_tryon(
            imagen_persona_b64=imagen_persona_b64,
            imagen_prenda_b64=imagen_prenda_b64,
            categoria=categoria
        )

        total_time = time.time() - start_time

        return {
            "imagen_resultado": resultado["imagen_resultado"],
            "tiempo_inferencia_catvton": resultado.get("tiempo_inferencia"),
            "tiempo_total_backend": round(total_time, 2)
        }
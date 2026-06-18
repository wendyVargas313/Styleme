# app/controllers/virtual_tryon_controller.py

from fastapi import APIRouter, HTTPException, Depends
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.config.database import get_db
from app.schemas.virtual_tryon_schema import (
    VirtualTryOnRequest,
    VirtualTryOnResponse,
)
from app.services.virtual_tryon_service import VirtualTryOnService


async def generar_tryon_multipart(
    persona_bytes: bytes,
    prenda_bytes: bytes,
    categoria: str,
    db: AsyncIOMotorDatabase,
) -> VirtualTryOnResponse:
    """
    Genera virtual try-on a partir de bytes de imagen directos.
    Usado por el endpoint multipart de Flutter.
    """
    try:
        if categoria not in ["upper", "lower", "dresses"]:
            raise HTTPException(
                status_code=400,
                detail="La categoría debe ser 'upper', 'lower' o 'dresses'"
            )

        service = VirtualTryOnService(db)
        resultado = await service.generar_tryon_desde_bytes(
            persona_bytes=persona_bytes,
            prenda_bytes=prenda_bytes,
            categoria=categoria
        )

        return VirtualTryOnResponse(
            ok=True,
            imagen_resultado=resultado["imagen_resultado"],
            tiempo_inferencia_catvton=resultado.get("tiempo_inferencia_catvton"),
            tiempo_total_backend=resultado.get("tiempo_total_backend")
        )

    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=502, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error interno generando virtual try-on: {str(e)}"
        )


router = APIRouter(
    prefix="/virtual-tryon",
    tags=["Virtual Try-On"]
)


@router.post(
    "/generar",
    response_model=VirtualTryOnResponse,
    summary="Generar imagen virtual try-on con CatVTON"
)
async def generar_virtual_tryon(
    request: VirtualTryOnRequest,
    db: AsyncIOMotorDatabase = Depends(get_db)
):
    """
    Endpoint que recibe desde Flutter:
    - persona_file_id: ID GridFS de la foto del usuario
    - prenda_file_id: ID GridFS de la imagen de la prenda
    - categoria: upper | lower | dresses

    Luego:
    - descarga las imágenes desde MongoDB GridFS
    - llama al microservicio CatVTON en Colab/ngrok
    - retorna la imagen generada en base64
    """

    try:
        if db is None:
            raise RuntimeError("La conexión a MongoDB no está disponible")

        service = VirtualTryOnService(db)

        resultado = await service.generar_tryon(
            persona_file_id=request.persona_file_id,
            prenda_file_id=request.prenda_file_id,
            categoria=request.categoria
        )

        return VirtualTryOnResponse(
            ok=True,
            imagen_resultado=resultado["imagen_resultado"],
            tiempo_inferencia_catvton=resultado.get("tiempo_inferencia_catvton"),
            tiempo_total_backend=resultado.get("tiempo_total_backend")
        )

    except ValueError as e:
        raise HTTPException(
            status_code=400,
            detail=str(e)
        )

    except RuntimeError as e:
        raise HTTPException(
            status_code=502,
            detail=str(e)
        )

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error interno generando virtual try-on: {str(e)}"
        )


@router.get(
    "/health",
    summary="Verificar estado del módulo virtual try-on"
)
async def health_virtual_tryon():
    """
    Endpoint simple para verificar que el controller está registrado.
    """

    return {
        "ok": True,
        "modulo": "virtual_tryon",
        "mensaje": "Controller virtual try-on activo"
    }
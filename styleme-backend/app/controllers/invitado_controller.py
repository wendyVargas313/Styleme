# StyleMe - Controlador del Modo Invitado
import logging
import os
import uuid
import tempfile
import traceback
from datetime import datetime, timedelta
from pathlib import Path
from fastapi import HTTPException, status, UploadFile
from typing import List

from app.ml.ml_agent import ml_agent
from app.ml.recommender import RecomendadorOutfits

logger = logging.getLogger(__name__)


async def probar_como_invitado(
    imagenes: List[UploadFile],
    device_id: str,
    temporada: str,
    db
) -> dict:
    """
    Permite a un usuario invitado probar StyleMe sin registrarse.
    
    Restricciones:
    - 1 uso por dispositivo cada 24 horas
    - Máximo 10 imágenes
    - Las imágenes se eliminan al finalizar
    
    Proceso:
    1. Verificar que device_id no haya usado la prueba en 24h
    2. Procesar imágenes con agente ML
    3. Generar 1 outfit de prueba
    4. Registrar uso y eliminar imágenes
    
    Returns:
        dict con prendas_detectadas y outfit_prueba
    """
    # Verificar límite de uso por dispositivo
    ahora = datetime.utcnow()
    registro_existente = await db.invitados.find_one({
        "device_id": device_id,
        "expira_en": {"$gt": ahora}
    })

    if registro_existente:
        tiempo_restante = registro_existente["expira_en"] - ahora
        horas_restantes = int(tiempo_restante.total_seconds() / 3600)
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Ya usaste el modo invitado. Disponible en {horas_restantes} horas. "
                   f"¡Crea una cuenta gratis para acceso ilimitado!"
        )

    # Validar cantidad de imágenes
    if not imagenes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debes enviar al menos 1 imagen"
        )

    if len(imagenes) > 10:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Máximo 10 imágenes en modo invitado"
        )

    archivos_temporales = []
    prendas_detectadas = []

    logger.info(f"🔍 Invitado: {len(imagenes)} imágenes, temporada={temporada}, device={device_id[:8]}...")

    try:
        # Procesar cada imagen con el agente ML
        for idx, imagen in enumerate(imagenes):
            logger.info(f"  📷 Imagen [{idx+1}/{len(imagenes)}]: filename={imagen.filename}, content_type={imagen.content_type}")
            contenido = await imagen.read()
            logger.info(f"  📦 Tamaño bytes: {len(contenido)}")

            if len(contenido) == 0:
                logger.warning(f"  ⚠️ Imagen [{idx+1}] vacía, saltando")
                continue

            # Procesar con ML
            logger.info(f"  🤖 Procesando imagen [{idx+1}] con ML...")
            resultado = await ml_agent.procesar_imagen(contenido)
            logger.info(f"  ✅ Resultado ML [{idx+1}]: tipo={resultado.get('tipo')}, color={resultado.get('color')}, confianza={resultado.get('confianza', 0):.2%}")

            prenda_detectada = {
                "tipo": resultado.get("tipo", "other"),
                "color": resultado.get("color", "negro"),
                "confianza": resultado.get("confianza", 0.0),
                "temporada": temporada
            }
            prendas_detectadas.append(prenda_detectada)

        logger.info(f"📊 Prendas detectadas: {len(prendas_detectadas)}")

        if not prendas_detectadas:
            logger.warning("⚠️ Ninguna prenda detectada en las imágenes")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No se pudieron procesar las imágenes"
            )

        # Generar outfit de prueba
        outfit_prueba = None
        if len(prendas_detectadas) >= 2:
            logger.info("👗 Generando outfit de prueba...")
            for i, prenda in enumerate(prendas_detectadas):
                prenda["id"] = f"invitado_{i}"

            recomendaciones = await ml_agent.recomendar_outfit(
                prendas_detectadas[0],
                prendas_detectadas[1:],
                top_k=3
            )
            logger.info(f"✅ Recomendaciones generadas: {len(recomendaciones)} complementos")

            outfit_prueba = {
                "prenda_base": prendas_detectadas[0],
                "complementos": recomendaciones
            }
        elif prendas_detectadas:
            logger.info("ℹ️ Solo 1 prenda — outfit sin complementos")
            outfit_prueba = {
                "prenda_base": prendas_detectadas[0],
                "complementos": [],
                "nota": "Agrega más prendas para ver outfits completos"
            }

        # Registrar uso del dispositivo (bloquear por 24h)
        logger.info("💾 Guardando registro de uso en DB...")
        expira = ahora + timedelta(hours=24)
        await db.invitados.insert_one({
            "device_id": device_id,
            "usado_en": ahora,
            "expira_en": expira,
            "n_prendas": len(prendas_detectadas)
        })

        logger.info(f"✅ Modo invitado completado para device: {device_id[:8]}...")

        return {
            "success": True,
            "prendas_detectadas": prendas_detectadas,
            "outfit_prueba": outfit_prueba,
            "mensaje": "¿Te gustó StyleMe? ¡Crea tu cuenta gratis para guardar tu guardarropa "
                       "y recibir recomendaciones personalizadas todos los días!"
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error en modo invitado: {type(e).__name__}: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error procesando las imágenes: {type(e).__name__}: {e}"
        )

# app/services/groq_service.py
"""Servicio de transporte hacia Groq: envía mensajes ya armados y devuelve la respuesta del modelo."""

import json
import time

from fastapi import HTTPException
from groq import (
    AsyncGroq,
    APIConnectionError,
    APIStatusError,
    APITimeoutError,
    AuthenticationError,
    BadRequestError,
    GroqError,
    InternalServerError,
    NotFoundError,
    PermissionDeniedError,
    RateLimitError,
    UnprocessableEntityError,
)

from app.config.settings import settings

_client: AsyncGroq | None = None


def _get_client() -> AsyncGroq:
    """Instancia y cachea el cliente AsyncGroq de forma perezosa (no al importar el módulo)."""
    global _client
    if _client is not None:
        return _client

    if not settings.GROQ_API_KEY:
        raise HTTPException(status_code=500, detail="Falta configurar GROQ_API_KEY")
    if not settings.GROQ_MODEL:
        raise HTTPException(status_code=500, detail="Falta configurar GROQ_MODEL")

    # max_retries=0: este endpoint es sincrono con el usuario esperando; el
    # reintento automatico del SDK espera el retry-after dentro de la misma
    # llamada, lo que produjo latencias medidas de 24 s. Se prefiere fallar
    # rapido y propagar el 429 con su retry-after para que el cliente decida.
    _client = AsyncGroq(api_key=settings.GROQ_API_KEY, timeout=15.0, max_retries=0)
    return _client


async def completar(
    mensajes: list[dict],
    *,
    json_mode: bool = False,
    temperatura: float = 0.7,
    max_tokens: int = 1024,
) -> dict:
    """
    Envía `mensajes` (formato chat de Groq/OpenAI) al modelo configurado y
    devuelve su respuesta.

    Entrada:
        mensajes: lista no vacía de dicts con roles/contenido de chat.
        json_mode: si True, exige respuesta JSON válida (requiere que la
            palabra "json" aparezca en algún mensaje; lo exige la API de Groq).
        temperatura: temperatura de muestreo.
        max_tokens: tope de tokens de la respuesta.

    Salida (dict):
        contenido: texto crudo de la respuesta.
        contenido_json: dict parseado si json_mode=True, si no None.
        modelo: modelo que efectivamente respondió.
        tokens_prompt: tokens consumidos por el prompt.
        tokens_respuesta: tokens generados en la respuesta.
        finish_reason: motivo de finalización reportado por la API.
        latencia_ms: duración de la llamada en milisegundos.
    """
    if not isinstance(mensajes, list) or not mensajes:
        raise HTTPException(status_code=500, detail="'mensajes' debe ser una lista no vacía")

    client = _get_client()

    kwargs: dict = {
        "model": settings.GROQ_MODEL,
        "messages": mensajes,
        "temperature": temperatura,
        # Groq deprecó `max_tokens` en favor de `max_completion_tokens`.
        "max_completion_tokens": max_tokens,
    }

    if json_mode:
        # Groq rechaza el modo JSON con 400 si la palabra "json" no aparece
        # literalmente en el contenido de algún mensaje. Se valida localmente
        # para dar un error claro en vez de un 400 remoto confuso.
        contiene_json = any("json" in str(m.get("content", "")).lower() for m in mensajes)
        if not contiene_json:
            raise HTTPException(
                status_code=500,
                detail="json_mode=True requiere que la palabra 'json' aparezca en el contenido de algún mensaje",
            )
        kwargs["response_format"] = {"type": "json_object"}

    inicio = time.perf_counter()
    try:
        respuesta = await client.chat.completions.create(**kwargs)
    # El orden de estos except es crítico: en groq==1.6.0 las excepciones son
    # jerárquicas (APITimeoutError hereda de APIConnectionError; todas las de
    # status heredan de APIStatusError -> APIError -> GroqError). Las ramas
    # específicas deben ir antes que las generales o quedarían inalcanzables.
    except RateLimitError as e:
        retry_after = None
        try:
            retry_after = e.response.headers.get("retry-after")
        except Exception:
            pass
        detail = "Límite de tasa excedido en Groq"
        if retry_after:
            detail += f" (retry-after: {retry_after})"
        raise HTTPException(status_code=429, detail=detail)
    except AuthenticationError:
        raise HTTPException(status_code=500, detail="Fallo de autenticación con Groq: revisar configuración de GROQ_API_KEY")
    except PermissionDeniedError:
        raise HTTPException(status_code=500, detail="Groq denegó el permiso para esta operación")
    except NotFoundError:
        raise HTTPException(
            status_code=500,
            detail="Groq no encontró el recurso solicitado; es posible que el modelo en GROQ_MODEL haya sido retirado",
        )
    except BadRequestError as e:
        raise HTTPException(status_code=502, detail=f"Solicitud inválida a Groq: {e}")
    except UnprocessableEntityError as e:
        raise HTTPException(status_code=502, detail=f"Groq no pudo procesar la solicitud: {e}")
    except InternalServerError as e:
        raise HTTPException(status_code=502, detail=f"Error interno de Groq: {e}")
    except APITimeoutError:
        raise HTTPException(status_code=504, detail="Tiempo de espera agotado al llamar a Groq")
    except APIConnectionError as e:
        raise HTTPException(status_code=503, detail=f"No se pudo conectar con Groq: {e}")
    except APIStatusError as e:
        raise HTTPException(status_code=502, detail=f"Error de Groq: {e}")
    except GroqError as e:
        raise HTTPException(status_code=500, detail=f"Error inesperado del SDK de Groq: {e}")

    latencia_ms = round((time.perf_counter() - inicio) * 1000, 2)

    if not respuesta.choices or respuesta.choices[0].message.content is None:
        raise HTTPException(status_code=502, detail="Groq devolvió una respuesta sin contenido")

    eleccion = respuesta.choices[0]
    contenido = eleccion.message.content
    finish_reason = eleccion.finish_reason

    if json_mode and finish_reason == "length":
        raise HTTPException(
            status_code=502,
            detail="La respuesta JSON de Groq quedó truncada por agotar max_tokens",
        )

    contenido_json = None
    if json_mode:
        try:
            contenido_json = json.loads(contenido)
        except json.JSONDecodeError as e:
            raise HTTPException(status_code=502, detail=f"Groq devolvió JSON inválido: {e}")

    tokens_prompt = respuesta.usage.prompt_tokens if respuesta.usage is not None else 0
    tokens_respuesta = respuesta.usage.completion_tokens if respuesta.usage is not None else 0

    return {
        "contenido": contenido,
        "contenido_json": contenido_json,
        "modelo": respuesta.model,
        "tokens_prompt": tokens_prompt,
        "tokens_respuesta": tokens_respuesta,
        "finish_reason": finish_reason,
        "latencia_ms": latencia_ms,
    }

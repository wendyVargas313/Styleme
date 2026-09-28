# app/services/groq_service.py
"""Servicio de transporte hacia Groq: envía mensajes ya armados y devuelve la respuesta del modelo."""

import json
import logging
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

logger = logging.getLogger(__name__)

_client: AsyncGroq | None = None


class _ModeloNoDisponible(Exception):
    """Groq respondió que el modelo no existe o fue retirado (404/model_decommissioned)."""

    def __init__(self, causa: GroqError):
        self.causa = causa


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


def _reasoning_effort_para(modelo: str) -> str | None:
    """
    Nivel de razonamiento según la familia del modelo (Groq exige valores
    distintos por familia, ver console.groq.com/docs/reasoning):
    - openai/gpt-oss-*: el configurado en GROQ_REASONING_EFFORT (esta familia
      solo admite "low"/"medium"/"high", no "none").
    - qwen/*: "none" — sin razonamiento, para que message.content sea
      directamente el JSON esperado por json_mode.
    - cualquier otro modelo: no se envía el parámetro (no lo soporta).
    """
    if modelo.startswith("openai/gpt-oss"):
        return settings.GROQ_REASONING_EFFORT
    if modelo.startswith("qwen/"):
        return "none"
    return None


def _codigo_error_groq(e: GroqError) -> str | None:
    """Código de error del cuerpo de la respuesta de Groq (p. ej. "model_decommissioned"), si lo hay."""
    body = getattr(e, "body", None)
    if isinstance(body, dict):
        error = body.get("error")
        if isinstance(error, dict):
            codigo = error.get("code")
            if isinstance(codigo, str):
                return codigo
    return None


async def _intentar(
    client: AsyncGroq,
    modelo: str,
    mensajes: list[dict],
    json_mode: bool,
    temperatura: float,
    max_tokens: int,
) -> dict:
    """Un intento de chat completion contra `modelo`. Lanza _ModeloNoDisponible
    si Groq responde que el modelo no existe o fue retirado (para que el
    llamador decida si reintenta con el respaldo)."""
    kwargs: dict = {
        "model": modelo,
        "messages": mensajes,
        "temperature": temperatura,
        # Groq deprecó `max_tokens` en favor de `max_completion_tokens`.
        "max_completion_tokens": max_tokens,
    }

    reasoning_effort = _reasoning_effort_para(modelo)
    if reasoning_effort is not None:
        kwargs["reasoning_effort"] = reasoning_effort

    if json_mode:
        kwargs["response_format"] = {"type": "json_object"}

    inicio = time.perf_counter()
    try:
        respuesta = await client.chat.completions.create(**kwargs)
    # El orden de estos except es crítico: en groq==1.6.0 las excepciones son
    # jerárquicas (APITimeoutError hereda de APIConnectionError; todas las de
    # status heredan de APIStatusError -> APIError -> GroqError). Las ramas
    # específicas deben ir antes que las generales o quedarían inalcanzables.
    except NotFoundError as e:
        raise _ModeloNoDisponible(e) from e
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
    except BadRequestError as e:
        # Algunos modelos retirados responden 400 con code="model_decommissioned"
        # en vez de 404 — se trata igual que NotFoundError (reintentable).
        if _codigo_error_groq(e) == "model_decommissioned":
            raise _ModeloNoDisponible(e) from e
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

    if not respuesta.choices:
        raise HTTPException(status_code=502, detail="Groq devolvió una respuesta sin choices")

    eleccion = respuesta.choices[0]
    # Se toma solo message.content: el campo message.reasoning (razonamiento
    # de modelos como gpt-oss/qwen) se ignora deliberadamente, nunca es parte
    # de la respuesta que se usa.
    contenido = eleccion.message.content
    finish_reason = eleccion.finish_reason

    if not contenido or not contenido.strip():
        # Vacío es un error claro y distinto de "JSON inválido": típicamente
        # significa que el presupuesto de tokens se agotó en razonamiento
        # antes de emitir la respuesta.
        raise HTTPException(
            status_code=502,
            detail=f"Groq ({modelo}) devolvió una respuesta vacía en message.content",
        )

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


async def completar(
    mensajes: list[dict],
    *,
    json_mode: bool = False,
    temperatura: float = 0.7,
    max_tokens: int = 2048,
) -> dict:
    """
    Envía `mensajes` (formato chat de Groq/OpenAI) al modelo configurado y
    devuelve su respuesta. Si el modelo (GROQ_MODEL) fue retirado de Groq
    (404 o 400 con code="model_decommissioned"), reintenta una única vez con
    GROQ_MODEL_FALLBACK antes de fallar.

    Entrada:
        mensajes: lista no vacía de dicts con roles/contenido de chat.
        json_mode: si True, exige respuesta JSON válida (requiere que la
            palabra "json" aparezca en algún mensaje; lo exige la API de Groq).
        temperatura: temperatura de muestreo.
        max_tokens: tope de tokens de la respuesta (incluye los tokens de
            razonamiento de modelos como gpt-oss/qwen, que se generan antes
            del contenido final).

    Salida (dict):
        contenido: texto crudo de la respuesta.
        contenido_json: dict parseado si json_mode=True, si no None.
        modelo: modelo que efectivamente respondió (puede ser el de respaldo).
        tokens_prompt: tokens consumidos por el prompt.
        tokens_respuesta: tokens generados en la respuesta.
        finish_reason: motivo de finalización reportado por la API.
        latencia_ms: duración de la llamada en milisegundos.
    """
    if not isinstance(mensajes, list) or not mensajes:
        raise HTTPException(status_code=500, detail="'mensajes' debe ser una lista no vacía")

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

    client = _get_client()

    try:
        return await _intentar(client, settings.GROQ_MODEL, mensajes, json_mode, temperatura, max_tokens)
    except _ModeloNoDisponible as e:
        logger.warning(
            f"Groq: el modelo configurado '{settings.GROQ_MODEL}' no está disponible "
            f"({e.causa.__class__.__name__}: {e.causa}); reintentando una vez con "
            f"el respaldo '{settings.GROQ_MODEL_FALLBACK}'"
        )
        try:
            return await _intentar(
                client, settings.GROQ_MODEL_FALLBACK, mensajes, json_mode, temperatura, max_tokens
            )
        except _ModeloNoDisponible as e2:
            raise HTTPException(
                status_code=500,
                detail=(
                    f"Groq no encontró ni el modelo configurado ('{settings.GROQ_MODEL}') "
                    f"ni el de respaldo ('{settings.GROQ_MODEL_FALLBACK}'); revisar "
                    f"GROQ_MODEL/GROQ_MODEL_FALLBACK, es posible que ambos hayan sido retirados"
                ),
            ) from e2.causa

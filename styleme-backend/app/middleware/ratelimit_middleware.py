# StyleMe - Configuración de Rate Limiting
from fastapi import Request
from fastapi.responses import JSONResponse
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)


def configurar_ratelimit(app):
    """
    Registra el limiter global de slowapi y su exception handler.
    Los endpoints que quieran aplicar un límite deben decorarse individualmente
    con @limiter.limit(...) (importar `limiter` desde este módulo).
    """
    app.state.limiter = limiter

    @app.exception_handler(RateLimitExceeded)
    async def ratelimit_handler(request: Request, exc: RateLimitExceeded):
        return JSONResponse(
            status_code=429,
            content={"detail": "Demasiados intentos. Espera un momento e intenta de nuevo."},
        )

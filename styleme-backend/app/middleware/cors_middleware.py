# StyleMe - Configuración de CORS
import os

from fastapi.middleware.cors import CORSMiddleware


def configurar_cors(app):
    """
    Configura el middleware CORS para la aplicación FastAPI.
    Permite solicitudes desde la app Flutter y herramientas de desarrollo.
    """
    _origins_env = os.getenv("ALLOWED_ORIGINS", "")
    if _origins_env.strip():
        allowed_origins = [o.strip() for o in _origins_env.split(",") if o.strip()]
    else:
        allowed_origins = [
            "http://localhost:8000",
            "http://127.0.0.1:8000",
        ]

    app.add_middleware(
        CORSMiddleware,
        allow_origins=allowed_origins,   # Orígenes concretos (via ALLOWED_ORIGINS)
        allow_credentials=False,        # No combinar con allow_origins=["*"]
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["*"],
    )

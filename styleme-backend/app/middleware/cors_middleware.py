# StyleMe - Configuración de CORS
from fastapi.middleware.cors import CORSMiddleware


def configurar_cors(app):
    """
    Configura el middleware CORS para la aplicación FastAPI.
    Permite solicitudes desde la app Flutter y herramientas de desarrollo.
    """
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],            # Permite cualquier origen (dev)
        allow_credentials=False,        # No combinar con allow_origins=["*"]
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["*"],
    )

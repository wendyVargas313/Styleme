# StyleMe - Entry Point FastAPI
# Universidad Manuela Beltrán — Trabajo de Grado Ingeniería de Software
import logging
import os
import traceback
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from app.config.database import conectar_db, desconectar_db
from app.config.settings import settings
from app.ml.ml_agent import ml_agent
from app.middleware.cors_middleware import configurar_cors
from app.views.auth_router import router as auth_router
from app.views.guardarropa_router import router as guardarropa_router
from app.views.recomendacion_router import router as recomendacion_router
from app.views.historial_router import router as historial_router
from app.views.invitado_router import router as invitado_router

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
logger = logging.getLogger("styleme")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Gestión del ciclo de vida de la aplicación.
    Al INICIAR: conecta BD + carga modelos ML
    Al DETENER: desconecta BD
    """
    # ─── INICIO ───────────────────────────────────────────
    logger.info("🚀 Iniciando StyleMe Backend...")
    logger.info("   Universidad Manuela Beltrán — TG Ingeniería de Software")

    # Crear directorio de uploads si no existe
    uploads_path = Path(settings.UPLOADS_PATH)
    uploads_path.mkdir(parents=True, exist_ok=True)
    logger.info(f"📁 Directorio de uploads: {uploads_path}")

    # Conectar a MongoDB
    await conectar_db()

    # Cargar los 3 modelos ML (UNA SOLA VEZ)
    await ml_agent.initialize()

    logger.info("✅ StyleMe listo para recibir requests")
    logger.info(f"   API: http://localhost:8000/api/{settings.API_VERSION}")
    logger.info(f"   Docs: http://localhost:8000/docs")

    yield  # La aplicación está corriendo

    # ─── DETENER ──────────────────────────────────────────
    logger.info("🛑 Deteniendo StyleMe Backend...")
    await desconectar_db()
    logger.info("✅ StyleMe detenido correctamente")


# Crear aplicación FastAPI
app = FastAPI(
    title="StyleMe API",
    description=(
        "API de recomendación inteligente de outfits con Machine Learning. "
        "Desarrollado como Trabajo de Grado en la Universidad Manuela Beltrán, "
        "Bogotá, Colombia."
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# Handler global para capturar TODOS los errores 500 con traceback
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    tb = traceback.format_exc()
    logger.error(f"\n{'='*60}\n💥 ERROR NO MANEJADO en {request.method} {request.url}\n{type(exc).__name__}: {exc}\nTraceback:\n{tb}{'='*60}")
    return JSONResponse(
        status_code=500,
        content={"detail": f"{type(exc).__name__}: {exc}"}
    )

# Configurar CORS
configurar_cors(app)

# Servir archivos de imágenes estáticamente
uploads_path = Path(settings.UPLOADS_PATH)
uploads_path.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=str(uploads_path)), name="uploads")

# ─── REGISTRAR ROUTERS ───────────────────────────────────
PREFIX = f"/api/{settings.API_VERSION}"

app.include_router(auth_router, prefix=PREFIX)
app.include_router(guardarropa_router, prefix=PREFIX)
app.include_router(recomendacion_router, prefix=PREFIX)
app.include_router(historial_router, prefix=PREFIX)
app.include_router(invitado_router, prefix=PREFIX)


# ─── ENDPOINT DE SALUD ───────────────────────────────────
@app.get(f"/api/{settings.API_VERSION}/health", tags=["Sistema"])
async def health_check():
    """
    Health check del sistema.
    Verifica estado de los modelos ML y la base de datos.
    """
    from app.config.database import database

    # Estado de la base de datos
    db_status = "connected"
    try:
        await database.client.admin.command("ping")
    except Exception:
        db_status = "disconnected"

    return {
        "status": "ok",
        "version": "1.0.0",
        "agente_ml": ml_agent.get_status(),
        "database": db_status
    }


@app.get("/", tags=["Sistema"])
async def raiz():
    """Endpoint raíz con información de la API."""
    return {
        "app": "StyleMe API",
        "version": "1.0.0",
        "descripcion": "Recomendación inteligente de outfits con ML",
        "universidad": "Universidad Manuela Beltrán",
        "docs": "/docs",
        "health": f"/api/{settings.API_VERSION}/health"
    }


# ─── PUNTO DE ENTRADA ────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )

# StyleMe - Configuración de variables de entorno
import os
from dotenv import load_dotenv

# Cargar variables de entorno desde .env
load_dotenv()


class Settings:
    """Configuración central de la aplicación StyleMe."""

    # MongoDB
    MONGODB_URL: str = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
    MONGODB_DB_NAME: str = os.getenv("MONGODB_DB_NAME", "styleme_db")

    # JWT
    JWT_SECRET_KEY: str = os.getenv("JWT_SECRET_KEY", "styleme_super_secret_key_2025")
    JWT_ALGORITHM: str = os.getenv("JWT_ALGORITHM", "HS256")
    JWT_EXPIRE_DAYS: int = int(os.getenv("JWT_EXPIRE_DAYS", "7"))

    # Rutas de modelos ML e imágenes
    ML_MODELS_PATH: str = os.getenv("ML_MODELS_PATH", "./models")
    UPLOADS_PATH: str = os.getenv("UPLOADS_PATH", "./uploads")

    # Configuración de imágenes
    MAX_IMAGE_SIZE_MB: int = int(os.getenv("MAX_IMAGE_SIZE_MB", "5"))
    MAX_IMAGE_SIZE_BYTES: int = MAX_IMAGE_SIZE_MB * 1024 * 1024

    # Rate limiting
    MAX_REQUESTS_PER_MINUTE: int = int(os.getenv("MAX_REQUESTS_PER_MINUTE", "10"))

    # Agente IA
    GROQ_API_KEY: str = os.getenv("GROQ_API_KEY", "")
    GROQ_MODEL: str = os.getenv("GROQ_MODEL", "openai/gpt-oss-120b")
    # Se usa si GROQ_MODEL responde 404/model_decommissioned (modelo retirado de Groq).
    GROQ_MODEL_FALLBACK: str = os.getenv("GROQ_MODEL_FALLBACK", "qwen/qwen3.8-27b")
    # Solo aplica a modelos openai/gpt-oss-*; admite low/medium/high (no "none").
    GROQ_REASONING_EFFORT: str = os.getenv("GROQ_REASONING_EFFORT", "low")
    OPENWEATHER_API_KEY: str = os.getenv("OPENWEATHER_API_KEY", "")

    # API
    API_VERSION: str = os.getenv("API_VERSION", "v1")
    APP_NAME: str = "StyleMe API"
    APP_VERSION: str = "1.0.0"

    # Tipos de imagen permitidos
    ALLOWED_IMAGE_TYPES: list = ["image/jpeg", "image/jpg", "image/png"]
    ALLOWED_EXTENSIONS: list = [".jpg", ".jpeg", ".png"]


# Instancia global de configuración
settings = Settings()

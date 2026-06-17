# StyleMe - Conexión a MongoDB con Motor (async)
import logging
from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from app.config.settings import settings

logger = logging.getLogger(__name__)


class Database:
    """Gestión de la conexión a MongoDB."""

    client: AsyncIOMotorClient = None
    db: AsyncIOMotorDatabase = None


# Instancia global de la base de datos
database = Database()


async def conectar_db():
    """Establece la conexión con MongoDB al iniciar el servidor."""
    try:
        database.client = AsyncIOMotorClient(settings.MONGODB_URL)
        database.db = database.client[settings.MONGODB_DB_NAME]

        # Verificar la conexión haciendo un ping
        await database.client.admin.command("ping")

        # Crear índices necesarios
        await crear_indices()

        logger.info(f"✅ Conectado a MongoDB: {settings.MONGODB_DB_NAME}")
    except Exception as e:
        logger.warning(f"⚠️  MongoDB no disponible al iniciar: {e}")
        logger.warning("   El servidor arrancará pero las rutas con BD fallarán hasta que MongoDB esté activo.")


async def desconectar_db():
    """Cierra la conexión con MongoDB al detener el servidor."""
    if database.client:
        database.client.close()
        logger.info("✅ Desconectado de MongoDB")


async def crear_indices():
    """Crea los índices necesarios en las colecciones MongoDB."""
    # Índice único en email de usuarios
    await database.db.usuarios.create_index("email", unique=True, sparse=True)

    # Índice en usuario_id para prendas y outfits (búsqueda rápida)
    await database.db.prendas.create_index("usuario_id")
    await database.db.outfits.create_index("usuario_id")

    # Índice en device_id para invitados
    await database.db.invitados.create_index("device_id")
    await database.db.invitados.create_index("expira_en")

    logger.info("✅ Índices MongoDB creados")


def get_db() -> AsyncIOMotorDatabase:
    """Retorna la instancia de la base de datos para uso en controladores."""
    return database.db

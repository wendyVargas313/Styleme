# CLAUDE.md

Este archivo proporciona orientación a Claude Code (claude.ai/code) al trabajar con código en este repositorio.

## Descripción General del Proyecto

**StyleMe** es un sistema inteligente de recomendación de outfits para una aplicación móvil (Flutter), desarrollado como proyecto de tesis en la Universidad Manuela Beltrán. El sistema utiliza tres modelos de ML preentrenados (detección YOLO, clasificación de color KMeans y motor de recomendación basado en coocurrencia) para ayudar a los usuarios a crear outfits desde su guardarropa digitalizado.

**Stack tecnológico:**
- Backend: FastAPI + MongoDB + 3 modelos de ML (preentrenados, en la raíz del proyecto)
- Frontend: Flutter con gestión de estado Provider
- Autenticación: JWT (vencimiento a 7 días) + cifrado de contraseñas con bcrypt
- Pipeline ML: YOLO → recorte → KMeans → almacenamiento MongoDB → recomendación

---

## Comandos Esenciales

### Configuración e Instalación del Backend

```bash
# Instalar dependencias (Python 3.11+)
cd styleme-backend
pip install -r requirements.txt

# Iniciar el servidor (modo auto-recarga)
python main.py
# O: uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Verificación de salud
curl http://localhost:8000/api/v1/health

# Documentación de API
# Navegador: http://localhost:8000/docs
```

**Requisitos:** MongoDB ejecutándose en `localhost:27017` (o configurado en `.env`)

### Configuración e Instalación del Frontend

```bash
cd styleme-flutter
flutter pub get

# Ejecutar en dispositivo/emulador conectado
flutter run

# Especificar dispositivo
flutter devices
flutter run -d <device_id>
```

**Configuración:** Actualizar `lib/config/api_config.dart` con la URL del backend:
- Emulador Android: `http://10.0.2.2:8000`
- Simulador iOS/web: `http://localhost:8000`
- Dispositivo físico: `http://192.168.1.X:8000`

---

## Arquitectura

### Backend (FastAPI)

**Estructura basada en MVC** en `styleme-backend/app/`:

| Capa | Propósito | Archivos |
|-----|----------|---------|
| **Views (Routers)** | Endpoints de FastAPI; maneja HTTP | `views/*_router.py` |
| **Controllers** | Lógica de negocio; llama servicios/ML | `controllers/*_controller.py` |
| **Models** | Esquemas de documentos MongoDB | `models/*_model.py` |
| **Schemas** | Validación Pydantic (solicitud/respuesta) | `schemas/*_schema.py` |
| **ML Agent** | Singleton que orquesta 3 modelos | `ml/ml_agent.py` |
| **Config** | Base de datos, configuración, entorno | `config/*.py` |
| **Middleware** | CORS, autenticación JWT | `middleware/*.py` |

**Punto de entrada clave:** `main.py` utiliza el gestor de contexto `lifespan` de FastAPI para:
1. Cargar 3 modelos de ML una sola vez al iniciar (patrón singleton — nunca recargar por solicitud)
2. Conectar a MongoDB
3. Registrar 6 routers (auth, guardarropa, recomendación, historial, invitado, virtual_tryon)

### Pipeline de ML

Tres modelos trabajan en secuencia (`ml/ml_agent.py` → `ml_agent.procesar_imagen()`):

1. **Detección YOLO** (`styleme_detector.pt`, 20 clases de prendas)
   - Detecta tipo de prenda + caja delimitadora + confianza
   - Archivo: `ml/detector.py`

2. **Clasificación de Color KMeans** (`modelo_color.pkl`, 13 clases de color)
   - Clasifica el color dominante de la prenda detectada
   - Funciona en la región recortada de la caja delimitadora
   - Archivo: `ml/color_classifier.py`

3. **Recomendador por Coocurrencia** (`modelo_recomendador_outfits.pkl`)
   - Califica compatibilidad de outfits: `puntuación = 0.5×coocurrencia + 0.3×color + 0.2×temporada`
   - Archivo: `ml/recommender.py`

Todos los archivos de modelos están en la **raíz del proyecto** (un nivel arriba de `styleme-backend/`), configurado mediante `ML_MODELS_PATH` en settings.

### Frontend (Flutter)

**Gestión de estado basada en Provider:**
- `lib/app/` — Configuración de la app, rutas, tema
- `lib/controllers/` — Clases Provider (gestores de estado)
- `lib/views/` — Pantallas (autenticación, guardarropa, recomendaciones, historial)
- `lib/services/` — Cliente HTTP (DIO), selección de imágenes, almacenamiento local
- `lib/widgets/` — Componentes de UI reutilizables
- `lib/models/` — Modelos de datos Dart (coinciden con esquemas del backend)

**Servicios clave:**
- `services/http_service.dart` — Cliente DIO con inyección de token JWT
- `services/image_service.dart` — Selector de imágenes + integración de cámara
- `services/storage_service.dart` — SharedPreferences para token JWT + datos de usuario

---

## Modelo de Datos (Colecciones de MongoDB)

| Colección | Propósito | Campos Clave |
|----------|----------|-------------|
| `users` | Cuentas de usuario | `_id`, `email`, `nombre`, `password_hash`, `genero`, `created_at` |
| `prendas` | Artículos del guardarropa (ropa) | `_id`, `user_id`, `tipo`, `color`, `temporada`, `imagen_url`, `confidence` |
| `outfits` | Outfits generados | `_id`, `user_id`, `prenda_base_id`, `complementos[]`, `puntuacion`, `created_at` |
| `historial` | Historial de outfits + retroalimentación | `_id`, `user_id`, `outfit_id`, `usado`, `feedback`, `timestamp` |

**Flujo:** El usuario sube imagen → YOLO detecta tipo de prenda → KMeans clasifica color → se almacena en `prendas` → el recomendador crea outfits desde `prendas` del usuario

---

## Estructura de API

Todos los endpoints bajo `/api/v1/`:

| Router | Propósito | Endpoints Clave |
|--------|----------|-----------------|
| `auth_router` | JWT + registro | `POST /auth/registro`, `/login`, `GET /auth/perfil` |
| `guardarropa_router` | CRUD de guardarropa + procesamiento de ML | `POST /guardarropa/agregar` (con YOLO+KMeans), `GET /listar`, `/stats`, `DELETE /{id}` |
| `recomendacion_router` | Generación de outfits | `POST /recomendar/outfit`, `GET /recomendar/diario` |
| `historial_router` | Historial + retroalimentación | `GET /historial`, `POST /historial/feedback` |
| `invitado_router` | Modo invitado | `POST /invitado/probar` |
| `tryon_router` | Prueba virtual | `POST /tryon/` |

**Autenticación:** Agregar encabezado `Authorization: Bearer <token>`. Los tokens vencen en 7 días. Renovar mediante re-login.

---

## Patrones Importantes y Restricciones

### Carga de Modelos de ML
- **Crítico:** Los modelos se cargan **una sola vez al iniciar** mediante el gestor de contexto `lifespan` en `main.py`
- El `ml_agent` es un **Singleton** — nunca recargar modelos por solicitud (impacto severo en rendimiento)
- Verificar estado del modelo mediante `GET /api/v1/health` — incluye `yolo_loaded`, `color_loaded`, `rec_loaded`
- Si un modelo falla al cargar, todo el servidor falla al iniciar (intencional — detectar temprano)

### Procesamiento de Imágenes
- Solo JPG/PNG permitidos; máximo 5MB (`MAX_IMAGE_SIZE_BYTES` en settings)
- Umbral de confianza YOLO: 0.25 (codificado en `ml_agent.procesar_imagen()`)
- Las imágenes se recortan a la caja delimitadora antes de la clasificación de color (mejora precisión)
- Las imágenes subidas se almacenan en `./uploads/` y se sirven estáticamente en `/uploads/<nombre_archivo>`

### Base de Datos y Transacciones
- MongoDB es asincrónico (librería motor) — todas las llamadas a BD deben ser `await`
- Sin soporte explícito de transacciones; confiar en operaciones atómicas de MongoDB
- Conexión a BD establecida al iniciar, cerrada al detener

### Seguridad
- Secreto JWT en `.env` (predeterminado a valor de demostración; cambiar en producción)
- Contraseñas cifradas con bcrypt (12 rondas)
- CORS configurado para permitir solicitudes de la app Flutter
- Validación de imágenes: tamaño, tipo MIME, extensión de archivo
- Aislamiento de usuario: cada usuario solo puede ver sus propias prendas/outfits

---

## Configuración del Entorno

Crear `.env` en `styleme-backend/` (o usar `.env.example`):

```env
# MongoDB
MONGODB_URL=mongodb://localhost:27017
MONGODB_DB_NAME=styleme_db

# JWT
JWT_SECRET_KEY=tu_clave_secreta_aqui
JWT_ALGORITHM=HS256
JWT_EXPIRE_DAYS=7

# Ruta de modelos ML (relativa a styleme-backend/)
ML_MODELS_PATH=../  # Apunta a la raíz del proyecto donde están los archivos .pt y .pkl

# Carga de imágenes
UPLOADS_PATH=./uploads
MAX_IMAGE_SIZE_MB=5

# API
API_VERSION=v1
```

---

## Tareas Comunes de Desarrollo

### Agregar un Nuevo Tipo de Prenda
1. El modelo YOLO ya está entrenado con 20 clases — verificar nombres de clases en endpoint `health`
2. Nuevos tipos requieren re-entrenar YOLO (fuera de este repositorio)
3. El clasificador de color se adapta automáticamente (paleta de 13 colores)

### Agregar un Nuevo Algoritmo de Recomendación
1. Modificar `recommender.py` — la función de puntuación está en el método `recomendar()`
2. Actual: `puntuación = 0.5×coocurrencia + 0.3×color + 0.2×temporada`
3. Re-entrenar requiere retroalimentación histórica de outfits (ya recolectada en colección `historial`)

### Pruebas con curl
```bash
# Registrar
curl -X POST http://localhost:8000/api/v1/auth/registro \
  -H "Content-Type: application/json" \
  -d '{"nombre":"Prueba","email":"prueba@ejemplo.com","password":"Test1234!","genero":"femenino"}'

# Iniciar sesión (obtener token)
TOKEN=$(curl -s -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"prueba@ejemplo.com","password":"Test1234!"}' | jq -r '.access_token')

# Agregar prenda (con archivo de imagen)
curl -X POST http://localhost:8000/api/v1/guardarropa/agregar \
  -H "Authorization: Bearer $TOKEN" \
  -F "imagen=@ruta/a/imagen.jpg" \
  -F "temporada=invierno"
```

---

## Problemas Comunes y Soluciones

1. **Los modelos no se cargan** → Verificar que `ML_MODELS_PATH` en `.env` apunte a la raíz del proyecto (no a `styleme-backend/`)
2. **MongoDB no se ejecuta** → El servidor fallará al iniciar con error de conexión
3. **Falla la carga de imagen** → Validar tamaño de archivo (<5MB), tipo MIME (JPG/PNG) y permisos de directorio
4. **Flutter no puede alcanzar el backend** → Verificar que la URL en `api_config.dart` coincida con tu configuración de red
5. **Token JWT expirado** → Los usuarios deben re-iniciar sesión (actualmente no hay endpoint de renovación)
6. **Confianza de YOLO muy alta** → Si las prendas no se detectan, el umbral de confianza puede ser demasiado estricto (actualmente 0.25)

---

## Documentación de Referencia

- **Documentación de API:** `http://localhost:8000/docs` (Interfaz Swagger interactiva)
- **README.md:** Descripción general e instrucciones de instalación
- **Modelos de ML:** Entrenados en dataset Clothing-Detection-6 (Roboflow) — ver métricas en README
- **Compilación de Flutter:** Ver `styleme-flutter/README.md`

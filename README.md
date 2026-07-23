# StyleMe 👗✨

**Aplicación móvil de recomendación inteligente de outfits basada en Machine Learning**

> Trabajo de Grado — Ingeniería de Software
> Universidad Manuela Beltrán, Bogotá, Colombia

---

## 📱 Descripción

StyleMe permite digitalizar tu guardarropa y recibir recomendaciones de outfits personalizadas usando modelos de Machine Learning propios entrenados con el dataset **Clothing-Detection-6** de Roboflow.

### 🤖 Modelos ML (pre-entrenados, incluidos en el repo)

| Modelo | Tipo | Función | Métricas |
|--------|------|---------|---------|
| `styleme_detector.pt` | YOLOv8n | Detecta 20 tipos de prendas | mAP50: 65.9% |
| `modelo_color.pkl` | KMeans sklearn | Clasifica 13 colores | Accuracy: 98.1% |
| `modelo_recomendador_outfits.pkl` | Co-ocurrencia real | Recomienda outfits compatibles | Sep: +0.499 |

> Los tres modelos están **versionados en el repositorio** (5.4 MB en total). No hay que descargarlos ni entrenarlos: al clonar, ya están listos.

---

## 🚀 Instalación con Docker (recomendado)

Es la forma más rápida de levantar el backend. No requiere instalar Python, ni crear entornos virtuales, ni instalar las dependencias de ML.

### Prerrequisitos

- **Docker Desktop** (con backend WSL2 activado en Windows)
- **MongoDB** corriendo en `localhost:27017`
- **Git**

### Pasos

```bash
# 1. Clonar el repositorio
git clone https://github.com/wendyVargas313/Styleme.git
cd Styleme

# 2. Crear el archivo .env del backend
cp styleme-backend/.env.example styleme-backend/.env
# Editar styleme-backend/.env y definir JWT_SECRET_KEY con un valor propio

# 3. Construir la imagen (primera vez: 8-15 min)
docker compose build

# 4. Levantar el backend
docker compose up -d

# 5. Verificar
curl http://localhost:8000/api/v1/health
```

Respuesta esperada:

```json
{
  "status": "ok",
  "version": "1.0.0",
  "agente_ml": {
    "yolo_loaded": true,
    "color_loaded": true,
    "rec_loaded": true,
    "yolo_classes": 20,
    "color_classes": 13,
    "rec_pairs": 79
  },
  "database": "connected"
}
```

### Comandos útiles

```bash
docker compose up -d          # Levantar en segundo plano
docker compose stop           # Detener (conserva el contenedor)
docker compose logs -f        # Ver logs en vivo
docker compose ps             # Estado del contenedor
docker compose build          # Reconstruir tras cambiar código del backend
```

> ⚠️ **El código del backend está horneado dentro de la imagen.** Si modificas archivos `.py`, el contenedor no los ve hasta que ejecutes `docker compose build` de nuevo.

### ⚠️ MongoDB debe aceptar conexiones desde el contenedor

Este es el problema más común al levantar el proyecto por primera vez.

MongoDB por defecto escucha **solo en `127.0.0.1`** (loopback). Compass funciona, pero el contenedor **no puede conectarse** y el health devuelve `"database": "disconnected"`.

**Solución** — editar `mongod.cfg` (normalmente en `C:\Program Files\MongoDB\Server\<version>\bin\mongod.cfg`) desde **PowerShell como Administrador**:

```powershell
# Backup primero
Copy-Item "C:\Program Files\MongoDB\Server\8.2\bin\mongod.cfg" "C:\Program Files\MongoDB\Server\8.2\bin\mongod.cfg.bak" -Force

# Cambiar bindIp (el ^\s* mantiene la indentación YAML correcta)
(Get-Content "C:\Program Files\MongoDB\Server\8.2\bin\mongod.cfg") -replace '^\s*bindIp:.*', '  bindIp: 0.0.0.0' | Set-Content "C:\Program Files\MongoDB\Server\8.2\bin\mongod.cfg"

# Reiniciar y verificar
Restart-Service MongoDB
netstat -ano | findstr :27017
```

Resultado correcto: `0.0.0.0:27017 LISTENING`.

> 🔴 **Cuidado con la indentación.** MongoDB es estricto con el YAML: `port` y `bindIp` deben ir con **exactamente 2 espacios**. Si queda mal, el servicio no arranca.
>
> ```yaml
> net:
>   port: 27017
>   bindIp: 0.0.0.0
> ```
>
> 📌 Una actualización de MongoDB puede revertir el `bindIp` a `127.0.0.1`. Si el backend deja de conectar de repente, revisar esto primero.

---

## 🐍 Instalación manual del backend (alternativa sin Docker)

### Prerrequisitos

- Python 3.11
- MongoDB en `localhost:27017`

```bash
cd styleme-backend
python -m venv venv
source venv/bin/activate     # Windows: venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env
# Ajustar ML_MODELS_PATH=../ (los modelos están en la raíz del repo)

uvicorn main:app --host 0.0.0.0 --port 8000
```

> ⚠️ **Windows:** si `torch` falla al cargar (`DLL load failed`), puede deberse a Smart App Control bloqueando `torch_cpu.dll`. En ese caso, usar Docker o WSL2.

---

## 📱 Frontend (Flutter)

El frontend **no está dockerizado**: se compila de forma nativa.

### 1. Instalar dependencias

```bash
cd styleme-flutter
flutter pub get
```

### 2. Conectar el dispositivo físico

La app apunta a `http://localhost:8000`. Para que el teléfono alcance el backend del PC se usa `adb reverse`:

```bash
adb devices                          # debe mostrar el device como "device"
adb reverse tcp:8000 tcp:8000
adb reverse --list                   # debe listar tcp:8000
```

> 🔴 **El `adb reverse` se pierde cada vez que se desconecta el cable USB.** Si la app dice *"No se puede conectar al servidor"* y el backend está sano, esta es la causa el 90% de las veces: recrearlo.
>
> Si el device aparece como `unauthorized`, hay que aceptar el diálogo **"¿Permitir depuración USB?"** en la pantalla del teléfono.

### 3. Correr la app

```bash
flutter devices
flutter run -d <device_id>
```

Primer build: 3–8 minutos (Gradle completo). Después, hot reload con `r`, salir con `q`.

---

## 👗 Virtual Try-On (CatVTON)

El probador virtual corre **fuera del proyecto**, en un notebook de Google Colab con GPU T4, expuesto mediante ngrok. La URL se configura en el `.env` como `CATVTON_TRYON_URL`.

Para usarlo hay que tener el notebook de Colab activo.

> ⚠️ **Redes institucionales:** algunos firewalls (p. ej. FortiGuard) bloquean `ngrok-free.dev` por categoría *"Proxy Avoidance"*, y el Try-On falla de inmediato. Solución: usar datos móviles o hotspot.

---

## 🗂️ Estructura del Proyecto

```
Styleme/
├── docker-compose.yml               # Orquestación del backend
├── .dockerignore
├── styleme_detector.pt              # Modelo YOLO (20 clases)
├── modelo_color.pkl                 # Modelo KMeans (13 colores)
├── modelo_recomendador_outfits.pkl  # Modelo recomendador
├── dataset_prendas_reales.json      # Dataset de entrenamiento
├── metricas_capitulo_iv.json        # Métricas del trabajo de grado
│
├── styleme-backend/                 # FastAPI Backend
│   ├── Dockerfile
│   ├── main.py                      # Entry point
│   ├── requirements.txt
│   ├── .env.example                 # Plantilla de variables (.env NO se versiona)
│   └── app/
│       ├── config/                  # Configuración DB y settings
│       ├── models/                  # Modelos MongoDB
│       ├── schemas/                 # Schemas Pydantic
│       ├── controllers/             # Lógica de negocio (MVC-C)
│       ├── views/                   # Routers FastAPI (MVC-V)
│       ├── ml/                      # Agente ML (3 modelos)
│       └── middleware/              # JWT + CORS
│
└── styleme-flutter/                 # Flutter Frontend
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── app/                     # App config + rutas
        ├── config/                  # Tema, constantes, API config
        ├── models/                  # Modelos Dart
        ├── controllers/             # Providers (MVC-C)
        ├── views/                   # Pantallas (MVC-V)
        ├── widgets/                 # Widgets reutilizables
        └── services/                # HTTP, storage, imágenes
```

---

## 🔌 API Endpoints

| Método | Endpoint | Descripción | Auth |
|--------|----------|-------------|------|
| `POST` | `/api/v1/auth/registro` | Registrar usuario | ❌ |
| `POST` | `/api/v1/auth/login` | Iniciar sesión (rate limit: 10/min por IP) | ❌ |
| `GET` | `/api/v1/auth/perfil` | Ver perfil | ✅ |
| `POST` | `/api/v1/guardarropa/agregar` | Agregar prenda (con ML) | ✅ |
| `GET` | `/api/v1/guardarropa/listar` | Listar prendas | ✅ |
| `GET` | `/api/v1/guardarropa/stats` | Estadísticas del armario | ✅ |
| `DELETE` | `/api/v1/guardarropa/{id}` | Eliminar prenda | ✅ |
| `POST` | `/api/v1/recomendar/outfit` | Generar outfit | ✅ |
| `GET` | `/api/v1/recomendar/diario` | Outfits del día | ✅ |
| `GET` | `/api/v1/historial` | Ver historial | ✅ |
| `POST` | `/api/v1/historial/feedback` | Dar feedback | ✅ |
| `DELETE` | `/api/v1/historial/{id}` | Eliminar outfit | ✅ |
| `POST` | `/api/v1/invitado/probar` | Modo invitado | ❌ |
| `GET` | `/api/v1/health` | Health check | ❌ |

> 📌 *Pendiente de documentar: los endpoints de foto de perfil / avatar (`foto_avatar_url`) añadidos posteriormente.*

Documentación interactiva (Swagger): `http://localhost:8000/docs`

---

## 🎨 Diseño

- **Paleta**: Naranja vibrante `#FF6B00` sobre fondo negro `#0D0D0D`
- **Tipografía**: Poppins (Google Fonts)
- **Estilo**: Dark mode, cards redondeadas, gradientes naranja
- **Animaciones**: 300ms, `easeInOut`

---

## 🔒 Seguridad

- JWT tokens con expiración de 7 días
- Contraseñas hasheadas con bcrypt (12 rounds)
- Validación de imágenes (solo JPG/PNG, máx 5MB)
- Validación de ObjectId con manejo global de errores (HTTP 400 en vez de 500)
- CORS restringido mediante la variable `ALLOWED_ORIGINS`
- Rate limiting en login con `slowapi` (10 peticiones/min por IP)
- Cada usuario solo accede a sus propias prendas y outfits
- Variables sensibles en `.env` (nunca hardcodeadas, nunca versionadas)

> 🔴 **Cada instalación debe definir su propio `JWT_SECRET_KEY`.** El valor del `.env.example` es solo un placeholder: si se usa tal cual, todas las instalaciones comparten la misma clave de firma.

---

## 📊 Flujo ML

```
Imagen del usuario
      ↓
  YOLOv8n (styleme_detector.pt)
  → Detecta tipo de prenda (20 clases)
  → Retorna bounding box + confianza
      ↓
  Recorte de la prenda (bbox)
      ↓
  KMeans (modelo_color.pkl)
  → Clasifica color dominante (13 colores)
      ↓
  Guardado en MongoDB con tipo + color + temporada
      ↓
  Recomendador (modelo_recomendador_outfits.pkl)
  → score = 0.5×coocurrencia + 0.3×color + 0.2×temporada
  → Retorna top-K prendas más compatibles
```

Adicionalmente, `rembg` (u2net) está disponible para eliminación de fondo. En Docker, el modelo `u2net.onnx` se cachea en un volumen para no descargarlo en cada arranque.

---

## 🧪 Probar la API con curl

```bash
# Registro
curl -X POST http://localhost:8000/api/v1/auth/registro \
  -H "Content-Type: application/json" \
  -d '{"nombre":"Laura","email":"laura@test.com","password":"Test1234!","genero":"femenino"}'

# Login
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"laura@test.com","password":"Test1234!"}'

# Health check
curl http://localhost:8000/api/v1/health
```

---

## 📦 Dependencias principales

### Backend

- `fastapi` — Framework web
- `ultralytics` — YOLOv8
- `scikit-learn` + `joblib` — Modelos ML
- `motor` / `pymongo` — MongoDB async
- `python-jose` — JWT
- `passlib[bcrypt]` — Hash de contraseñas
- `slowapi` — Rate limiting
- `rembg` + `onnxruntime` — Eliminación de fondo

> 📌 **Versiones pineadas en Docker.** El `Dockerfile` fija `scikit-learn==1.9.0`, `ultralytics==8.4.81` y `torch==2.12.1+cpu`. Esto es intencional: `modelo_color.pkl` fue serializado con scikit-learn 1.9.0 y una versión distinta genera advertencias de incompatibilidad al cargarlo.
>
> El `torch` se instala desde el índice **CPU-only** de PyTorch. Instalarlo desde PyPI traería las librerías de CUDA (~2.5 GB extra) que el proyecto no usa.

### Frontend

- `provider` — State management
- `dio` — HTTP client
- `image_picker` — Cámara y galería
- `cached_network_image` — Caché de imágenes
- `google_fonts` — Tipografía Poppins

---

## 🐛 Problemas conocidos

| Síntoma | Causa probable | Solución |
|---------|----------------|----------|
| App: *"No se puede conectar al servidor"* | `adb reverse` perdido al desconectar el cable | `adb reverse tcp:8000 tcp:8000` |
| `"database": "disconnected"` | `bindIp: 127.0.0.1` en `mongod.cfg` | Ver sección de MongoDB |
| MongoDB no arranca tras editar config | Indentación YAML incorrecta | `port` y `bindIp` con 2 espacios |
| Try-On falla al instante | Firewall bloqueando ngrok | Usar datos móviles |
| Error al registrar usuario (DuplicateKey) | Índice antiguo `correo_1` en MongoDB | Eliminar el índice obsoleto |
| Device `unauthorized` en adb | Falta autorizar depuración USB | Aceptar el diálogo en el teléfono |

---

*StyleMe v1.0.0 — Universidad Manuela Beltrán © 2025*

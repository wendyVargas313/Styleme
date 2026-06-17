# StyleMe 👗✨

**Aplicación móvil de recomendación inteligente de outfits basada en Machine Learning**

> Trabajo de Grado — Ingeniería de Software  
> Universidad Manuela Beltrán, Bogotá, Colombia

---

## 📱 Descripción

StyleMe permite digitalizar tu guardarropa y recibir recomendaciones de outfits personalizadas usando modelos de Machine Learning propios entrenados con el dataset **Clothing-Detection-6** de Roboflow.

### 🤖 Modelos ML (pre-entrenados, listos para usar)

| Modelo | Tipo | Función | Métricas |
|--------|------|---------|---------|
| `styleme_detector.pt` | YOLOv8n | Detecta 20 tipos de prendas | mAP50: 65.9% |
| `modelo_color.pkl` | KMeans sklearn | Clasifica 13 colores | Accuracy: 98.1% |
| `modelo_recomendador_outfits.pkl` | Co-ocurrencia real | Recomienda outfits compatibles | Sep: +0.499 |

---

## 🚀 Instalación rápida

### Prerrequisitos

- Python 3.11+
- MongoDB instalado y corriendo en `localhost:27017`
- Flutter 3.x con Dart SDK
- Git

---

## 🐍 Backend (FastAPI)

### 1. Instalar dependencias

```bash
cd styleme-backend
pip install -r requirements.txt
```

### 2. Configurar variables de entorno

```bash
# El archivo .env ya está configurado con los valores por defecto
# Los modelos ML están en la carpeta raíz del proyecto (un nivel arriba)
# ML_MODELS_PATH=../ (ya configurado)
```

### 3. Iniciar MongoDB

```bash
# Windows
mongod

# macOS/Linux
sudo systemctl start mongod
```

### 4. Iniciar el servidor

```bash
cd styleme-backend
python main.py
# o
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 5. Verificar que funciona

```
GET http://localhost:8000/api/v1/health
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

### 📖 Documentación interactiva API

Disponible en: `http://localhost:8000/docs`

---

## 📱 Frontend (Flutter)

### 1. Instalar dependencias

```bash
cd styleme-flutter
flutter pub get
```

### 2. Configurar URL del backend

Editar `lib/config/api_config.dart`:

```dart
// Para emulador Android:
static const String baseUrl = 'http://10.0.2.2:8000';

// Para simulador iOS o web:
static const String baseUrl = 'http://localhost:8000';

// Para dispositivo físico (reemplazar con tu IP):
static const String baseUrl = 'http://192.168.1.X:8000';
```

### 3. Correr la app

```bash
# Emulador/simulador
flutter run

# Dispositivo específico
flutter devices
flutter run -d <device_id>
```

---

## 🗂️ Estructura del Proyecto

```
Styleme/
├── styleme_detector.pt              # Modelo YOLO (20 clases)
├── modelo_color.pkl                 # Modelo KMeans (13 colores)
├── modelo_recomendador_outfits.pkl  # Modelo recomendador
├── dataset_prendas_reales.json      # Dataset de entrenamiento
├── metricas_capitulo_iv.json        # Métricas del trabajo de grado
│
├── styleme-backend/                 # FastAPI Backend
│   ├── main.py                      # Entry point
│   ├── requirements.txt
│   ├── .env                         # Variables de entorno
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
| `POST` | `/api/v1/auth/login` | Iniciar sesión | ❌ |
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
- Cada usuario solo accede a sus propias prendas y outfits
- Variables sensibles en `.env` (nunca hardcodeadas)

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
- `motor` — MongoDB async
- `python-jose` — JWT
- `passlib[bcrypt]` — Hash de contraseñas

### Frontend
- `provider` — State management
- `dio` — HTTP client
- `image_picker` — Cámara y galería
- `cached_network_image` — Caché de imágenes
- `google_fonts` — Tipografía Poppins

---

*StyleMe v1.0.0 — Universidad Manuela Beltrán © 2025*

# Guía de instalación de StyleMe desde cero

> ℹ️ **Guía de instalación manual (alternativa).**
> Para la vía recomendada —que no requiere instalar Python, MongoDB ni las
> dependencias de Machine Learning— consulta **`GUIA_INSTALACION_DOCKER.md`**.
> Esta guía se conserva para instalaciones sin Docker o como referencia.

> **Para quién es esta guía:** para montar y correr el proyecto StyleMe en una máquina nueva (Windows) desde el repositorio clonado, dejando el backend funcionando y el módulo de Virtual Try-On operativo.
>
> **Cómo usar esta guía con una IA:** si te apoyas en una IA (Claude, Gemini, ChatGPT, etc.), puedes pegarle este documento completo al inicio de la conversación y decirle algo como: *"Esta es la guía de instalación de mi proyecto. Voy a seguir estos pasos en mi PC con Windows y te iré pegando las salidas y errores; ayúdame a interpretarlos y resolverlos sin romper lo que ya funciona, un paso a la vez."* Así la IA tiene todo el contexto y no te hace adivinar.

---

## 0. Contexto del proyecto (para ti y para la IA)

**StyleMe** es una aplicación móvil de moda inteligente (proyecto de grado, Universidad Manuela Beltrán). Permite digitalizar el guardarropa y recibir recomendaciones de outfits usando modelos de Machine Learning propios, más un módulo de "probador virtual" (Virtual Try-On).

**Stack:**
- **Backend:** FastAPI + Python, conectado a **MongoDB** local.
- **Frontend:** Flutter (Android).
- **Modelos ML propios (3):** detección de prendas (YOLO), clasificación de color (KMeans) y recomendador de outfits. Son archivos pesados.
- **Virtual Try-On:** modelo **CatVTON** que corre en **Google Colab** (con GPU gratuita) y se expone a internet mediante un túnel **ngrok**. El backend lo consume por una URL.

**Idea clave que explica casi todos los problemas de instalación:** al clonar el repositorio obtienes el **código**, pero NO obtienes el **entorno**. Hay tres cosas que NO viajan por Git y que cada persona debe montar localmente:
1. El archivo de configuración `.env` (está excluido por seguridad).
2. El entorno virtual de Python con las dependencias instaladas.
3. Los tres archivos de modelos ML (son demasiado pesados para el repositorio).

Si entiendes esto, los errores de "no encuentra X" dejan de ser un misterio: casi siempre es una de esas tres piezas que falta colocar.

---

## 1. Requisitos previos

Antes de empezar, asegúrate de tener instalado en tu PC:

- **Python** (versión 3.11 o superior). Verifícalo con `python --version`.
- **MongoDB** instalado y corriendo localmente, y opcionalmente **MongoDB Compass** (la interfaz visual) para ver la base de datos.
- **Git** (para clonar el repositorio).
- **Flutter** (solo si vas a correr la app móvil; para probar el backend no es imprescindible al inicio).
- Acceso a la **cuenta comunal de Google** del proyecto (la que tiene el Colab, el Drive con los modelos y la cuenta de ngrok). Pídesela al equipo.

---

## 2. Clonar el proyecto

Clona el repositorio en tu máquina (ajusta la URL a la de tu repo) y entra a la carpeta. La estructura quedará más o menos así:

```
Proyecto-de-grado/
└── Styleme/                 <- raíz del proyecto
    ├── styleme-backend/     <- el backend (FastAPI)
    ├── styleme-flutter/     <- la app (Flutter)
    ├── CLAUDE.md
    ├── README.md
    └── (aquí van los 3 modelos ML, ver paso 4)
```

> **Importante:** distingue bien dos carpetas que se parecen:
> - `Styleme/` = la **raíz** del proyecto.
> - `Styleme/styleme-backend/` = el **backend**, un nivel adentro.
>
> Varios pasos dependen de en cuál de las dos estás parado.

---

## 3. MongoDB: confirmar que está corriendo

El backend se conecta a una base de datos local llamada `styleme_db` en `mongodb://localhost:27017`.

1. Asegúrate de que el **servicio de MongoDB** esté activo en tu PC (corre en segundo plano en el puerto 27017).
2. Abre **MongoDB Compass** y conéctate a `localhost:27017`. Si ves que puedes conectarte y aparece (o puedes crear) la base `styleme_db`, MongoDB está listo.

> Compass es solo el "visor". Lo que el backend necesita es el **servicio** de MongoDB corriendo. Si Compass conecta, el servicio está activo.

---

## 4. Descargar y colocar los 3 modelos ML

Los modelos NO están en el repositorio. Están en el **Google Drive de la cuenta comunal** (revisa la carpeta del proyecto; pueden estar en una carpeta tipo `StyleMe_ML`).

**Los tres archivos que necesitas (nombres exactos):**
- `styleme_detector.pt` (detector YOLO — es el más pesado)
- `modelo_color.pkl` (clasificador de color KMeans)
- `modelo_recomendador_outfits.pkl` (recomendador de outfits)

**Pasos:**
1. En Google Drive, descarga los **tres** archivos a tu PC (clic derecho → Descargar).
2. Muévelos a la **raíz del proyecto**, es decir a `Proyecto-de-grado/Styleme/` (al mismo nivel que la carpeta `styleme-backend`, **NO** dentro de ella).
3. Verifica que los nombres queden **idénticos** a los de arriba. Si Google los renombró o los descargó en un `.zip`, corrígelos/descomprímelos para que coincidan exactamente.

> **Por qué van en la raíz y no en el backend:** el archivo de configuración usa `ML_MODELS_PATH=../`, que le dice al backend que busque los modelos "un nivel arriba" de `styleme-backend/`, o sea en `Styleme/`. Si los pones en otro lado, el backend no los encontrará.
>
> **No confundir** estos 3 archivos con los del Virtual Try-On (como `model.safetensors`, archivos `.pth`, `model_final_162be9.pkl`): esos pertenecen a CatVTON y viven en el Colab, NO se descargan a tu PC.

---

## 5. Crear el entorno virtual e instalar dependencias de Python

Para no ensuciar el Python global de tu sistema, las dependencias se instalan en un **entorno virtual (venv)** aislado, dentro de `styleme-backend`.

En una terminal (PowerShell en Windows), ubícate en la carpeta del backend:

```powershell
cd ruta\a\Proyecto-de-grado\Styleme\styleme-backend
```

Crea el entorno virtual:

```powershell
python -m venv venv
```

> **Nota sobre Windows / PowerShell:** la activación del venv (`venv\Scripts\Activate`) a veces no persiste entre comandos, o PowerShell la bloquea por la política de ejecución de scripts (verás un error que menciona *"execution policy"* o *"running scripts is disabled"*). Dos formas de manejarlo:
> - **Opción A (recomendada y a prueba de fallos):** en lugar de activar, usa directamente el Python del venv apuntando a su ruta. Por ejemplo:
>   ```powershell
>   .\venv\Scripts\python.exe -m pip install -r requirements.txt
>   ```
> - **Opción B:** habilitar scripts en PowerShell con `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` y luego activar con `venv\Scripts\Activate`.

Instala las dependencias (esto **tarda varios minutos**, porque incluye librerías de ML pesadas como `torch`, `ultralytics`/YOLO, `scikit-learn`, `rembg`, etc.). Déjalo terminar sin interrumpir:

```powershell
.\venv\Scripts\python.exe -m pip install -r requirements.txt
```

> **Posibles tropiezos:**
> - Si alguna dependencia falla al instalar (a veces pasa en Windows con paquetes que requieren compilación), copia el error completo y resuélvelo uno por uno; no sigas hasta que la instalación termine limpia.
> - **Aviso conocido de `scikit-learn`:** el modelo de color fue entrenado con `scikit-learn 1.6.1`, pero por defecto se instala una versión más nueva. Al arrancar el backend puede aparecer un `InconsistentVersionWarning`. Carga igual, pero conviene saber que está pendiente alinear esa versión (es una tarea conocida del proyecto). No bloquea la instalación.

---

## 6. Crear el archivo `.env`

El archivo `.env` con la configuración **no viene en el repositorio** (está protegido por `.gitignore`). Debes crearlo tú dentro de `styleme-backend/`.

Crea un archivo llamado exactamente `.env` (con el punto al inicio) en `styleme-backend/` con este contenido:

```env
MONGODB_URL=mongodb://localhost:27017
MONGODB_DB_NAME=styleme_db
JWT_SECRET_KEY=PON_AQUI_UNA_CLAVE_LARGA_Y_ALEATORIA
JWT_ALGORITHM=HS256
JWT_EXPIRE_DAYS=7
ML_MODELS_PATH=../
UPLOADS_PATH=./uploads
MAX_IMAGE_SIZE_MB=5
MAX_REQUESTS_PER_MINUTE=10
API_VERSION=v1
CATVTON_TRYON_URL=PON_AQUI_LA_URL_DE_NGROK_CON_LA_RUTA_/tryon
```

**Dos valores que tienes que completar:**

- **`JWT_SECRET_KEY`**: una clave secreta larga y aleatoria. Puedes generarla con:
  ```powershell
  .\venv\Scripts\python.exe -c "import secrets; print(secrets.token_urlsafe(48))"
  ```
  Copia el resultado y pégalo como valor. Para desarrollo, **no importa** que tu clave sea distinta a la de tus compañeros.

- **`CATVTON_TRYON_URL`**: la URL pública de ngrok del Colab, **con la ruta `/tryon` al final** (la obtienes en el paso 7). Ejemplo del formato:
  ```
  CATVTON_TRYON_URL=https://NOMBRE-DEL-TUNEL.ngrok-free.dev/tryon
  ```

> **Seguridad:** nunca subas el `.env` al repositorio ni pegues la clave JWT real en chats. Confirma que `.gitignore` excluye los `.env` (debe tener una regla como `*.env`). Pide al equipo, por un canal seguro, los valores que deban coincidir (como la URL del Colab); la clave JWT la generas tú.

---

## 7. Encender el Virtual Try-On: Colab + ngrok

El probador virtual (CatVTON) corre en un **notebook de Google Colab** de la cuenta comunal. Para que funcione, ese Colab tiene que estar **encendido y corriendo**, y exponerse con ngrok.

### Antes de empezar
- Abre el Colab con la **cuenta comunal** (la que tiene los modelos en su Drive). Si entras con otra cuenta, fallará al buscar los archivos.
- Ten a mano el **authtoken de ngrok** de la cuenta comunal (lo encuentras en el panel de ngrok de esa cuenta).
- **Recomendación:** usa una ventana **normal** de Chrome (no incógnito) para el Colab, y no la cierres mientras trabajas; así la sesión es más estable.

### Orden de ejecución de las celdas
El notebook tiene celdas numeradas. **Ejecútalas en orden, una a una, esperando que cada una termine antes de seguir.** El orden correcto es:

1. **Celda 1** — Instala dependencias y verifica la GPU. **Al final pide reiniciar la sesión** (porque reinstala `numpy`). Si lo pide: ve al menú **Entorno de ejecución → Reiniciar sesión** (NO "desconectar y eliminar entorno"). Tras reiniciar, **no repitas la Celda 1**; las dependencias quedan instaladas.
2. **Celda 2** — Clona el repositorio de CatVTON y prepara los archivos.
3. **Celda 3** — Monta Google Drive y trae los *checkpoints* del modelo. **Te pedirá autorizar el acceso a Drive: elige la cuenta comunal.** Si los checkpoints ya estaban guardados en el Drive comunal, esto es rápido; si no, los descarga (puede tardar, son varios GB).
4. **Celda 4** — Levanta el servidor y el túnel ngrok. **Te pedirá pegar el authtoken de ngrok**: pégalo y presiona Enter.

> **Hay una "Celda 0" (fix de PEFT)** que desinstala una librería y obliga a reiniciar la sesión. **NO la ejecutes** salvo que tengas un error que mencione explícitamente "PEFT". Si la corres, tendrás que reiniciar y volver a ejecutar desde la Celda 1.

### Resultado esperado
Cuando la Celda 4 termina bien, verás algo como:

```
SERVIDOR STYLEME CATVTON ACTIVO
URL pública ngrok: https://NOMBRE-DEL-TUNEL.ngrok-free.dev
Health check: https://NOMBRE-DEL-TUNEL.ngrok-free.dev/health
Try-on endpoint: https://NOMBRE-DEL-TUNEL.ngrok-free.dev/tryon
```

Copia esa URL del try-on (la que termina en `/tryon`) y ponla en tu `.env` en `CATVTON_TRYON_URL` (paso 6).

> **Sobre la URL de ngrok:** la cuenta comunal tiene un **dominio fijo**, así que la URL suele ser **siempre la misma** aunque reinicies el Colab. Aun así, conviene verificarla cada vez que reinicies, por si acaso.

### Errores comunes en el Colab y cómo se resolvieron
- **`FileNotFoundError: Falta checkpoint ... model.safetensors`** → ejecutaste la Celda 4 sin correr antes la Celda 3 (la que trae el modelo). Corre las celdas en orden.
- **`ValueError: numpy.dtype size changed...`** al final de la Celda 1 → es el aviso de reinicio: **reinicia la sesión** y continúa desde la Celda 2.
- **`ValueError: Mountpoint must not already contain files`** en la Celda 3 → la carpeta `/content/drive` ya tenía contenido. Solución: borrar esa carpeta antes de montar (con `shutil.rmtree("/content/drive", ignore_errors=True)`) y volver a montar. (Borrar `/content/drive` NO toca tu Drive real, solo el punto de montaje temporal de Colab.)

---

## 8. Arrancar el backend

Con MongoDB corriendo (paso 3), los modelos en su sitio (paso 4), las dependencias instaladas (paso 5) y el `.env` creado (paso 6), ya puedes arrancar el servidor.

**Clave:** hay que lanzarlo **desde dentro de `styleme-backend`**, porque la ruta de los modelos (`ML_MODELS_PATH=../`) es relativa a la carpeta desde donde ejecutas el comando. Si lo lanzas desde la raíz `Styleme/`, buscará los modelos en el lugar equivocado y fallará.

```powershell
cd ruta\a\Proyecto-de-grado\Styleme\styleme-backend
.\venv\Scripts\python.exe main.py
```

### Resultado esperado
El arranque puede tardar unos segundos mientras cargan los modelos. Deberías ver algo como:

```
✅ Conectado a MongoDB: styleme_db
(carga de los 3 modelos ML: YOLO, KMeans/color, recomendador)
INFO: Uvicorn running on http://0.0.0.0:8000
INFO: Application startup complete.
```

> Si **cualquiera de los 3 modelos** no carga, el servidor **no arranca a propósito** (para detectar el problema temprano). El error te dirá cuál modelo falta o qué ruta está mal.

### Verificar que el backend responde
Abre en el navegador:

```
http://localhost:8000/docs
```

Si carga la página de documentación (Swagger) con la lista de endpoints (Autenticación, Guardarropa, Recomendaciones, Virtual Try-On, etc.), **el backend está funcionando**.

---

## 9. Checklist rápido de verificación

Marca cada punto; si todos pasan, el entorno está listo:

- [ ] `python --version` muestra 3.11 o superior.
- [ ] MongoDB Compass conecta a `localhost:27017` y existe `styleme_db`.
- [ ] Los 3 modelos (`styleme_detector.pt`, `modelo_color.pkl`, `modelo_recomendador_outfits.pkl`) están en la **raíz** `Styleme/`.
- [ ] Existe el entorno virtual `styleme-backend/venv` y las dependencias instalaron sin errores.
- [ ] Existe `styleme-backend/.env` con `JWT_SECRET_KEY` y `CATVTON_TRYON_URL` completados.
- [ ] El Colab está corriendo y mostró la URL de ngrok (solo si vas a probar el Try-On).
- [ ] El backend arranca desde `styleme-backend/` y muestra MongoDB + 3 modelos OK.
- [ ] `http://localhost:8000/docs` carga la lista de endpoints.

---

## 10. Orden recomendado para no perderte

Si es tu primera vez, sigue exactamente este orden:

1. Requisitos previos (Python, MongoDB, Git) — paso 1.
2. Clonar el repo — paso 2.
3. Confirmar MongoDB — paso 3.
4. Descargar y colocar los 3 modelos — paso 4.
5. Crear venv + instalar dependencias — paso 5.
6. Crear el `.env` (con clave JWT; la URL de ngrok la rellenas tras el paso 7) — paso 6.
7. Encender Colab + ngrok y copiar la URL al `.env` — paso 7.
8. Arrancar el backend y verificar en `/docs` — paso 8.
9. Pasar el checklist — paso 9.

> **Consejo final:** ve paso a paso, no te saltes el orden, y si algo falla, copia el **mensaje de error completo** y pégaselo a la IA que estés usando junto con esta guía. La mayoría de los errores de instalación de StyleMe son por una de las tres piezas que no viajan por Git (`.env`, venv/dependencias, modelos) o por ejecutar algo desde la carpeta equivocada.

# 🐳 Guía de instalación — Backend de StyleMe con Docker

> Guía para levantar **solo el backend** (API + MongoDB) en Windows.
> No requiere instalar Python, MongoDB, ni las dependencias de Machine Learning.
> Tiempo estimado: 20–30 minutos la primera vez (casi todo es esperar el build).

---

## ✅ Qué vas a tener al terminar

- La API de StyleMe corriendo en `http://localhost:8000`
- Documentación interactiva (Swagger) en `http://localhost:8000/docs`
- Una base de datos MongoDB propia, aislada, dentro de Docker
- Los 3 modelos de Machine Learning cargados y funcionando

**No necesitas:** Python, MongoDB instalada, Flutter, ni el SDK de Android.

---

## 1. Instalar Docker Desktop

Descarga e instala desde: https://www.docker.com/products/docker-desktop/

Durante la instalación, deja marcada la opción **"Use WSL 2 instead of Hyper-V"** (viene marcada por defecto).

Al terminar, **reinicia el equipo** y abre Docker Desktop. Debe quedar corriendo en segundo plano — verás el ícono de la ballena en la barra de tareas.

### Verificar que quedó bien

Abre **PowerShell** o **CMD** y ejecuta:

```powershell
docker --version
docker compose version
```

Si ambos responden con un número de versión, está listo.

> ⚠️ Si Docker Desktop pide activar la virtualización, hay que habilitarla en la BIOS. Busca "Virtualization Technology" o "SVM Mode" según el fabricante.

---

## 2. Clonar el repositorio

```powershell
cd C:\Users\TU_USUARIO\Desktop
git clone https://github.com/wendyVargas313/Styleme.git
cd Styleme
```

> 💡 Si Git te pide usuario y contraseña, **GitHub ya no acepta contraseñas de cuenta**.
> La forma más fácil de resolverlo es instalar [GitHub CLI](https://cli.github.com/) y ejecutar `gh auth login`, que configura todo por navegador sin necesidad de generar tokens a mano.

---

## 3. Crear el archivo `.env`

El backend necesita un archivo de variables de entorno. En el repo viene una plantilla:

```powershell
copy styleme-backend\.env.example styleme-backend\.env
```

Abre `styleme-backend\.env` en Windsurf y **cambia el valor de `JWT_SECRET_KEY`** por cualquier texto largo y propio. Por ejemplo:

```env
JWT_SECRET_KEY=mi_clave_secreta_personal_2026_xyz789
```

> 🔒 Esta clave firma los tokens de sesión. Cada instalación debe tener la suya.
> El archivo `.env` **no se sube al repositorio** (está en `.gitignore`), así que tu clave se queda solo en tu equipo.

El resto de variables funcionan tal cual — no hace falta tocarlas.

---

## 4. Construir la imagen

```powershell
docker compose build
```

⏱️ **La primera vez tarda entre 8 y 20 minutos.** Descarga Python, PyTorch, y las librerías de ML.

Verás una lista de pasos numerados (`[1/10]`, `[2/10]`…). Es normal que el paso de `pip install` se quede varios minutos sin mostrar nada — no está colgado, está instalando.

Al final debe aparecer algo como:

```
=> => naming to docker.io/library/styleme-backend:latest
✔ styleme-backend  Built
```

---

## 5. Levantar el proyecto

```powershell
docker compose up -d
```

Esto arranca **dos contenedores**: el backend y MongoDB.

Verificar que ambos están arriba:

```powershell
docker compose ps
```

Deben aparecer `styleme-backend-1` y `styleme-mongo-1`, ambos con estado **Up**.

---

## 6. Verificar que funciona

```powershell
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

Lo importante:

- **`"database": "connected"`** → MongoDB conectada
- **Los tres `_loaded` en `true`** → modelos de ML cargados

Ahora abre en el navegador: **http://localhost:8000/docs**

Ahí tienes la documentación interactiva de todos los endpoints, con botón para probarlos directamente.

---

## 7. Crear tu primer usuario

La base de datos arranca **vacía**. Puedes registrarte desde Swagger (`/docs` → `POST /api/v1/auth/registro` → *Try it out*) o por consola:

```powershell
curl -X POST http://localhost:8000/api/v1/auth/registro -H "Content-Type: application/json" -d "{\"nombre\":\"Laura\",\"email\":\"laura@test.com\",\"password\":\"Test1234!\",\"genero\":\"femenino\"}"
```

Luego el login te devuelve el token JWT que necesitas para los endpoints protegidos:

```powershell
curl -X POST http://localhost:8000/api/v1/auth/login -H "Content-Type: application/json" -d "{\"email\":\"laura@test.com\",\"password\":\"Test1234!\"}"
```

---

## 📋 Comandos del día a día

| Qué quieres hacer | Comando |
|---|---|
| Levantar el proyecto | `docker compose up -d` |
| Detener el proyecto | `docker compose stop` |
| Ver los logs en vivo | `docker compose logs -f` |
| Ver solo los logs del backend | `docker compose logs -f backend` |
| Ver el estado | `docker compose ps` |
| Reconstruir tras cambiar código | `docker compose build` y luego `docker compose up -d` |

> 🔴 **Nunca uses `docker compose down -v`.**
> La bandera `-v` **borra la base de datos completa** (usuarios, prendas, outfits).
> Para apagar el proyecto usa siempre `docker compose stop`.

---

## ⚠️ Importante: el código está dentro de la imagen

Si modificas cualquier archivo `.py` del backend, **el contenedor no lo ve** hasta que reconstruyas:

```powershell
docker compose build
docker compose up -d
```

Esto tarda menos que la primera vez (unos 1–3 minutos), porque Docker reutiliza las capas que no cambiaron.

---

## 🛠️ Trabajar con Windsurf

Windsurf es un editor basado en VS Code, así que funciona bien con este proyecto:

- Abre la carpeta `Styleme` completa como workspace
- La extensión **Docker** de VS Code funciona en Windsurf y te deja ver contenedores y logs desde la barra lateral
- El terminal integrado (`Ctrl + ñ`) sirve para todos los comandos de esta guía
- Los archivos que vas a tocar están en `styleme-backend/app/`

> 💡 Para explorar la API sin escribir código, `http://localhost:8000/docs` es lo más rápido.

---

## 🗄️ Inspeccionar la base de datos (opcional)

Si quieres ver los datos con MongoDB Compass, la base del contenedor está publicada en:

```
mongodb://localhost:27018
```

⚠️ **Puerto 27018, no 27017.** Se eligió así a propósito para no chocar si ya tienes MongoDB instalada en Windows.

---

## 🐛 Problemas comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `docker: command not found` | Docker Desktop no está corriendo | Abrir Docker Desktop y esperar a que arranque |
| `port is already allocated` | Algo más usa el puerto 8000 | Cerrar lo que lo ocupe, o cambiar el puerto en `docker-compose.yml` |
| `"database": "disconnected"` | El contenedor de Mongo no arrancó | `docker compose ps` y revisar `docker compose logs mongo` |
| Los modelos salen en `false` | El build no copió los modelos | Verificar que los `.pkl` y `.pt` estén en la raíz del repo tras clonar |
| El build falla al descargar | Problema de red o proxy | Reintentar; si persiste, revisar el proxy del equipo |
| Cambié código y no se refleja | El código está horneado en la imagen | `docker compose build` y luego `up -d` |
| Git pide contraseña y la rechaza | GitHub ya no acepta contraseñas | Usar `gh auth login` (ver paso 2) |

---

## 📚 Más información

El `README.md` en la raíz del repositorio tiene la descripción completa del proyecto: arquitectura, modelos de ML, lista de endpoints y flujo de recomendación.

---

*StyleMe — Universidad Manuela Beltrán*

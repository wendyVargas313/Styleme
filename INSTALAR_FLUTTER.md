# Guía de Instalación del Flutter SDK

El proyecto Flutter de StyleMe está completo pero requiere el **Flutter SDK** para compilar y ejecutar.

---

## 1. Descargar Flutter SDK

Ir a: https://docs.flutter.dev/get-started/install/windows/mobile

O descargar directamente:
```
https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.32.3-stable.zip
```

## 2. Instalar en la ruta esperada

Extraer el ZIP en:
```
D:\01.Downloads\flutter\
```

El resultado debe quedar así:
```
D:\01.Downloads\flutter\
  bin\
    flutter.bat     ← Ejecutable principal
    dart.bat
  packages\
  ...
```

## 3. Verificar instalación

Abrir PowerShell y ejecutar:
```powershell
D:\01.Downloads\flutter\bin\flutter.bat doctor
```

Debe mostrar:
```
[✓] Flutter (Channel stable, 3.32.3)
[✓] Windows Version
[!] Android toolchain (falta configurar si no está)
[✓] Android Studio
```

## 4. Instalar dependencias del proyecto

```powershell
cd D:\Styleme\styleme-flutter
D:\01.Downloads\flutter\bin\flutter.bat pub get
```

## 5. Ejecutar la app

### Con emulador Android (recomendado)
```powershell
# Abrir Android Studio → Device Manager → Crear/iniciar AVD
D:\01.Downloads\flutter\bin\flutter.bat run
```

### Con dispositivo físico Android
```powershell
# Activar Opciones de Desarrollador en el teléfono
# Conectar por USB y habilitar Depuración USB
D:\01.Downloads\flutter\bin\flutter.bat devices
D:\01.Downloads\flutter\bin\flutter.bat run -d <id_dispositivo>
```

---

## Configuración de la URL del backend

Antes de ejecutar, verificar en `lib/config/api_config.dart`:

| Caso | URL |
|------|-----|
| Emulador Android | `http://10.0.2.2:8000` (ya configurado) |
| iOS Simulator | `http://localhost:8000` |
| Dispositivo físico | `http://TU_IP_LOCAL:8000` |

Para encontrar tu IP local: `ipconfig` → "Adaptador de red Wi-Fi" → Dirección IPv4

---

## Arranque completo del sistema

**Terminal 1 — Backend:**
```powershell
powershell -ExecutionPolicy Bypass -File D:\Styleme\iniciar_backend.ps1
```

**Terminal 2 — Flutter:**
```powershell
cd D:\Styleme\styleme-flutter
D:\01.Downloads\flutter\bin\flutter.bat run
```

---

## Solución de problemas

**Error "No devices found"**
→ Abrir Android Studio y asegurarse de que el emulador esté corriendo

**Error "Connection refused"**
→ Verificar que el backend esté activo en `http://localhost:8000/api/v1/health`

**Error "pub get failed"**
→ Ejecutar `flutter.bat clean` y luego `flutter.bat pub get` nuevamente

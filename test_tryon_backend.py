"""
Script de prueba end-to-end del endpoint /tryon.
Flujo: registro → login → try-on → guardar resultado.
"""

import base64
import io
import json
import sys
from pathlib import Path

import httpx

# Forzar salida UTF-8 para evitar UnicodeEncodeError en consolas Windows (cp1252)
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

BASE_URL = "http://localhost:8000/api/v1"
RAIZ = Path(__file__).parent

PERSONA_IMG = RAIZ / "test_persona_YO.png"
PRENDA_IMG  = RAIZ / "test_camiseta.jpg"
RESULTADO   = RAIZ / "resultado_tryon_backend.jpg"

USUARIO = {
    "nombre":   "Prueba TryOn",
    "email":    "prueba_tryon@test.com",
    "password": "Test1234!",
    "genero":   "masculino",
}


def sep(titulo: str):
    print(f"\n{'='*60}")
    print(f"  {titulo}")
    print('='*60)


def b64_imagen(ruta: Path) -> str:
    return base64.b64encode(ruta.read_bytes()).decode("utf-8")


def main():
    # ── 0. Verificar imágenes ─────────────────────────────────
    sep("0. Verificando imágenes de entrada")
    for img in (PERSONA_IMG, PRENDA_IMG):
        if not img.exists():
            print(f"  ❌ No encontrada: {img}")
            sys.exit(1)
        print(f"  ✅ {img.name}  ({img.stat().st_size / 1024:.1f} KB)")

    # ── 1. Registro ───────────────────────────────────────────
    sep("1. Registro")
    r = httpx.post(f"{BASE_URL}/auth/registro", json=USUARIO)
    print(f"  Status: {r.status_code}")
    if r.status_code == 201:
        print(f"  ✅ Usuario creado: {r.json()}")
    elif r.status_code in (400, 409, 422):
        print(f"  ⚠️  Usuario ya existe o error de validación — continuando al login")
        print(f"  Respuesta: {r.text}")
    else:
        print(f"  ❌ Error inesperado: {r.text}")
        sys.exit(1)

    # ── 2. Login ──────────────────────────────────────────────
    sep("2. Login")
    r = httpx.post(f"{BASE_URL}/auth/login", json={
        "email":    USUARIO["email"],
        "password": USUARIO["password"],
    })
    print(f"  Status: {r.status_code}")
    if r.status_code != 200:
        print(f"  ❌ Login fallido: {r.text}")
        sys.exit(1)
    data_login = r.json()
    token = data_login.get("access_token") or data_login.get("token")
    if not token:
        print(f"  ❌ No se encontró token en la respuesta: {data_login}")
        sys.exit(1)
    print(f"  ✅ Token obtenido: {token[:30]}...")

    # ── 3. Try-on ─────────────────────────────────────────────
    sep("3. Try-on (POST /tryon)")
    print(f"  Convirtiendo imágenes a base64...")
    persona_b64 = b64_imagen(PERSONA_IMG)
    prenda_b64  = b64_imagen(PRENDA_IMG)
    print(f"  persona base64: {len(persona_b64):,} chars")
    print(f"  prenda  base64: {len(prenda_b64):,} chars")

    payload = {
        "imagen_persona": persona_b64,
        "imagen_prenda":  prenda_b64,
        "categoria":      "upper",
    }
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type":  "application/json",
    }

    print(f"\n  Enviando petición al backend (timeout: 5 min)...")
    try:
        r = httpx.post(
            f"{BASE_URL}/tryon",
            json=payload,
            headers=headers,
            timeout=300.0,
        )
    except httpx.TimeoutException:
        print("  ❌ Timeout: el servidor no respondió en 5 minutos")
        sys.exit(1)
    except httpx.ConnectError as e:
        print(f"  ❌ No se pudo conectar al backend: {e}")
        sys.exit(1)

    print(f"\n  Status: {r.status_code}")

    if r.status_code != 200:
        print(f"  ❌ Error del servidor:")
        try:
            print(f"  {json.dumps(r.json(), indent=2, ensure_ascii=False)}")
        except Exception:
            print(f"  {r.text}")
        sys.exit(1)

    data = r.json()
    print(f"  ok:                      {data.get('ok')}")
    print(f"  tiempo_inferencia_catvton: {data.get('tiempo_inferencia_catvton')} s")
    print(f"  tiempo_total_backend:      {data.get('tiempo_total_backend')} s")

    imagen_b64 = data.get("imagen_resultado", "")
    if not imagen_b64:
        print("  ❌ La respuesta no contiene imagen_resultado")
        sys.exit(1)

    # ── 4. Guardar resultado ──────────────────────────────────
    sep("4. Guardando resultado")
    imagen_bytes = base64.b64decode(imagen_b64)
    RESULTADO.write_bytes(imagen_bytes)
    print(f"  ✅ Imagen guardada: {RESULTADO.name}  ({len(imagen_bytes)/1024:.1f} KB)")
    print(f"  Ruta completa: {RESULTADO}")

    sep("RESULTADO FINAL")
    print("  ✅ Prueba end-to-end completada exitosamente.")
    print(f"  Abre {RESULTADO.name} en la raíz del proyecto para ver el resultado.")


if __name__ == "__main__":
    main()

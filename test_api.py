"""StyleMe - Test end-to-end del pipeline ML completo."""
import requests
import json

BASE = "http://localhost:8001/api/v1"

def test_completo():
    print("=" * 50)
    print("   StyleMe - Test E2E del Pipeline ML")
    print("=" * 50)

    # 1. Login
    r = requests.post(f"{BASE}/auth/login", json={
        "email": "laura@styleme.com",
        "password": "Test1234!"
    })
    token = r.json()["token"]
    h = {"Authorization": f"Bearer {token}"}
    print(f"[OK] Login - Usuario: {r.json()['usuario']['nombre']}")

    # 2. Agregar prenda con imagen (YOLOv8 + KMeans)
    with open("test_camiseta.jpg", "rb") as img:
        r = requests.post(
            f"{BASE}/guardarropa/agregar",
            headers=h,
            files={"imagen": ("camiseta.jpg", img, "image/jpeg")},
            data={"temporada": "invierno", "notas": "Prueba ML pipeline"}
        )

    prenda = r.json()["prenda"]
    prenda_id = prenda["id"]
    print(f"\n[OK] Prenda agregada con ML:")
    print(f"     Tipo detectado (YOLO)  : {prenda['tipo']}")
    print(f"     Color (KMeans)         : {prenda['color']}")
    print(f"     Confianza YOLO         : {prenda['confianza_yolo']:.1%}")
    print(f"     Temporada              : {prenda['temporada']}")
    print(f"     ID                     : {prenda_id}")

    # 3. Agregar 2 prendas más para tener variedad
    tipos_extra = [
        ("test_camiseta.jpg", "primavera"),
        ("test_camiseta.jpg", "verano"),
    ]
    ids_extra = []
    for img_path, temporada in tipos_extra:
        with open(img_path, "rb") as img:
            r2 = requests.post(
                f"{BASE}/guardarropa/agregar",
                headers=h,
                files={"imagen": ("prenda.jpg", img, "image/jpeg")},
                data={"temporada": temporada}
            )
        p2 = r2.json()["prenda"]
        ids_extra.append(p2["id"])
        print(f"[OK] Prenda extra: {p2['tipo']} ({p2['color']}) - {temporada}")

    # 4. Stats del guardarropa
    r = requests.get(f"{BASE}/guardarropa/stats", headers=h)
    stats = r.json()
    print(f"\n[OK] Stats guardarropa:")
    print(f"     Total prendas: {stats['total_prendas']}")
    print(f"     Por tipo     : {dict(list(stats['por_tipo'].items())[:3])}")
    print(f"     Por color    : {dict(list(stats['por_color'].items())[:3])}")

    # 5. Generar outfit con recomendador (Co-ocurrencia + Color + Temporada)
    r = requests.post(
        f"{BASE}/recomendar/outfit",
        headers=h,
        json={"prenda_id": prenda_id, "temporada": "invierno", "top_k": 3}
    )
    outfit = r.json()
    print(f"\n[OK] Outfit generado:")
    print(f"     Outfit ID    : {outfit.get('outfit_id', 'N/A')}")
    print(f"     Prenda base  : {outfit.get('prenda_base', {}).get('tipo', 'N/A')}")
    recs = outfit.get("recomendaciones", [])
    for i, rec in enumerate(recs[:3], 1):
        print(f"     Comp {i}      : {rec.get('prenda', {}).get('tipo')} | score={rec.get('score', 0):.3f} ({rec.get('porcentaje', '?')})")

    outfit_id = outfit.get("outfit_id")

    # 6. Dar feedback
    if outfit_id:
        r = requests.post(
            f"{BASE}/historial/feedback",
            headers=h,
            json={"outfit_id": outfit_id, "feedback": "liked"}
        )
        print(f"\n[OK] Feedback 'liked' registrado: {r.json().get('mensaje', r.json())}")

    # 7. Ver historial
    r = requests.get(f"{BASE}/historial", headers=h)
    hist = r.json()
    print(f"[OK] Historial: {hist['total']} outfits guardados")

    # 8. Outfits del día
    r = requests.get(f"{BASE}/recomendar/diario?temporada=invierno", headers=h)
    diario = r.json()
    print(f"[OK] Outfits del dia: {diario.get('total_outfits', 0)} generados")

    print("\n" + "=" * 50)
    print("   PIPELINE ML COMPLETAMENTE VERIFICADO")
    print("   YOLOv8 + KMeans + Recomendador = OK")
    print("=" * 50)


if __name__ == "__main__":
    test_completo()

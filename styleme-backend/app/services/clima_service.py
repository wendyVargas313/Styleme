# app/services/clima_service.py
"""Servicio de clima: resuelve pronóstico o climatología para un lugar y fecha."""

import asyncio
import logging
import unicodedata
from datetime import date, datetime, timedelta

import httpx
from fastapi import HTTPException

from app.config.settings import settings

logger = logging.getLogger(__name__)

_TIMEOUT = 10.0

# Caché local de ciudades colombianas frecuentes: nombre_normalizado -> (lat, lon, nombre_canonico)
_CIUDADES_COLOMBIA = {
    "bogota": (4.61, -74.08, "Bogotá, Cundinamarca, CO"),
    "medellin": (6.25, -75.56, "Medellín, Antioquia, CO"),
    "cali": (3.44, -76.52, "Cali, Valle del Cauca, CO"),
    "cartagena": (10.39, -75.51, "Cartagena de Indias, Bolívar, CO"),
    "barranquilla": (10.96, -74.80, "Barranquilla, Atlántico, CO"),
    "santa marta": (11.24, -74.20, "Santa Marta, Magdalena, CO"),
    "bucaramanga": (7.12, -73.13, "Bucaramanga, Santander, CO"),
    "pereira": (4.81, -75.69, "Pereira, Risaralda, CO"),
    "manizales": (5.07, -75.52, "Manizales, Caldas, CO"),
    "cucuta": (7.89, -72.50, "Cúcuta, Norte de Santander, CO"),
    "villavicencio": (4.14, -73.63, "Villavicencio, Meta, CO"),
    "armenia": (4.53, -75.68, "Armenia, Quindío, CO"),
    "ibague": (4.44, -75.24, "Ibagué, Tolima, CO"),
    "pasto": (1.21, -77.28, "Pasto, Nariño, CO"),
    "san andres": (12.58, -81.70, "San Andrés, San Andrés y Providencia, CO"),
}

# Mapeo acotado de códigos WMO a descripciones en español
_WMO_DESCRIPCIONES = {
    0: "cielo despejado",
    1: "mayormente despejado",
    2: "parcialmente nublado",
    3: "nublado",
    45: "neblina",
    48: "neblina con escarcha",
    51: "llovizna ligera",
    53: "llovizna moderada",
    55: "llovizna intensa",
    56: "llovizna helada ligera",
    57: "llovizna helada intensa",
    61: "lluvia ligera",
    63: "lluvia moderada",
    65: "lluvia intensa",
    66: "lluvia helada ligera",
    67: "lluvia helada intensa",
    71: "nevada ligera",
    73: "nevada moderada",
    75: "nevada intensa",
    77: "granos de nieve",
    80: "chubascos ligeros",
    81: "chubascos moderados",
    82: "chubascos violentos",
    85: "chubascos de nieve ligeros",
    86: "chubascos de nieve intensos",
    95: "tormenta eléctrica",
    96: "tormenta con granizo ligero",
    99: "tormenta con granizo intenso",
}


def _normalizar_texto(texto: str) -> str:
    """Minúsculas, sin tildes, sin espacios extra."""
    sin_tildes = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode("ascii")
    return " ".join(sin_tildes.lower().split())


def _parsear_fecha(fecha: str) -> date:
    """Convierte 'YYYY-MM-DD' a date, lanza 400 si el formato es inválido."""
    try:
        return datetime.strptime(fecha, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Fecha inválida: '{fecha}'. Formato esperado YYYY-MM-DD")


async def _resolver_coordenadas(lugar: str) -> tuple[float, float, str]:
    """Resuelve lat/lon y nombre canónico: caché local primero, luego geocoding de Open-Meteo."""
    clave = _normalizar_texto(lugar)
    if clave in _CIUDADES_COLOMBIA:
        lat, lon, nombre = _CIUDADES_COLOMBIA[clave]
        return lat, lon, nombre

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            resp = await client.get(
                "https://geocoding-api.open-meteo.com/v1/search",
                params={"name": lugar, "count": 10, "language": "es", "format": "json"},
            )
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPError as e:
        raise HTTPException(status_code=503, detail=f"Servicio de clima no disponible: {e}")

    resultados = data.get("results") or []
    if not resultados:
        raise HTTPException(status_code=404, detail=f"No se encontró el lugar '{lugar}'")

    mejor = max(resultados, key=lambda r: r.get("population") or 0)
    nombre_canonico = ", ".join(
        parte for parte in (mejor.get("name"), mejor.get("admin1"), mejor.get("country_code")) if parte
    )
    return mejor["latitude"], mejor["longitude"], nombre_canonico


async def _clima_pronostico_openweather(lat: float, lon: float, fecha_objetivo: date) -> dict:
    """Rama 0-5 días: OpenWeather forecast de 3h, filtrado y agregado al día objetivo."""
    if not settings.OPENWEATHER_API_KEY:
        raise HTTPException(status_code=503, detail="Servicio de clima no disponible: falta OPENWEATHER_API_KEY")

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            resp = await client.get(
                "https://api.openweathermap.org/data/2.5/forecast",
                params={
                    "lat": lat,
                    "lon": lon,
                    "appid": settings.OPENWEATHER_API_KEY,
                    "units": "metric",
                    "lang": "es",
                },
            )
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPError as e:
        raise HTTPException(status_code=503, detail=f"Servicio de clima no disponible: {e}")

    fecha_str = fecha_objetivo.isoformat()
    bloques = [b for b in data.get("list", []) if b.get("dt_txt", "").startswith(fecha_str)]

    if not bloques:
        raise HTTPException(
            status_code=503,
            detail="Servicio de clima no disponible: sin datos de pronóstico para la fecha solicitada",
        )

    temp_max = max(b["main"]["temp_max"] for b in bloques)
    temp_min = min(b["main"]["temp_min"] for b in bloques)
    humedad_prom = sum(b["main"]["humidity"] for b in bloques) / len(bloques)
    precipitacion_total = sum(b.get("rain", {}).get("3h", 0.0) for b in bloques)

    conteo_descripciones: dict[str, int] = {}
    for b in bloques:
        clima = b.get("weather", [])
        if clima:
            desc = clima[0].get("description", "")
            conteo_descripciones[desc] = conteo_descripciones.get(desc, 0) + 1
    descripcion = max(conteo_descripciones, key=conteo_descripciones.get) if conteo_descripciones else ""

    return {
        "temp_max": round(temp_max, 1),
        "temp_min": round(temp_min, 1),
        "temp_promedio": round((temp_max + temp_min) / 2, 1),
        "humedad": round(humedad_prom),
        "precipitacion_mm": round(precipitacion_total, 1),
        "dias_con_lluvia_pct": 0,
        "descripcion": descripcion,
        "fuente": "pronostico",
        "confianza": "alta",
        "detalle_fuente": "pronóstico horario OpenWeather agregado al día objetivo",
    }


async def _clima_pronostico_extendido(lat: float, lon: float, fecha_objetivo: date) -> dict:
    """Rama 6-10 días: Open-Meteo Forecast (daily incluye relative_humidity_2m_mean)."""
    fecha_str = fecha_objetivo.isoformat()

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            resp = await client.get(
                "https://api.open-meteo.com/v1/forecast",
                params={
                    "latitude": lat,
                    "longitude": lon,
                    "daily": (
                        "temperature_2m_max,temperature_2m_min,precipitation_sum,"
                        "precipitation_probability_max,weather_code,relative_humidity_2m_mean"
                    ),
                    "timezone": "auto",
                    "start_date": fecha_str,
                    "end_date": fecha_str,
                },
            )
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPError as e:
        raise HTTPException(status_code=503, detail=f"Servicio de clima no disponible: {e}")

    diario = data.get("daily", {})
    if not diario.get("time"):
        raise HTTPException(
            status_code=503,
            detail="Servicio de clima no disponible: sin datos de pronóstico extendido para la fecha solicitada",
        )

    temp_max = diario["temperature_2m_max"][0]
    temp_min = diario["temperature_2m_min"][0]
    precipitacion = diario["precipitation_sum"][0] or 0.0
    prob_lluvia = diario["precipitation_probability_max"][0] or 0
    humedad = diario["relative_humidity_2m_mean"][0]
    codigo_clima = diario["weather_code"][0]

    return {
        "temp_max": round(temp_max, 1),
        "temp_min": round(temp_min, 1),
        "temp_promedio": round((temp_max + temp_min) / 2, 1),
        "humedad": round(humedad),
        "precipitacion_mm": round(precipitacion, 1),
        "dias_con_lluvia_pct": round(prob_lluvia),
        "descripcion": _WMO_DESCRIPCIONES.get(codigo_clima, "condiciones variables"),
        "fuente": "pronostico_extendido",
        "confianza": "media",
        "detalle_fuente": "pronóstico diario Open-Meteo",
    }


async def _climatologia_una_ventana(client: httpx.AsyncClient, lat: float, lon: float, inicio: date, fin: date) -> list[dict]:
    """Consulta el Archive de Open-Meteo para una ventana de fechas de un año específico."""
    try:
        resp = await client.get(
            "https://archive-api.open-meteo.com/v1/archive",
            params={
                "latitude": lat,
                "longitude": lon,
                "start_date": inicio.isoformat(),
                "end_date": fin.isoformat(),
                "daily": (
                    "temperature_2m_max,temperature_2m_min,"
                    "relative_humidity_2m_mean,precipitation_sum"
                ),
                "timezone": "auto",
            },
        )
        resp.raise_for_status()
        data = resp.json()
    except httpx.HTTPError as e:
        raise HTTPException(status_code=503, detail=f"Servicio de clima no disponible: {e}")

    diario = data.get("daily", {})
    dias = []
    tiempos = diario.get("time", [])
    for i in range(len(tiempos)):
        dias.append({
            "temp_max": diario.get("temperature_2m_max", [])[i] if i < len(diario.get("temperature_2m_max", [])) else None,
            "temp_min": diario.get("temperature_2m_min", [])[i] if i < len(diario.get("temperature_2m_min", [])) else None,
            "humedad": diario.get("relative_humidity_2m_mean", [])[i] if i < len(diario.get("relative_humidity_2m_mean", [])) else None,
            "precipitacion": diario.get("precipitation_sum", [])[i] if i < len(diario.get("precipitation_sum", [])) else None,
        })
    return dias


async def _clima_climatologia(lat: float, lon: float, fecha_objetivo: date) -> dict:
    """Rama >10 días: climatología de 5 años (±7 días) vía Open-Meteo Archive."""
    hoy = date.today()
    anios = range(hoy.year - 5, hoy.year)

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        tareas = []
        for anio in anios:
            try:
                dia_referencia = fecha_objetivo.replace(year=anio)
            except ValueError:
                # 29 de febrero en año no bisiesto: usar 28 de febrero
                dia_referencia = fecha_objetivo.replace(year=anio, day=28)
            inicio = dia_referencia - timedelta(days=7)
            fin = dia_referencia + timedelta(days=7)
            tareas.append(_climatologia_una_ventana(client, lat, lon, inicio, fin))

        resultados_por_anio = await asyncio.gather(*tareas)

    todos_los_dias = [dia for ventana in resultados_por_anio for dia in ventana]

    temp_max_vals = [d["temp_max"] for d in todos_los_dias if d["temp_max"] is not None]
    temp_min_vals = [d["temp_min"] for d in todos_los_dias if d["temp_min"] is not None]
    humedad_vals = [d["humedad"] for d in todos_los_dias if d["humedad"] is not None]
    precipitacion_vals = [d["precipitacion"] for d in todos_los_dias if d["precipitacion"] is not None]

    if not temp_max_vals or not temp_min_vals:
        raise HTTPException(
            status_code=503,
            detail="Servicio de clima no disponible: sin datos históricos suficientes para climatología",
        )

    temp_max_prom = sum(temp_max_vals) / len(temp_max_vals)
    temp_min_prom = sum(temp_min_vals) / len(temp_min_vals)
    humedad_prom = sum(humedad_vals) / len(humedad_vals) if humedad_vals else 0.0
    precipitacion_prom = sum(precipitacion_vals) / len(precipitacion_vals) if precipitacion_vals else 0.0
    dias_con_lluvia_pct = (
        (sum(1 for p in precipitacion_vals if p > 1.0) / len(precipitacion_vals)) * 100
        if precipitacion_vals else 0.0
    )

    if precipitacion_prom > 5:
        descripcion = "cálido y húmedo" if temp_max_prom >= 25 else "fresco y lluvioso"
    else:
        descripcion = "cálido y seco" if temp_max_prom >= 25 else "templado y seco"

    return {
        "temp_max": round(temp_max_prom, 1),
        "temp_min": round(temp_min_prom, 1),
        "temp_promedio": round((temp_max_prom + temp_min_prom) / 2, 1),
        "humedad": round(humedad_prom),
        "precipitacion_mm": round(precipitacion_prom, 1),
        "dias_con_lluvia_pct": round(dias_con_lluvia_pct),
        "descripcion": descripcion,
        "fuente": "climatologia",
        "confianza": "baja",
        "detalle_fuente": f"promedio de 5 años ({hoy.year - 5}–{hoy.year - 1}), ventana ±7 días",
    }


async def obtener_clima(lugar: str, fecha: str) -> dict:
    """
    Obtiene el clima esperado para un lugar y fecha futura.

    Rutea automáticamente entre pronóstico (OpenWeather), pronóstico extendido
    (Open-Meteo Forecast) o climatología histórica (Open-Meteo Archive) según
    qué tan lejos esté la fecha objetivo.
    """
    fecha_objetivo = _parsear_fecha(fecha)
    hoy = date.today()
    delta = (fecha_objetivo - hoy).days

    if delta < 0:
        raise HTTPException(status_code=400, detail="La fecha del evento ya pasó")

    lat, lon, nombre_canonico = await _resolver_coordenadas(lugar)

    if delta <= 5:
        datos = await _clima_pronostico_openweather(lat, lon, fecha_objetivo)
    elif delta <= 10:
        datos = await _clima_pronostico_extendido(lat, lon, fecha_objetivo)
    else:
        datos = await _clima_climatologia(lat, lon, fecha_objetivo)

    return {
        "lugar": nombre_canonico,
        "coordenadas": {"lat": round(lat, 2), "lon": round(lon, 2)},
        "fecha_objetivo": fecha_objetivo.isoformat(),
        **datos,
    }

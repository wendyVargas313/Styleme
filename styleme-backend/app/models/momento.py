# StyleMe - Fuente única de verdad para el campo "momento" de las prendas
"""
Reemplaza el viejo campo "temporada" (primavera/verano/otono/invierno) por
un modelo soleado/lluvioso/ambos, más simple y alineado con el uso real de
la prenda (qué tan abrigada es) que con la estación del año.

Alcance: el guardarropa es solo para Bogotá, así que no hay estaciones
reales — la variable que importa es sol (fresco/ligero) vs. lluvia o frío
(abrigado).
"""

MOMENTOS_VALIDOS = ["soleado", "lluvioso", "ambos"]
MOMENTO_DEFAULT = "ambos"

# Valores legados aceptados en la entrada (API vieja con dia/noche): se
# traducen al guardar, nunca se persisten tal cual.
MAPEO_LEGADO_A_MOMENTO = {
    "dia": "soleado",
    "noche": "lluvioso",
}

# Mapeo de respaldo para prendas viejas que solo tienen "temporada" (sin migrar).
MAPEO_TEMPORADA_A_MOMENTO = {
    "verano": "soleado",
    "invierno": "lluvioso",
    "primavera": "ambos",
    "otono": "ambos",
}


def normalizar_momento(valor) -> str | None:
    """
    Normaliza un valor de entrada al vocabulario vigente de "momento".

    Devuelve el valor tal cual si ya es válido, lo traduce si es un valor
    legado (dia/noche), o None si no se reconoce.
    """
    if valor in MOMENTOS_VALIDOS:
        return valor
    if valor in MAPEO_LEGADO_A_MOMENTO:
        return MAPEO_LEGADO_A_MOMENTO[valor]
    return None


def momento_de_prenda(doc: dict) -> str:
    """
    Devuelve el momento efectivo de una prenda.

    Prioridad: "momento" normalizado (válido o legado) > derivado de
    "temporada" (prendas viejas sin migrar, vía MAPEO_TEMPORADA_A_MOMENTO)
    > MOMENTO_DEFAULT.
    """
    momento_normalizado = normalizar_momento(doc.get("momento"))
    if momento_normalizado is not None:
        return momento_normalizado

    temporada = doc.get("temporada")
    if temporada in MAPEO_TEMPORADA_A_MOMENTO:
        return MAPEO_TEMPORADA_A_MOMENTO[temporada]

    return MOMENTO_DEFAULT

# StyleMe - Fuente única de verdad para el campo "momento" de las prendas
"""
Reemplaza el viejo campo "temporada" (primavera/verano/otono/invierno) por
un modelo día/noche/ambos, más simple y alineado con el uso real de la
prenda (qué tan abrigada es) que con la estación del año.
"""

MOMENTOS_VALIDOS = ["dia", "noche", "ambos"]
MOMENTO_DEFAULT = "ambos"

# Mapeo de respaldo para prendas viejas que solo tienen "temporada" (sin migrar).
MAPEO_TEMPORADA_A_MOMENTO = {
    "verano": "dia",
    "invierno": "noche",
    "primavera": "ambos",
    "otono": "ambos",
}


def momento_de_prenda(doc: dict) -> str:
    """
    Devuelve el momento efectivo de una prenda.

    Prioridad: "momento" si existe y es válido > derivado de "temporada"
    (prendas viejas sin migrar, vía MAPEO_TEMPORADA_A_MOMENTO) > MOMENTO_DEFAULT.
    """
    momento = doc.get("momento")
    if momento in MOMENTOS_VALIDOS:
        return momento

    temporada = doc.get("temporada")
    if temporada in MAPEO_TEMPORADA_A_MOMENTO:
        return MAPEO_TEMPORADA_A_MOMENTO[temporada]

    return MOMENTO_DEFAULT

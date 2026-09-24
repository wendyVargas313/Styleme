# app/services/prompt_agente.py
"""Prompt del agente de outfits y utilidades asociadas (filtrado de prendas, validación de salida del LLM).

SYSTEM_PROMPT, EXPRESION_POR_CONFIANZA y construir_mensaje_usuario están
copiados tal cual de scripts/verificar_prompt_agente.py, donde fueron
verificados contra la API real de Groq. No modificar ese texto sin volver
a correr la verificación.
"""

from app.models.momento import momento_de_prenda

# Umbrales para decidir qué momentos ("dia"/"noche"/"ambos") son apropiados
# según el clima esperado del evento (ver filtrar_prendas).
UMBRAL_CALOR_MAX = 22   # temp_max >= esto -> permite "dia"
UMBRAL_FRIO_MAX = 16    # temp_max <= esto -> permite "noche"
UMBRAL_LLUVIA_MM = 1.0
UMBRAL_DIAS_LLUVIA_PCT = 50
PALABRAS_LLUVIA = ("lluvia", "llovizna", "tormenta", "chubasco", "aguacero")

LEYENDA_MOMENTO = (
    "momento: dia = ropa fresca para calor, noche = ropa abrigada para frio "
    "o lluvia, ambos = sirve en los dos casos"
)

SYSTEM_PROMPT = """Eres un asesor de vestuario. Recomiendas outfits usando UNICAMENTE las
prendas del guardarropa que se te entrega.

REGLAS
1. Cada prenda se identifica por su indice entero. Usa solo indices que
   aparezcan en la lista. Nunca inventes uno.
2. Cada outfit combina prendas coherentes entre si y apropiadas para el
   evento y el clima indicados.
3. Los 3 outfits deben ser distintos entre si.
4. Para referirte al clima usa exactamente la expresion indicada en el
   bloque CLIMA. Si la confianza no es alta, NUNCA afirmes el clima como
   un hecho.
5. Si el bloque de clima trae la marca (derivado), su descripcion es un
   promedio calculado, no una observacion. Tratala como tendencia.

FORMATO
Responde SOLO con un objeto JSON valido. Sin markdown, sin texto antes
ni despues. Estructura exacta:

{"outfits":[{"nombre":"","prendas":[],"justificacion":""}],"notas":[]}

- exactamente 3 outfits
- "nombre": maximo 4 palabras
- "prendas": arreglo de indices enteros
- "justificacion": maximo 2 frases
- "notas": 0 a 2 elementos, una frase cada uno, senalando que le falta al
  guardarropa para este evento. Si no falta nada, arreglo vacio."""


EXPRESION_POR_CONFIANZA = {
    "alta": "se pronostica",
    "media": "la proyeccion indica",
    "baja": "tipicamente en esa epoca",
}


def construir_mensaje_usuario(descripcion_evento: str, clima: dict, prendas: list[dict]) -> str:
    marca = " (derivado)" if clima["fuente"] == "climatologia" else ""
    expresion = EXPRESION_POR_CONFIANZA.get(clima["confianza"], "la proyeccion indica")
    lineas = "\n".join(
        f"{i} {p['tipo']} {p['color']} {momento_de_prenda(p)}" for i, p in enumerate(prendas)
    )
    return f"""EVENTO: {descripcion_evento}
LUGAR: {clima["lugar"]}
FECHA: {clima["fecha_objetivo"]}

CLIMA (confianza {clima["confianza"]}){marca}
Usa la expresion: "{expresion}"
{clima["temp_min"]}-{clima["temp_max"]}C, promedio {clima["temp_promedio"]}C
humedad {clima["humedad"]}%, lluvia {clima["precipitacion_mm"]}mm, dias con lluvia {clima["dias_con_lluvia_pct"]}%
{clima["descripcion"]}

{LEYENDA_MOMENTO}
GUARDARROPA
{lineas}"""


def _momentos_permitidos(clima: dict) -> set[str] | None:
    """
    Decide qué momentos ("dia"/"noche"/"ambos") son apropiados para el clima
    esperado del evento. Devuelve None si no hay que filtrar por momento
    (clima intermedio y sin señales de lluvia).
    """
    temp_max = clima.get("temp_max")
    precipitacion_mm = clima.get("precipitacion_mm") or 0
    dias_con_lluvia_pct = clima.get("dias_con_lluvia_pct") or 0
    descripcion = (clima.get("descripcion") or "").lower()

    hay_lluvia = (
        precipitacion_mm >= UMBRAL_LLUVIA_MM
        or dias_con_lluvia_pct >= UMBRAL_DIAS_LLUVIA_PCT
        or any(palabra in descripcion for palabra in PALABRAS_LLUVIA)
    )

    if hay_lluvia:
        return {"noche", "ambos"}
    if temp_max is not None and temp_max >= UMBRAL_CALOR_MAX:
        return {"dia", "ambos"}
    if temp_max is not None and temp_max <= UMBRAL_FRIO_MAX:
        return {"noche", "ambos"}
    return None


def filtrar_prendas(prendas: list[dict], clima: dict, limite: int = 40) -> list[dict]:
    """
    Reduce el guardarropa a las prendas más relevantes para el clima, capado a `limite`.

    El clima decide qué momentos ("dia"/"noche"/"ambos") son apropiados (ver
    _momentos_permitidos): lluvia -> noche/ambos; calor sin lluvia -> dia/ambos;
    frío sin lluvia -> noche/ambos; clima intermedio y seco -> no se filtra.
    El resultado se ordena por veces_usado descendente y se capa a `limite`.

    Si el filtro por momento deja menos de 3 prendas, se descarta el filtro
    y se devuelve la lista original ordenada y capada: es preferible
    recomendar con prendas de momento inadecuado que no poder recomendar
    (por ejemplo, un guardarropa pequeño compuesto solo de ropa de noche
    en un evento de clima cálido no debe vaciarse a cero opciones).
    """
    momentos_permitidos = _momentos_permitidos(clima)

    if momentos_permitidos is None:
        filtradas = list(prendas)
    else:
        filtradas = [p for p in prendas if momento_de_prenda(p) in momentos_permitidos]

    if len(filtradas) < 3:
        filtradas = list(prendas)

    filtradas.sort(key=lambda p: p["veces_usado"], reverse=True)
    return filtradas[:limite]


def validar_outfits(contenido_json, n_prendas: int) -> tuple[list[dict], list[dict]]:
    """
    Clasifica los outfits devueltos por el LLM en válidos y descartados.

    No repara outfits parcialmente inválidos (p. ej. quitándoles un índice
    inventado): un outfit al que se le quita una prenda deja de corresponder
    a su justificación, así que se descarta completo. No lanza excepciones;
    solo clasifica — decidir qué hacer con cero outfits válidos es
    responsabilidad del controller.
    """
    outfits_validos: list[dict] = []
    descartados: list[dict] = []

    if not isinstance(contenido_json, dict):
        return outfits_validos, [{"outfit": contenido_json, "motivo": "contenido_json no es un dict"}]

    outfits = contenido_json.get("outfits")
    if not isinstance(outfits, list):
        return outfits_validos, [{"outfit": outfits, "motivo": "'outfits' no es una lista"}]

    claves_esperadas = {"nombre", "prendas", "justificacion"}

    for outfit in outfits:
        if not isinstance(outfit, dict):
            descartados.append({"outfit": outfit, "motivo": "no es un dict"})
            continue

        if set(outfit.keys()) != claves_esperadas:
            descartados.append({"outfit": outfit, "motivo": f"claves inesperadas: {sorted(outfit.keys())}"})
            continue

        prendas = outfit.get("prendas")
        if not isinstance(prendas, list) or len(prendas) == 0:
            descartados.append({"outfit": outfit, "motivo": "'prendas' no es una lista no vacía"})
            continue

        if not all(isinstance(i, int) for i in prendas):
            descartados.append({"outfit": outfit, "motivo": "'prendas' contiene elementos no enteros"})
            continue

        fuera_de_rango = [i for i in prendas if not (0 <= i <= n_prendas - 1)]
        if fuera_de_rango:
            descartados.append({"outfit": outfit, "motivo": f"índices fuera de rango: {fuera_de_rango}"})
            continue

        outfits_validos.append(outfit)

    return outfits_validos, descartados

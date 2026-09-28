# app/models/tipo_prenda.py
"""
Traducción de las 20 clases del modelo YOLO (valor crudo en inglés que se
guarda y se filtra) a una etiqueta en español, para texto que lee un humano
o un LLM. Debe mantenerse sincronizado a mano con
styleme-flutter/lib/config/constants.dart (tipoEtiquetas/etiquetaTipo).
"""

TIPO_ETIQUETAS = {
    "T-shirt": "Camiseta",
    "blazer": "Blazer",
    "blouse": "Blusa",
    "body": "Body",
    "dress": "Vestido",
    "glove": "Guantes",
    "hat": "Sombrero",
    "hoodie": "Buzo",
    "long sleeve": "Manga larga",
    "not sure": "Sin identificar",
    "other": "Otro",
    "outwear": "Abrigo",
    "pants": "Pantalón",
    "polo": "Polo",
    "shirt": "Camisa",
    "shoe": "Calzado",
    "shorts": "Pantaloneta",
    "skirt": "Falda",
    "top": "Top",
    "undershirt": "Camiseta interior",
}


def etiqueta_tipo(tipo) -> str:
    """Etiqueta en español de un tipo; si no se conoce, el valor crudo."""
    if not tipo:
        return TIPO_ETIQUETAS["other"]
    return TIPO_ETIQUETAS.get(tipo, tipo)

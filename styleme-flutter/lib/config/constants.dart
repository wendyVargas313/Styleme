// StyleMe - Constantes globales de la aplicación
import 'dart:ui' show Color;

class AppConstants {
  static const String appName = 'StyleMe';
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  // Momento de una prenda = clima para el que sirve. 'ambos' es un valor
  // interno (prenda versátil): en la UI se marca con los dos chips.
  static const List<String> momentos = ['soleado', 'lluvioso', 'ambos'];
  static const String momentoDefault = 'ambos';
  static const List<String> momentosSeleccionables = ['soleado', 'lluvioso'];

  static const Map<String, String> momentoIconos = {
    'soleado': '☀️',
    'lluvioso': '🌧️',
    'ambos': '☀️🌧️',
  };

  static const Map<String, String> momentoEtiquetas = {
    'soleado': 'Soleado',
    'lluvioso': 'Lluvioso',
    'ambos': 'Soleado y lluvioso',
  };

  static const Map<String, String> _momentosLegado = {
    'dia': 'soleado',
    'noche': 'lluvioso',
  };

  // Valor vigente del momento (acepta el legado dia/noche); null si no se
  // reconoce.
  static String? normalizarMomento(String? momento) {
    if (momentos.contains(momento)) return momento;
    return _momentosLegado[momento];
  }

  // Ícono para un momento; tolerante a null o valores desconocidos.
  static String iconoMomento(String? momento) {
    return momentoIconos[normalizarMomento(momento) ?? momentoDefault]!;
  }

  // Etiqueta legible para un momento; tolerante a null o valores desconocidos.
  static String etiquetaMomento(String? momento) {
    return momentoEtiquetas[normalizarMomento(momento) ?? momentoDefault]!;
  }

  // Opciones de género
  static const List<String> generos = ['masculino', 'femenino', 'otro'];

  // Opciones de feedback
  static const Map<String, String> feedbackIconos = {
    'liked': '❤️',
    'saved': '🔖',
    'disliked': '✕',
    'none': '',
  };

  // Los 13 colores del clasificador (valor interno idéntico al del backend)
  // con un color de muestra para pintar el círculo. Debe mantenerse
  // sincronizado a mano con ClasificadorColor.COLORES en
  // styleme-backend/app/ml/color_classifier.py.
  static const List<(String, Color)> colores = [
    ('negro', Color(0xFF1A1A1A)),
    ('blanco', Color(0xFFF5F5F5)),
    ('gris', Color(0xFF808080)),
    ('rojo', Color(0xFFE53935)),
    ('rosa', Color(0xFFEC407A)),
    ('azul', Color(0xFF1E88E5)),
    ('azul marino', Color(0xFF1A237E)),
    ('verde', Color(0xFF43A047)),
    ('amarillo', Color(0xFFFDD835)),
    ('naranja', Color(0xFFFF6B00)),
    ('morado', Color(0xFF8E24AA)),
    ('beige', Color(0xFFF5DEB3)),
    ('cafe', Color(0xFF795548)),
  ];

  static const Map<String, String> _colorEtiquetas = {'cafe': 'Café'};

  // Muestra del color; null si el valor no es uno de los 13.
  static Color? muestraColor(String? color) {
    for (final (nombre, muestra) in colores) {
      if (nombre == color?.toLowerCase()) return muestra;
    }
    return null;
  }

  // Nombre visible del color ("azul marino" → "Azul marino", "cafe" → "Café").
  static String etiquetaColor(String color) {
    final especial = _colorEtiquetas[color];
    if (especial != null) return especial;
    if (color.isEmpty) return color;
    return color[0].toUpperCase() + color.substring(1);
  }

  // Por debajo de esta confianza de YOLO (y sin corrección del usuario) la
  // prenda se marca para revisión.
  static const double umbralRevision = 0.5;

  // Clases del modelo YOLO (valor que guarda y filtra el backend, en inglés)
  // → etiqueta visible en español.
  static const Map<String, String> tipoEtiquetas = {
    'T-shirt': 'Camiseta',
    'blazer': 'Blazer',
    'blouse': 'Blusa',
    'body': 'Body',
    'dress': 'Vestido',
    'glove': 'Guantes',
    'hat': 'Sombrero',
    'hoodie': 'Buzo',
    'long sleeve': 'Manga larga',
    'not sure': 'Sin identificar',
    'other': 'Otro',
    'outwear': 'Abrigo',
    'pants': 'Pantalón',
    'polo': 'Polo',
    'shirt': 'Camisa',
    'shoe': 'Calzado',
    'shorts': 'Pantaloneta',
    'skirt': 'Falda',
    'top': 'Top',
    'undershirt': 'Camiseta interior',
  };

  // Etiqueta en español de un tipo; si no se conoce, el valor crudo.
  static String etiquetaTipo(String? tipo) {
    if (tipo == null || tipo.isEmpty) return tipoEtiquetas['other']!;
    return tipoEtiquetas[tipo] ?? tipo;
  }

  // Duración de animaciones
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);
}

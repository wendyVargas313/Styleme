// StyleMe - Constantes globales de la aplicación
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

  // Colores del modelo ML
  static const List<String> coloresML = [
    'negro', 'blanco', 'gris', 'rojo', 'rosa', 'azul',
    'azul marino', 'verde', 'amarillo', 'naranja', 'morado',
    'beige', 'cafe',
  ];

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

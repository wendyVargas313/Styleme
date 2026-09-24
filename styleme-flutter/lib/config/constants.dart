// StyleMe - Constantes globales de la aplicación
class AppConstants {
  static const String appName = 'StyleMe';
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  // Momentos disponibles para una prenda: cuándo conviene usarla
  static const List<String> momentos = ['dia', 'noche', 'ambos'];
  static const String momentoDefault = 'ambos';

  static const Map<String, String> momentoIconos = {
    'dia': '☀️',
    'noche': '🌙',
    'ambos': '🔄',
  };

  static const Map<String, String> momentoEtiquetas = {
    'dia': 'Día',
    'noche': 'Noche',
    'ambos': 'Ambos',
  };

  // Ícono para un momento; tolerante a null o valores desconocidos.
  static String iconoMomento(String? momento) {
    return momentoIconos[momento] ?? '🔄';
  }

  // Etiqueta legible para un momento; tolerante a null o valores desconocidos.
  static String etiquetaMomento(String? momento) {
    return momentoEtiquetas[momento] ?? 'Ambos';
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

  // Tipos de prendas del modelo YOLO
  static const List<String> tiposPrendas = [
    'T-shirt', 'blazer', 'blouse', 'body', 'dress', 'glove',
    'hat', 'hoodie', 'long sleeve', 'outwear', 'pants', 'polo',
    'shirt', 'shoe', 'shorts', 'skirt', 'top', 'undershirt',
  ];

  // Duración de animaciones
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);
}

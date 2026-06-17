// StyleMe - Constantes globales de la aplicación
class AppConstants {
  static const String appName = 'StyleMe';
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  // Temporadas disponibles
  static const List<String> temporadas = [
    'primavera',
    'verano',
    'otono',
    'invierno',
  ];

  static const Map<String, String> temporadasIconos = {
    'primavera': '🌸',
    'verano': '☀️',
    'otono': '🍂',
    'invierno': '❄️',
  };

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

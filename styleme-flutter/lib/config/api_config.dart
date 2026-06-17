// StyleMe - Configuración de la API Backend
class ApiConfig {
  // URL base del backend FastAPI
  // Cambiar a la IP del servidor en producción
  // static const String baseUrl = 'http://10.0.2.2:8000'; // Android emulador
  // static const String baseUrl = 'http://localhost:8000'; // Web / iOS simulator
  static const String baseUrl = 'http://192.168.0.8:8000'; // Dispositivo físico

  static const String apiVersion = 'v1';
  static const String apiPrefix = '$baseUrl/api/$apiVersion';

  // Timeouts
  static const int connectTimeout = 30000; // 30 segundos
  static const int receiveTimeout = 60000; // 60 segundos (ML puede tardar)

  // Endpoints de Auth
  static const String registro = '$apiPrefix/auth/registro';
  static const String login = '$apiPrefix/auth/login';
  static const String perfil = '$apiPrefix/auth/perfil';

  // Endpoints de Guardarropa
  static const String agregarPrenda = '$apiPrefix/guardarropa/agregar';
  static const String listarPrendas = '$apiPrefix/guardarropa/listar';
  static const String statsGuardarropa = '$apiPrefix/guardarropa/stats';
  static String eliminarPrenda(String id) => '$apiPrefix/guardarropa/$id';

  // Endpoints de Recomendaciones
  static const String recomendarOutfit = '$apiPrefix/recomendar/outfit';
  static const String outfitDiario = '$apiPrefix/recomendar/diario';

  // Endpoints de Historial
  static const String historial = '$apiPrefix/historial';
  static const String feedback = '$apiPrefix/historial/feedback';
  static String eliminarOutfit(String id) => '$apiPrefix/historial/$id';

  // Endpoints de Invitado
  static const String invitadoProbar = '$apiPrefix/invitado/probar';

  // Health check
  static const String health = '$apiPrefix/health';
}

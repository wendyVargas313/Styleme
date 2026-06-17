// StyleMe - Servicio HTTP con Dio
import 'package:dio/dio.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/services/storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
      headers: {'Content-Type': 'application/json'},
    ));

    // Interceptor para agregar el JWT token automáticamente
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await StorageService().getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        return handler.next(error);
      },
    ));
  }

  // ── GET ───────────────────────────────────────────────
  Future<Response> get(
    String url, {
    Map<String, dynamic>? queryParams,
  }) async {
    return await _dio.get(url, queryParameters: queryParams);
  }

  // ── POST ──────────────────────────────────────────────
  Future<Response> post(
    String url, {
    dynamic data,
  }) async {
    return await _dio.post(url, data: data);
  }

  // ── POST Multipart (para subir imágenes) ──────────────
  Future<Response> postFormData(
    String url,
    FormData formData,
  ) async {
    return await _dio.post(
      url,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  // ── DELETE ────────────────────────────────────────────
  Future<Response> delete(String url) async {
    return await _dio.delete(url);
  }

  // ── Crear FormData para subir imagen ──────────────────
  static FormData crearFormDataImagen({
    required String fieldName,
    required String rutaArchivo,
    required String nombreArchivo,
    Map<String, String>? campos,
  }) {
    final formData = FormData.fromMap({
      fieldName: MultipartFile.fromFileSync(
        rutaArchivo,
        filename: nombreArchivo,
      ),
      ...?campos,
    });
    return formData;
  }
}

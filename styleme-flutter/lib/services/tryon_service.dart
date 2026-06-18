// StyleMe - Servicio de Virtual Try-On
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/services/storage_service.dart';

class TryonService {
  late final Dio _dio;

  TryonService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConfig.tryonTimeout),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await StorageService().getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  // Convierte imágenes a base64 y las envía como JSON
  Future<Map<String, dynamic>> generarTryon({
    required File persona,
    required File prenda,
    required String categoria,
  }) async {
    final personaBytes = await persona.readAsBytes();
    final prendaBytes  = await prenda.readAsBytes();

    final body = {
      'imagen_persona': base64Encode(personaBytes),
      'imagen_prenda':  base64Encode(prendaBytes),
      'categoria':      categoria,
    };

    final response = await _dio.post(ApiConfig.tryon, data: body);
    return response.data as Map<String, dynamic>;
  }
}

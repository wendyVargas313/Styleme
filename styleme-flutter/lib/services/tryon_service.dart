// StyleMe - Servicio de Virtual Try-On
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
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

  // Lee un archivo de imagen, hornea la orientación EXIF en los píxeles
  // y re-codifica a JPG. Si la imagen no se puede decodificar, hace
  // fallback a los bytes originales sin romper el flujo.
  Future<Uint8List> _corregirOrientacion(File archivo) async {
    final bytesOriginales = await archivo.readAsBytes();

    final imagenDecodificada = img.decodeImage(bytesOriginales);
    if (imagenDecodificada == null) {
      developer.log(
        'No se pudo decodificar la imagen (${archivo.path}); '
        'se usan los bytes originales sin corregir orientación EXIF.',
        name: 'TryonService',
        level: 900,
      );
      return bytesOriginales;
    }

    final imagenOrientada = img.bakeOrientation(imagenDecodificada);
    return Uint8List.fromList(img.encodeJpg(imagenOrientada, quality: 90));
  }

  // Convierte imágenes a base64 y las envía como JSON
  Future<Map<String, dynamic>> generarTryon({
    required File persona,
    required File prenda,
    required String categoria,
  }) async {
    final personaBytes = await _corregirOrientacion(persona);
    final prendaBytes  = await _corregirOrientacion(prenda);

    final body = {
      'imagen_persona': base64Encode(personaBytes),
      'imagen_prenda':  base64Encode(prendaBytes),
      'categoria':      categoria,
    };

    final response = await _dio.post(ApiConfig.tryon, data: body);
    return response.data as Map<String, dynamic>;
  }
}

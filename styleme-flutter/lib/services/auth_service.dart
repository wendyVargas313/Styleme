// StyleMe - Servicio de Autenticación
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/models/user_model.dart';
import 'package:styleme/services/api_service.dart';
import 'package:styleme/services/storage_service.dart';

class AuthService {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  Future<Map<String, dynamic>> registro({
    required String nombre,
    required String email,
    required String password,
    required String genero,
  }) async {
    final response = await _api.post(ApiConfig.registro, data: {
      'nombre': nombre,
      'email': email,
      'password': password,
      'genero': genero,
    });

    final data = response.data as Map<String, dynamic>;
    if (data['success'] == true) {
      await _storage.guardarToken(data['token']);
      await _storage.guardarUsuario(UserModel.fromJson(data['usuario']));
    }
    return data;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post(ApiConfig.login, data: {
      'email': email,
      'password': password,
    });

    final data = response.data as Map<String, dynamic>;
    if (data['success'] == true) {
      await _storage.guardarToken(data['token']);
      await _storage.guardarUsuario(UserModel.fromJson(data['usuario']));
    }
    return data;
  }

  Future<UserModel?> obtenerPerfil() async {
    final response = await _api.get(ApiConfig.perfil);
    final data = response.data as Map<String, dynamic>;
    final usuario = UserModel.fromJson(data);
    await _storage.guardarUsuario(usuario);
    return usuario;
  }

  Future<void> cerrarSesion() async {
    await _storage.cerrarSesion();
  }

  // Sube la foto de perfil como multipart y retorna la URL guardada
  Future<String> subirFotoPerfil(File foto) async {
    final formData = FormData.fromMap({
      'foto': await MultipartFile.fromFile(
        foto.path,
        filename: 'perfil.jpg',
      ),
    });
    final response = await _api.postFormData(ApiConfig.fotoPerfil, formData);
    final data = response.data as Map<String, dynamic>;
    return data['foto_perfil_url'] as String;
  }

  // Sube el avatar como multipart y retorna la URL guardada
  Future<String> subirAvatar(File foto) async {
    final formData = FormData.fromMap({
      'foto': await MultipartFile.fromFile(
        foto.path,
        filename: 'avatar.jpg',
      ),
    });
    final response = await _api.postFormData(ApiConfig.fotoAvatar, formData);
    final data = response.data as Map<String, dynamic>;
    return data['foto_avatar_url'] as String;
  }
}

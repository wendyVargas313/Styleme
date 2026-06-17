// StyleMe - Servicio de almacenamiento local
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:styleme/config/constants.dart';
import 'package:styleme/models/user_model.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // ── Token JWT ─────────────────────────────────────────
  Future<void> guardarToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  Future<void> eliminarToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
  }

  // ── Usuario ───────────────────────────────────────────
  Future<void> guardarUsuario(UserModel usuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, jsonEncode(usuario.toJson()));
  }

  Future<UserModel?> getUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(AppConstants.userKey);
    if (json == null) return null;
    return UserModel.fromJson(jsonDecode(json));
  }

  Future<void> eliminarUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userKey);
  }

  // ── Sesión completa ───────────────────────────────────
  Future<bool> haySesionActiva() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> cerrarSesion() async {
    await eliminarToken();
    await eliminarUsuario();
  }
}

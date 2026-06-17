// StyleMe - Controller de Autenticación (Provider)
import 'package:flutter/foundation.dart';
import 'package:styleme/models/user_model.dart';
import 'package:styleme/services/auth_service.dart';
import 'package:styleme/services/storage_service.dart';

enum AuthEstado { inicial, cargando, autenticado, noAutenticado, error }

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final StorageService _storage = StorageService();

  AuthEstado _estado = AuthEstado.inicial;
  UserModel? _usuario;
  String? _mensajeError;

  AuthEstado get estado => _estado;
  UserModel? get usuario => _usuario;
  String? get mensajeError => _mensajeError;
  bool get estaAutenticado => _estado == AuthEstado.autenticado;

  // Verifica si hay sesión guardada al iniciar la app
  Future<void> verificarSesion() async {
    _estado = AuthEstado.cargando;
    notifyListeners();

    try {
      final haySession = await _storage.haySesionActiva();
      if (haySession) {
        _usuario = await _storage.getUsuario();
        _estado = AuthEstado.autenticado;
      } else {
        _estado = AuthEstado.noAutenticado;
      }
    } catch (_) {
      _estado = AuthEstado.noAutenticado;
    }
    notifyListeners();
  }

  // Registro de nuevo usuario
  Future<bool> registro({
    required String nombre,
    required String email,
    required String password,
    required String genero,
  }) async {
    _estado = AuthEstado.cargando;
    _mensajeError = null;
    notifyListeners();

    try {
      final respuesta = await _authService.registro(
        nombre: nombre,
        email: email,
        password: password,
        genero: genero,
      );
      _usuario = UserModel.fromJson(respuesta['usuario']);
      _estado = AuthEstado.autenticado;
      notifyListeners();
      return true;
    } catch (e) {
      _mensajeError = _parsearError(e);
      _estado = AuthEstado.error;
      notifyListeners();
      return false;
    }
  }

  // Inicio de sesión
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _estado = AuthEstado.cargando;
    _mensajeError = null;
    notifyListeners();

    try {
      final respuesta = await _authService.login(email: email, password: password);
      _usuario = UserModel.fromJson(respuesta['usuario']);
      _estado = AuthEstado.autenticado;
      notifyListeners();
      return true;
    } catch (e) {
      _mensajeError = _parsearError(e);
      _estado = AuthEstado.error;
      notifyListeners();
      return false;
    }
  }

  // Refrescar perfil del usuario
  Future<void> refrescarPerfil() async {
    try {
      _usuario = await _authService.obtenerPerfil();
      notifyListeners();
    } catch (_) {}
  }

  // Cerrar sesión
  Future<void> cerrarSesion() async {
    await _authService.cerrarSesion();
    _usuario = null;
    _estado = AuthEstado.noAutenticado;
    notifyListeners();
  }

  // Parsea el error de Dio a mensaje legible
  String _parsearError(dynamic e) {
    if (e.toString().contains('409')) return 'El email ya está registrado';
    if (e.toString().contains('401')) return 'Credenciales incorrectas';
    if (e.toString().contains('SocketException') ||
        e.toString().contains('Connection refused')) {
      return 'No se puede conectar al servidor. Verifica tu conexión.';
    }
    return 'Ocurrió un error. Intenta de nuevo.';
  }
}

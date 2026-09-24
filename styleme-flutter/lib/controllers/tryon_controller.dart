// StyleMe - Controller de Virtual Try-On (Provider)
import 'dart:developer' as developer;
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/services/api_service.dart';
import 'package:styleme/services/auth_service.dart';
import 'package:styleme/services/tryon_service.dart';

enum TryonEstado { inicial, procesando, listo, error }

class TryonController extends ChangeNotifier {
  final TryonService _service = TryonService();
  final AuthService _authService = AuthService();
  final ApiService _api = ApiService();

  TryonEstado _estado = TryonEstado.inicial;
  File? _imagenPersona;
  File? _imagenPrenda;
  String _categoria = 'upper';
  String? _imagenResultadoBase64;
  double? _tiempoInferencia;
  String? _mensajeError;

  bool _cargandoFotoGuardada = false;
  bool _usandoFotoGuardada = false;
  bool _fotoElegidaManualmente = false;
  bool _destruido = false;

  @override
  void dispose() {
    _destruido = true;
    super.dispose();
  }

  // Evita notificar (y el crash de ChangeNotifier) si el controller ya fue
  // destruido mientras un await de cargarFotoGuardada/generarTryon seguía
  // en curso (ej. el usuario salió de la pantalla de try-on).
  @override
  void notifyListeners() {
    if (_destruido) return;
    super.notifyListeners();
  }

  TryonEstado get estado => _estado;
  File? get imagenPersona => _imagenPersona;
  File? get imagenPrenda => _imagenPrenda;
  String get categoria => _categoria;
  String? get imagenResultadoBase64 => _imagenResultadoBase64;
  double? get tiempoInferencia => _tiempoInferencia;
  String? get mensajeError => _mensajeError;
  bool get listo => _imagenPersona != null && _imagenPrenda != null;
  bool get cargandoFotoGuardada => _cargandoFotoGuardada;
  bool get usandoFotoGuardada => _usandoFotoGuardada;

  void setImagenPersona(File imagen) {
    _fotoElegidaManualmente = true;
    _usandoFotoGuardada = false;
    _imagenPersona = imagen;
    _imagenResultadoBase64 = null;
    notifyListeners();
  }

  void setImagenPrenda(File imagen) {
    _imagenPrenda = imagen;
    _imagenResultadoBase64 = null;
    notifyListeners();
  }

  void setCategoria(String cat) {
    _categoria = cat;
    notifyListeners();
  }

  // Precarga "Mi foto para Try-On" (foto_perfil_url) si el usuario ya tiene
  // una guardada. Nunca muestra error: cualquier fallo solo queda en el log.
  Future<void> cargarFotoGuardada() async {
    if (_imagenPersona != null || _fotoElegidaManualmente) return;

    _cargandoFotoGuardada = true;
    notifyListeners();

    try {
      final fotoUrl = await _authService.obtenerFotoPerfilUrl();
      if (fotoUrl == null || fotoUrl.isEmpty) {
        developer.log('Sin foto de perfil guardada', name: '[Tryon]');
        return;
      }

      final urlCompleta =
          '${ApiConfig.baseUrl}$fotoUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      final response = await _api.getBytes(urlCompleta);
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        developer.log('Respuesta vacía al descargar la foto guardada', name: '[Tryon]');
        return;
      }

      // El usuario pudo haber elegido una foto manualmente mientras
      // descargábamos: no sobrescribir esa elección.
      if (_fotoElegidaManualmente) {
        developer.log(
          'El usuario ya eligió una foto manualmente, se descarta la guardada',
          name: '[Tryon]',
        );
        return;
      }

      final tempFile = File(
        '${Directory.systemTemp.path}/styleme_tryon_persona_'
        '${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(bytes);

      // Segundo chequeo: la elección manual pudo llegar durante la escritura.
      if (_fotoElegidaManualmente) {
        developer.log(
          'El usuario eligió una foto manualmente durante la descarga, se descarta la guardada',
          name: '[Tryon]',
        );
        return;
      }

      _imagenPersona = tempFile;
      _usandoFotoGuardada = true;
    } catch (e) {
      developer.log('No se pudo precargar la foto guardada: $e', name: '[Tryon]');
    } finally {
      _cargandoFotoGuardada = false;
      notifyListeners();
    }
  }

  Future<bool> generarTryon() async {
    if (_imagenPersona == null || _imagenPrenda == null) return false;

    _estado = TryonEstado.procesando;
    _mensajeError = null;
    _imagenResultadoBase64 = null;
    notifyListeners();

    try {
      final resultado = await _service.generarTryon(
        persona: _imagenPersona!,
        prenda: _imagenPrenda!,
        categoria: _categoria,
      );

      _imagenResultadoBase64 = resultado['imagen_resultado'] as String?;
      _tiempoInferencia = (resultado['tiempo_inferencia_catvton'] as num?)?.toDouble();
      _estado = TryonEstado.listo;
      notifyListeners();
      return true;
    } catch (e) {
      _mensajeError = _parsearError(e);
      _estado = TryonEstado.error;
      notifyListeners();
      return false;
    }
  }

  void reiniciar() {
    _estado = TryonEstado.inicial;
    _imagenPersona = null;
    _imagenPrenda = null;
    _imagenResultadoBase64 = null;
    _mensajeError = null;
    _tiempoInferencia = null;
    _categoria = 'upper';
    _usandoFotoGuardada = false;
    _fotoElegidaManualmente = false;
    notifyListeners();
  }

  String _parsearError(dynamic e) {
    if (e is! DioException) {
      developer.log('Error no-Dio en try-on: $e', name: '[Tryon]');
      return 'Error generando el try-on. Intenta de nuevo';
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        developer.log('Timeout de try-on (${e.type})', name: '[Tryon]');
        return 'Tiempo de espera agotado. El servidor tardó demasiado';
      case DioExceptionType.connectionError:
        developer.log('Error de conexión en try-on: ${e.message}', name: '[Tryon]');
        return 'No se puede conectar al servidor. Verifica tu conexión';
      default:
        break;
    }

    final response = e.response;
    if (response == null) {
      developer.log('DioException sin respuesta en try-on: ${e.type} ${e.message}', name: '[Tryon]');
      return 'Error generando el try-on. Intenta de nuevo';
    }

    final codigo = response.statusCode;
    final detail = _extraerDetail(response.data);

    developer.log('Error try-on: codigo=$codigo detail=$detail', name: '[Tryon]');

    switch (codigo) {
      case 400:
        return detail ?? 'Categoría o imágenes inválidas';
      case 401:
        return 'Sesión expirada. Vuelve a iniciar sesión';
      case 422:
        return 'Datos inválidos: ${detail ?? "verifica los campos"}';
      case 502:
      case 503:
        return 'El servicio de try-on no está disponible en este momento (servidor de IA apagado)';
      default:
        return 'Error generando el try-on ($codigo). Intenta de nuevo';
    }
  }

  // Extrae el campo 'detail' de la respuesta de error del backend.
  // Puede ser un String (HTTPException propia) o una lista de objetos de
  // validación de Pydantic/FastAPI (422), de la que se toma el 'msg' del
  // primer elemento.
  String? _extraerDetail(dynamic data) {
    if (data is! Map) return null;
    final detail = data['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      final primero = detail.first;
      if (primero is Map && primero['msg'] != null) {
        return primero['msg'].toString();
      }
    }
    return null;
  }
}

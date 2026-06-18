// StyleMe - Controller de Virtual Try-On (Provider)
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:styleme/services/tryon_service.dart';

enum TryonEstado { inicial, procesando, listo, error }

class TryonController extends ChangeNotifier {
  final TryonService _service = TryonService();

  TryonEstado _estado = TryonEstado.inicial;
  File? _imagenPersona;
  File? _imagenPrenda;
  String _categoria = 'upper';
  String? _imagenResultadoBase64;
  double? _tiempoInferencia;
  String? _mensajeError;

  TryonEstado get estado => _estado;
  File? get imagenPersona => _imagenPersona;
  File? get imagenPrenda => _imagenPrenda;
  String get categoria => _categoria;
  String? get imagenResultadoBase64 => _imagenResultadoBase64;
  double? get tiempoInferencia => _tiempoInferencia;
  String? get mensajeError => _mensajeError;
  bool get listo => _imagenPersona != null && _imagenPrenda != null;

  void setImagenPersona(File imagen) {
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
    notifyListeners();
  }

  String _parsearError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('502') || msg.contains('SocketException')) {
      return 'El microservicio CatVTON no está disponible';
    }
    if (msg.contains('400')) return 'Categoría o imágenes inválidas';
    if (msg.contains('401')) return 'Sesión expirada. Vuelve a iniciar sesión';
    if (msg.contains('TimeoutException') || msg.contains('timeout')) {
      return 'Tiempo de espera agotado. El servidor tardó demasiado';
    }
    return 'Error generando el try-on. Intenta de nuevo';
  }
}

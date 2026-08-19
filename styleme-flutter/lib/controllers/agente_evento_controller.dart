// StyleMe - Controller del Agente de Recomendación para Eventos (Provider)
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/models/recomendacion_evento_model.dart';
import 'package:styleme/services/api_service.dart';

enum AgenteEventoEstado { inicial, cargando, listo, error }
enum HistorialEstado { inicial, cargando, listo, error }

class AgenteEventoController extends ChangeNotifier {
  final ApiService _api = ApiService();

  AgenteEventoEstado _estado = AgenteEventoEstado.inicial;
  RecomendacionEvento? _recomendacion;
  String? _mensajeError;

  AgenteEventoEstado get estado => _estado;
  RecomendacionEvento? get recomendacion => _recomendacion;
  String? get mensajeError => _mensajeError;

  // ── Estado del historial (independiente del estado de arriba) ──
  HistorialEstado _estadoHistorial = HistorialEstado.inicial;
  List<RecomendacionResumen> _historial = [];
  int _totalHistorial = 0;
  int _paginaActual = 1;
  String? _mensajeErrorHistorial;
  String? _mensajeErrorDetalle;

  HistorialEstado get estadoHistorial => _estadoHistorial;
  List<RecomendacionResumen> get historial => _historial;
  int get totalHistorial => _totalHistorial;
  int get paginaActual => _paginaActual;
  String? get mensajeErrorHistorial => _mensajeErrorHistorial;
  String? get mensajeErrorDetalle => _mensajeErrorDetalle;

  // ── Acciones puntuales sobre un outfit (guardar/eliminar) ──
  // No usan _estado ni _estadoHistorial: son acciones sobre un solo item,
  // la vista maneja su propio indicador local (igual que cargarDetalle).
  String? _mensajeErrorAccion;
  String? get mensajeErrorAccion => _mensajeErrorAccion;

  // Genera la recomendación de outfits para un evento
  Future<bool> recomendarParaEvento({
    required String descripcionEvento,
    required String lugar,
    required String fecha,
  }) async {
    _estado = AgenteEventoEstado.cargando;
    _mensajeError = null;
    notifyListeners();

    try {
      final response = await _api.post(ApiConfig.agenteRecomendarEvento, data: {
        'descripcion_evento': descripcionEvento,
        'lugar': lugar,
        'fecha': fecha,
      });

      final data = response.data as Map<String, dynamic>;
      _recomendacion = RecomendacionEvento.fromJson(data);
      _estado = AgenteEventoEstado.listo;
      notifyListeners();
      return true;
    } catch (e) {
      _mensajeError = _parsearError(e);
      _estado = AgenteEventoEstado.error;
      notifyListeners();
    }
    return false;
  }

  // Limpia la recomendación y vuelve al estado inicial
  void limpiar() {
    _recomendacion = null;
    _mensajeError = null;
    _estado = AgenteEventoEstado.inicial;
    notifyListeners();
  }

  // Carga el historial paginado de recomendaciones (reemplaza la lista actual)
  Future<void> cargarHistorial({int page = 1, int limit = 20}) async {
    _estadoHistorial = HistorialEstado.cargando;
    _mensajeErrorHistorial = null;
    notifyListeners();

    try {
      final response = await _api.get(
        ApiConfig.agenteRecomendaciones,
        queryParams: {'page': page, 'limit': limit},
      );

      final data = response.data as Map<String, dynamic>;
      final lista = ListaRecomendaciones.fromJson(data);
      _historial = lista.recomendaciones;
      _totalHistorial = lista.total;
      _paginaActual = lista.page;
      _estadoHistorial = HistorialEstado.listo;
    } catch (e) {
      _mensajeErrorHistorial = _parsearErrorHistorial(e);
      _estadoHistorial = HistorialEstado.error;
    }
    notifyListeners();
  }

  // Carga el detalle de una recomendación puntual del historial.
  // No usa _estado ni _estadoHistorial: la vista maneja su propio loading (FutureBuilder).
  Future<RecomendacionEvento?> cargarDetalle(String id) async {
    _mensajeErrorDetalle = null;
    try {
      final response = await _api.get(ApiConfig.agenteRecomendacionDetalle(id));
      final data = response.data as Map<String, dynamic>;
      return RecomendacionEvento.fromJson(data);
    } catch (e) {
      _mensajeErrorDetalle = _parsearErrorHistorial(e);
      return null;
    }
  }

  // Alterna el "me gusta" de un outfit de la recomendación (guarda/quita copia en el historial).
  Future<bool> alternarGuardadoOutfit(String recomendacionId, int indice) async {
    _mensajeErrorAccion = null;
    try {
      final response = await _api.post(ApiConfig.agenteGuardarOutfit(recomendacionId, indice));
      final data = response.data as Map<String, dynamic>;
      final outfitGuardadoId = data['outfit_guardado_id'] as String?;

      final rec = _recomendacion;
      if (rec != null && indice >= 0 && indice < rec.outfits.length) {
        rec.outfits[indice] = rec.outfits[indice].copyWith(outfitGuardadoId: outfitGuardadoId);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _mensajeErrorAccion = _parsearErrorHistorial(e);
      notifyListeners();
      return false;
    }
  }

  // Elimina un outfit del array de la recomendación (no toca su copia en el historial).
  Future<bool> eliminarOutfitRecomendacion(String recomendacionId, int indice) async {
    _mensajeErrorAccion = null;
    try {
      await _api.delete(ApiConfig.agenteEliminarOutfit(recomendacionId, indice));

      final rec = _recomendacion;
      if (rec != null && indice >= 0 && indice < rec.outfits.length) {
        rec.outfits.removeAt(indice);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _mensajeErrorAccion = _parsearErrorHistorial(e);
      notifyListeners();
      return false;
    }
  }

  // Extrae `detail` del body de error de forma defensiva: solo lo usa si
  // es un string legible; si el body no es un Map, o `detail` no viene o
  // no es string, retorna null para que el caller caiga a su mensaje genérico.
  String? _detalleLegible(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail;
    }
    return null;
  }

  String _parsearErrorHistorial(dynamic e) {
    if (e is DioException) {
      final statusCode = e.response?.statusCode;

      if (statusCode == 404) return 'No se encontró la recomendación';
      if (statusCode == 400) return 'Identificador inválido';

      final detalle = _detalleLegible(e);
      if (detalle != null) return detalle;
    }
    return 'Error consultando el historial de recomendaciones';
  }

  String _parsearError(dynamic e) {
    if (e is DioException) {
      final statusCode = e.response?.statusCode;

      if (statusCode == 400) {
        final detail = e.response?.data?['detail'];
        if (detail != null) return detail.toString();
        return 'No se pudo generar la recomendación';
      }
      if (statusCode == 404) {
        return _detalleLegible(e) ?? 'No se encontró el lugar indicado';
      }
      if (statusCode == 429) {
        return 'Se alcanzó el límite de peticiones al servicio de IA. Intenta de nuevo en unos minutos.';
      }
      if (statusCode == 502) {
        return 'El servicio de IA devolvió una respuesta inválida. Intenta de nuevo.';
      }
      if (statusCode == 503) {
        return 'No se pudo conectar con el servicio de IA. Intenta más tarde.';
      }
      if (statusCode == 504) {
        return 'El servicio de IA tardó demasiado en responder. Intenta de nuevo.';
      }

      final detalle = _detalleLegible(e);
      if (detalle != null) return detalle;
    }
    return 'Error generando la recomendación del evento';
  }
}

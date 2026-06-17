// StyleMe - Controller del Historial (Provider)
import 'package:flutter/foundation.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/models/outfit_model.dart';
import 'package:styleme/services/api_service.dart';

enum HistorialEstado { inicial, cargando, listo, error }

class HistorialController extends ChangeNotifier {
  final ApiService _api = ApiService();

  HistorialEstado _estado = HistorialEstado.inicial;
  List<OutfitModel> _outfits = [];
  String _filtroActivo = 'all';
  int _total = 0;
  String? _mensajeError;

  HistorialEstado get estado => _estado;
  List<OutfitModel> get outfits => _outfits;
  String get filtroActivo => _filtroActivo;
  int get total => _total;
  String? get mensajeError => _mensajeError;

  // Carga el historial de outfits
  Future<void> cargarHistorial({String filtro = 'all', bool resetear = false}) async {
    if (resetear) _outfits = [];
    _filtroActivo = filtro;
    _estado = HistorialEstado.cargando;
    _mensajeError = null;
    notifyListeners();

    try {
      final response = await _api.get(
        ApiConfig.historial,
        queryParams: {'filtro': filtro, 'page': 1, 'limit': 50},
      );

      final data = response.data as Map<String, dynamic>;
      final outfitsJson = data['outfits'] as List? ?? [];

      _outfits = outfitsJson
          .map((o) => OutfitModel.fromJson(o as Map<String, dynamic>))
          .toList();
      _total = data['total'] ?? 0;
      _estado = HistorialEstado.listo;
    } catch (e) {
      _mensajeError = 'Error cargando historial';
      _estado = HistorialEstado.error;
    }
    notifyListeners();
  }

  // Registra feedback en un outfit
  Future<bool> darFeedback(String outfitId, String feedback) async {
    try {
      await _api.post(ApiConfig.feedback, data: {
        'outfit_id': outfitId,
        'feedback': feedback,
      });

      // Actualizar localmente
      final idx = _outfits.indexWhere((o) => o.id == outfitId);
      if (idx != -1) {
        _outfits[idx] = OutfitModel(
          id: _outfits[idx].id,
          prendaBase: _outfits[idx].prendaBase,
          complementos: _outfits[idx].complementos,
          feedback: feedback,
          temporada: _outfits[idx].temporada,
          tipoGeneracion: _outfits[idx].tipoGeneracion,
          generadoEn: _outfits[idx].generadoEn,
        );
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // Elimina un outfit del historial
  Future<bool> eliminarOutfit(String outfitId) async {
    try {
      await _api.delete(ApiConfig.eliminarOutfit(outfitId));
      _outfits.removeWhere((o) => o.id == outfitId);
      _total = (_total - 1).clamp(0, 9999);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}

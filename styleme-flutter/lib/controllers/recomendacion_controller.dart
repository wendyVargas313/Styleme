// StyleMe - Controller de Recomendaciones (Provider)
import 'package:flutter/foundation.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/models/outfit_model.dart';
import 'package:styleme/models/prenda_model.dart';
import 'package:styleme/services/api_service.dart';

enum RecomendacionEstado { inicial, cargando, listo, error }

class RecomendacionController extends ChangeNotifier {
  final ApiService _api = ApiService();

  RecomendacionEstado _estado = RecomendacionEstado.inicial;
  OutfitModel? _outfitActual;
  List<OutfitModel> _outfitsDelDia = [];
  String? _mensajeError;

  RecomendacionEstado get estado => _estado;
  OutfitModel? get outfitActual => _outfitActual;
  List<OutfitModel> get outfitsDelDia => _outfitsDelDia;
  String? get mensajeError => _mensajeError;
  bool get estaCargando => _estado == RecomendacionEstado.cargando;

  // Genera outfit basado en una prenda seleccionada
  Future<OutfitModel?> generarOutfit({
    required String prendaId,
    required String temporada,
    int topK = 3,
  }) async {
    _estado = RecomendacionEstado.cargando;
    _outfitActual = null;
    _mensajeError = null;
    notifyListeners();

    try {
      final response = await _api.post(ApiConfig.recomendarOutfit, data: {
        'prenda_id': prendaId,
        'temporada': temporada,
        'top_k': topK,
      });

      final data = response.data as Map<String, dynamic>;

      if (data['success'] == true) {
        // Construir el OutfitModel desde la respuesta
        _outfitActual = OutfitModel(
          id: data['outfit_id'] ?? '',
          prendaBase: data['prenda_base'] != null
              ? PrendaModel.fromJson(data['prenda_base'])
              : null,
          complementos: (data['recomendaciones'] as List? ?? [])
              .map((r) => ComplementoOutfit.fromJson(r as Map<String, dynamic>))
              .toList(),
          temporada: temporada,
          tipoGeneracion: 'manual',
          generadoEn: data['generado_en'] ?? '',
        );
        _estado = RecomendacionEstado.listo;
        notifyListeners();
        return _outfitActual;
      }
    } catch (e) {
      _mensajeError = _parsearError(e);
      _estado = RecomendacionEstado.error;
      notifyListeners();
    }
    return null;
  }

  // Carga los outfits del día
  Future<void> cargarOutfitsDiarios({String temporada = 'invierno'}) async {
    _estado = RecomendacionEstado.cargando;
    _mensajeError = null;
    notifyListeners();

    try {
      final response = await _api.get(
        ApiConfig.outfitDiario,
        queryParams: {'temporada': temporada},
      );

      final data = response.data as Map<String, dynamic>;
      final outfitsJson = data['outfits_del_dia'] as List? ?? [];

      _outfitsDelDia = outfitsJson.map((o) {
        final oMap = o as Map<String, dynamic>;
        return OutfitModel(
          id: oMap['outfit_id'] ?? '',
          prendaBase: oMap['prenda_base'] != null
              ? PrendaModel.fromJson(oMap['prenda_base'])
              : null,
          complementos: (oMap['complementos'] as List? ?? [])
              .map((c) => ComplementoOutfit.fromJson(c as Map<String, dynamic>))
              .toList(),
          temporada: data['temporada'] ?? temporada,
          tipoGeneracion: 'diario',
          generadoEn: data['fecha'] ?? '',
        );
      }).toList();

      _estado = RecomendacionEstado.listo;
    } catch (e) {
      _mensajeError = _parsearError(e);
      _estado = RecomendacionEstado.error;
    }
    notifyListeners();
  }

  void limpiarOutfit() {
    _outfitActual = null;
    _estado = RecomendacionEstado.inicial;
    notifyListeners();
  }

  String _parsearError(dynamic e) {
    if (e.toString().contains('400')) {
      return 'Necesitas más prendas en tu guardarropa para generar outfits';
    }
    if (e.toString().contains('404')) return 'Prenda no encontrada';
    return 'Error generando el outfit. Intenta de nuevo.';
  }
}

// StyleMe - Controller de Recomendaciones (Provider)
import 'package:flutter/foundation.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/controllers/mixins/recarga_inteligente.dart';
import 'package:styleme/models/outfit_ia_model.dart';
import 'package:styleme/models/outfit_model.dart';
import 'package:styleme/models/prenda_model.dart';
import 'package:styleme/services/api_service.dart';

enum RecomendacionEstado { inicial, cargando, listo, error }

class RecomendacionController extends ChangeNotifier with RecargaInteligente {
  final ApiService _api = ApiService();

  // ── Estado outfits diarios ──────────────────────────────────
  // El mixin RecargaInteligente (haceFaltaRecargar/registrarCarga...) solo
  // se usa para los outfits diarios de esta sección. Los outfits IA de más
  // abajo NUNCA lo tocan — se manejan solo con _generandoIA.
  RecomendacionEstado _estado = RecomendacionEstado.inicial;
  OutfitModel? _outfitActual;
  List<OutfitModel> _outfitsDelDia = [];
  String? _mensajeError;
  bool _ultimoRefrescoFallo = false;

  // ── Estado outfits IA ───────────────────────────────────────
  List<OutfitIAModel> _outfitsIA = [];
  bool _generandoIA = false;
  bool _sinFotoPerfil = false;
  String? _errorIA;

  RecomendacionEstado get estado => _estado;
  OutfitModel? get outfitActual => _outfitActual;
  List<OutfitModel> get outfitsDelDia => _outfitsDelDia;
  String? get mensajeError => _mensajeError;
  bool get estaCargando => _estado == RecomendacionEstado.cargando;
  bool get ultimoRefrescoFallo => _ultimoRefrescoFallo;

  // Recarga los outfits diarios solo si hace falta. NUNCA toca los
  // outfits IA (esos se disparan aparte, deliberadamente). Si ya hay una
  // carga en curso (diaria o de generarOutfit, comparten _estado), no
  // dispara otra.
  Future<void> refrescarSiHaceFalta() async {
    if (_estado == RecomendacionEstado.cargando) return;
    if (haceFaltaRecargar) await cargarOutfitsDiarios();
  }

  // Getters IA
  List<OutfitIAModel> get outfitsIA => _outfitsIA;
  bool get generandoIA => _generandoIA;
  bool get sinFotoPerfil => _sinFotoPerfil;
  String? get errorIA => _errorIA;

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
        return _outfitActual;
      } else {
        // La respuesta llegó 200 pero sin success == true: antes esto
        // dejaba _estado atascado en "cargando" para siempre.
        _mensajeError = 'No se pudo generar el outfit. Intenta de nuevo.';
        _estado = RecomendacionEstado.error;
        return null;
      }
    } catch (e) {
      _mensajeError = _parsearError(e);
      _estado = RecomendacionEstado.error;
      return null;
    } finally {
      notifyListeners();
    }
  }

  // Carga los outfits del día
  Future<void> cargarOutfitsDiarios({String temporada = 'invierno'}) async {
    final huboDatosPrevios = _outfitsDelDia.isNotEmpty;
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

      // Solo se reemplaza la lista si la respuesta fue exitosa.
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
      _ultimoRefrescoFallo = false;
      registrarCargaExitosa();
    } catch (e) {
      registrarCargaFallida();
      _mensajeError = _parsearError(e);
      if (huboDatosPrevios) {
        _estado = RecomendacionEstado.listo;
        _ultimoRefrescoFallo = true;
      } else {
        _estado = RecomendacionEstado.error;
        _ultimoRefrescoFallo = false;
      }
    }
    notifyListeners();
  }

  // Genera outfits del día con imagen IA via CatVTON
  Future<void> cargarOutfitsIA({String temporada = 'invierno'}) async {
    if (_generandoIA) return; // Evitar llamadas duplicadas
    _generandoIA = true;
    _sinFotoPerfil = false;
    _errorIA = null;
    notifyListeners();

    try {
      final response = await _api.post(
        ApiConfig.outfitsIA,
        data: {'temporada': temporada},
      );
      final data = response.data as Map<String, dynamic>;
      _outfitsIA = (data['outfits_ia'] as List? ?? [])
          .map((o) => OutfitIAModel.fromJson(o as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('400') && msg.contains('foto de perfil')) {
        _sinFotoPerfil = true;
      } else {
        _errorIA = 'No se pudieron generar outfits con IA';
      }
    } finally {
      _generandoIA = false;
      notifyListeners();
    }
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

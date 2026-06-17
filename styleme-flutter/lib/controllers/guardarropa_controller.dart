// StyleMe - Controller del Guardarropa (Provider)
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/models/prenda_model.dart';
import 'package:styleme/services/api_service.dart';

enum GuardarropaEstado { inicial, cargando, listo, agregando, error }

class GuardarropaController extends ChangeNotifier {
  final ApiService _api = ApiService();

  GuardarropaEstado _estado = GuardarropaEstado.inicial;
  List<PrendaModel> _prendas = [];
  Map<String, dynamic> _stats = {};
  String? _mensajeError;
  int _totalPrendas = 0;
  int _paginaActual = 1;

  // Filtros activos
  String? _filtroTipo;
  String? _filtroColor;
  String? _filtroTemporada;

  GuardarropaEstado get estado => _estado;
  List<PrendaModel> get prendas => _prendas;
  Map<String, dynamic> get stats => _stats;
  String? get mensajeError => _mensajeError;
  int get totalPrendas => _totalPrendas;
  String? get filtroTipo => _filtroTipo;
  String? get filtroColor => _filtroColor;
  String? get filtroTemporada => _filtroTemporada;

  // Cargar prendas del guardarropa
  Future<void> cargarPrendas({bool resetear = false}) async {
    if (resetear) {
      _paginaActual = 1;
      _prendas = [];
    }

    _estado = GuardarropaEstado.cargando;
    _mensajeError = null;
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{
        'page': _paginaActual,
        'limit': 20,
      };
      if (_filtroTipo != null) queryParams['tipo'] = _filtroTipo;
      if (_filtroColor != null) queryParams['color'] = _filtroColor;
      if (_filtroTemporada != null) queryParams['temporada'] = _filtroTemporada;

      final response = await _api.get(
        ApiConfig.listarPrendas,
        queryParams: queryParams,
      );

      final data = response.data as Map<String, dynamic>;
      final prendasJson = data['prendas'] as List? ?? [];
      _prendas = prendasJson.map((p) => PrendaModel.fromJson(p)).toList();
      _totalPrendas = data['total'] ?? 0;
      _estado = GuardarropaEstado.listo;
    } catch (e) {
      _mensajeError = 'Error cargando prendas';
      _estado = GuardarropaEstado.error;
    }
    notifyListeners();
  }

  // Agregar prenda con imagen
  Future<PrendaModel?> agregarPrenda({
    required File imagen,
    required String temporada,
    String notas = '',
  }) async {
    _estado = GuardarropaEstado.agregando;
    _mensajeError = null;
    notifyListeners();

    try {
      final formData = FormData.fromMap({
        'imagen': await MultipartFile.fromFile(
          imagen.path,
          filename: imagen.path.split('/').last,
        ),
        'temporada': temporada,
        'notas': notas,
      });

      final response = await _api.postFormData(ApiConfig.agregarPrenda, formData);
      final data = response.data as Map<String, dynamic>;

      if (data['success'] == true) {
        final nuevaPrenda = PrendaModel.fromJson(data['prenda']);
        _prendas.insert(0, nuevaPrenda);
        _totalPrendas++;
        _estado = GuardarropaEstado.listo;
        notifyListeners();
        return nuevaPrenda;
      }
    } catch (e) {
      _mensajeError = _parsearError(e);
      _estado = GuardarropaEstado.error;
      notifyListeners();
    }
    return null;
  }

  // Eliminar prenda
  Future<bool> eliminarPrenda(String prendaId) async {
    try {
      await _api.delete(ApiConfig.eliminarPrenda(prendaId));
      _prendas.removeWhere((p) => p.id == prendaId);
      _totalPrendas = (_totalPrendas - 1).clamp(0, 9999);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // Cargar estadísticas
  Future<void> cargarStats() async {
    try {
      final response = await _api.get(ApiConfig.statsGuardarropa);
      _stats = response.data as Map<String, dynamic>;
      notifyListeners();
    } catch (_) {}
  }

  // Aplicar filtro
  void aplicarFiltros({String? tipo, String? color, String? temporada}) {
    _filtroTipo = tipo;
    _filtroColor = color;
    _filtroTemporada = temporada;
    cargarPrendas(resetear: true);
  }

  // Limpiar filtros
  void limpiarFiltros() {
    _filtroTipo = null;
    _filtroColor = null;
    _filtroTemporada = null;
    cargarPrendas(resetear: true);
  }

  String _parsearError(dynamic e) {
    if (e.toString().contains('413')) return 'La imagen es demasiado grande (máx 5MB)';
    if (e.toString().contains('400')) return 'Formato de imagen no válido';
    return 'Error al agregar la prenda';
  }
}

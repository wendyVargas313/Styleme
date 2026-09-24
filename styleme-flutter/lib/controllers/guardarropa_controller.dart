// StyleMe - Controller del Guardarropa (Provider)
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/controllers/mixins/recarga_inteligente.dart';
import 'package:styleme/models/prenda_model.dart';
import 'package:styleme/services/api_service.dart';
import 'package:styleme/services/segmentacion_service.dart';

enum GuardarropaEstado { inicial, cargando, listo, agregando, error }

class GuardarropaController extends ChangeNotifier with RecargaInteligente {
  final ApiService _api = ApiService();

  GuardarropaEstado _estado = GuardarropaEstado.inicial;
  List<PrendaModel> _prendas = [];
  Map<String, dynamic> _stats = {};
  String? _mensajeError;
  int _totalPrendas = 0;
  int _paginaActual = 1;
  bool _ultimoRefrescoFallo = false;

  // Filtros activos
  String? _filtroTipo;
  String? _filtroColor;
  String? _filtroMomento;

  GuardarropaEstado get estado => _estado;
  List<PrendaModel> get prendas => _prendas;
  Map<String, dynamic> get stats => _stats;
  String? get mensajeError => _mensajeError;
  int get totalPrendas => _totalPrendas;
  String? get filtroTipo => _filtroTipo;
  String? get filtroColor => _filtroColor;
  String? get filtroMomento => _filtroMomento;
  bool get ultimoRefrescoFallo => _ultimoRefrescoFallo;

  // Recarga solo si hace falta (nunca cargó, la última falló, o pasaron
  // más de 30s). Pensado para disparadores pasivos: cambio de pestaña,
  // vuelta a primer plano. Si ya hay una carga en curso, no dispara otra.
  // Siempre pide resetear:true (página 1) para no arrastrar una página
  // vieja si en el futuro se agrega scroll infinito.
  Future<void> refrescarSiHaceFalta() async {
    if (_estado == GuardarropaEstado.cargando) return;
    if (haceFaltaRecargar) await cargarPrendas(resetear: true);
  }

  // Cargar prendas del guardarropa
  Future<void> cargarPrendas({bool resetear = false}) async {
    if (resetear) {
      _paginaActual = 1;
    }

    final huboDatosPrevios = _prendas.isNotEmpty;
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
      if (_filtroMomento != null) queryParams['momento'] = _filtroMomento;

      final response = await _api.get(
        ApiConfig.listarPrendas,
        queryParams: queryParams,
      );

      final data = response.data as Map<String, dynamic>;
      final prendasJson = data['prendas'] as List? ?? [];
      // Solo se reemplaza la lista si la respuesta fue exitosa.
      _prendas = prendasJson.map((p) => PrendaModel.fromJson(p)).toList();
      _totalPrendas = data['total'] ?? 0;
      _estado = GuardarropaEstado.listo;
      _ultimoRefrescoFallo = false;
      registrarCargaExitosa();
    } catch (e) {
      registrarCargaFallida();
      _mensajeError = 'Error cargando prendas';
      if (huboDatosPrevios) {
        // Se conserva la lista previa: no dejamos al usuario sin nada por
        // un fallo puntual de red.
        _estado = GuardarropaEstado.listo;
        _ultimoRefrescoFallo = true;
      } else {
        _estado = GuardarropaEstado.error;
        _ultimoRefrescoFallo = false;
      }
    }
    notifyListeners();
  }

  // Agregar prenda con imagen
  Future<PrendaModel?> agregarPrenda({
    required File imagen,
    required String momento,
    String notas = '',
  }) async {
    _estado = GuardarropaEstado.agregando;
    _mensajeError = null;
    notifyListeners();

    try {
      // Recorte de fondo hecho en el celular (ML Kit); imagen sigue siendo
      // la foto ORIGINAL sin cambios, YOLO la necesita tal cual.
      final recorte = await SegmentacionService.recortarFondo(imagen);

      final campos = <String, dynamic>{
        'imagen': await MultipartFile.fromFile(
          imagen.path,
          filename: imagen.path.split('/').last,
        ),
        'momento': momento,
        'notas': notas,
      };

      if (recorte != null) {
        campos['imagen_sin_fondo'] = await MultipartFile.fromFile(
          recorte.path,
          filename: 'recorte.png',
          contentType: DioMediaType('image', 'png'),
        );
      }

      final formData = FormData.fromMap(campos);

      final response = await _api.postFormData(
        ApiConfig.agregarPrenda,
        formData,
        receiveTimeout: const Duration(seconds: 120),
      );
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
  void aplicarFiltros({String? tipo, String? color, String? momento}) {
    _filtroTipo = tipo;
    _filtroColor = color;
    _filtroMomento = momento;
    cargarPrendas(resetear: true);
  }

  // Limpiar filtros
  void limpiarFiltros() {
    _filtroTipo = null;
    _filtroColor = null;
    _filtroMomento = null;
    cargarPrendas(resetear: true);
  }

  String _parsearError(dynamic e) {
    if (e.toString().contains('413')) return 'La imagen es demasiado grande (máx 5MB)';
    if (e.toString().contains('400')) return 'Formato de imagen no válido';
    return 'Error al agregar la prenda';
  }
}

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

// Clasificación del fallo al subir una prenda, para que la cola decida si
// sigue con la siguiente foto o se detiene.
enum TipoErrorSubida {
  // Sin red, conexión rechazada, timeout de conexión o de envío: el servidor
  // no recibió el archivo completo, reintentar es seguro.
  conexion,
  // receiveTimeout: el archivo llegó y el backend puede seguir procesándolo;
  // la prenda probablemente se guardó. No se debe reintentar (duplicados).
  sinConfirmar,
  // Error de esa foto en particular (413, 400, 422, 500, etc.).
  deLaFoto,
}

class GuardarropaController extends ChangeNotifier with RecargaInteligente {
  final ApiService _api = ApiService();

  GuardarropaEstado _estado = GuardarropaEstado.inicial;
  List<PrendaModel> _prendas = [];
  Map<String, dynamic> _stats = {};
  String? _mensajeError;
  TipoErrorSubida? _ultimoErrorSubida;
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
  TipoErrorSubida? get ultimoErrorSubida => _ultimoErrorSubida;
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

  // Agregar prenda con imagen.
  // Con notificar: false (cola de varias fotos) no cambia el estado global ni
  // notifica en cada foto: solo inserta la prenda en la lista local y deja
  // el fallo en mensajeError/ultimoErrorSubida. La cola recarga una vez al
  // final.
  Future<PrendaModel?> agregarPrenda({
    required File imagen,
    required String momento,
    String notas = '',
    bool notificar = true,
  }) async {
    _mensajeError = null;
    _ultimoErrorSubida = null;
    if (notificar) {
      _estado = GuardarropaEstado.agregando;
      notifyListeners();
    }

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
        if (notificar) {
          _estado = GuardarropaEstado.listo;
          notifyListeners();
        }
        return nuevaPrenda;
      }
      _registrarErrorSubida(
          TipoErrorSubida.deLaFoto, 'Error al agregar la prenda', notificar);
    } catch (e) {
      final tipo = _clasificarErrorSubida(e);
      _registrarErrorSubida(tipo, _parsearError(e, tipo), notificar);
    }
    return null;
  }

  void _registrarErrorSubida(
      TipoErrorSubida tipo, String mensaje, bool notificar) {
    _ultimoErrorSubida = tipo;
    _mensajeError = mensaje;
    if (notificar) {
      _estado = GuardarropaEstado.error;
      notifyListeners();
    }
  }

  TipoErrorSubida _clasificarErrorSubida(Object e) {
    if (e is SocketException) return TipoErrorSubida.conexion;
    if (e is! DioException) return TipoErrorSubida.deLaFoto;
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return TipoErrorSubida.conexion;
      case DioExceptionType.receiveTimeout:
        return TipoErrorSubida.sinConfirmar;
      case DioExceptionType.unknown:
        return e.error is SocketException
            ? TipoErrorSubida.conexion
            : TipoErrorSubida.deLaFoto;
      default:
        return TipoErrorSubida.deLaFoto;
    }
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

  String _parsearError(Object e, TipoErrorSubida tipo) {
    switch (tipo) {
      case TipoErrorSubida.conexion:
        return 'Se perdió la conexión. Reintenta cuando vuelva.';
      case TipoErrorSubida.sinConfirmar:
        return 'El servidor tardó en responder; la prenda probablemente se '
            'guardó. Revisa el armario.';
      case TipoErrorSubida.deLaFoto:
        break;
    }
    if (e is DioException) {
      final codigo = e.response?.statusCode;
      final data = e.response?.data;
      final detalle =
          (data is Map && data['detail'] is String) ? data['detail'] as String : null;
      if (codigo == 413) return 'La imagen es demasiado grande (máx 5MB)';
      if (codigo == 400) return detalle ?? 'Formato de imagen no válido';
      if (codigo == 422) return detalle ?? 'Datos de la prenda no válidos';
      if (codigo != null && codigo >= 500) {
        return 'Error del servidor al procesar esta foto';
      }
    }
    return 'Error al agregar la prenda';
  }
}

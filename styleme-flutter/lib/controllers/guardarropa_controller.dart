// StyleMe - Controller del Guardarropa (Provider)
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/config/constants.dart';
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

// Resultado de un borrado múltiple en serie.
class ResultadoEliminacion {
  final List<String> eliminadas;
  final List<String> fallidas;
  // Se detuvo por falta de conexión: las que no se intentaron no están en
  // ninguna de las dos listas.
  final bool conexionPerdida;

  const ResultadoEliminacion({
    required this.eliminadas,
    required this.fallidas,
    required this.conexionPerdida,
  });
}

class GuardarropaController extends ChangeNotifier with RecargaInteligente {
  final ApiService _api = ApiService();

  // Máximo que acepta el backend por página.
  static const int _limite = 50;

  GuardarropaEstado _estado = GuardarropaEstado.inicial;
  List<PrendaModel> _prendas = [];
  Map<String, dynamic> _stats = {};
  Map<String, int> _conteoPorTipo = {};
  String? _mensajeError;
  TipoErrorSubida? _ultimoErrorSubida;
  int _totalPrendas = 0;
  bool _ultimoRefrescoFallo = false;

  bool _cargandoMas = false;
  bool _errorCargarMas = false;
  // Una página no trajo nada nuevo aunque total dijera que faltaban: se deja
  // de pedir para no entrar en un ciclo.
  bool _finForzado = false;
  Future<void>? _cargaMasEnCurso;
  // Cada recarga desde la página 1 invalida las respuestas en vuelo de
  // cargas anteriores (filtro cambiado a mitad de una petición).
  int _generacion = 0;

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
  bool get cargandoMas => _cargandoMas;
  bool get errorCargarMas => _errorCargarMas;
  bool get hayMas => !_finForzado && _prendas.length < _totalPrendas;

  // Tipos que el usuario tiene para el filtro de clima activo (si hay uno),
  // de más a menos prendas.
  List<MapEntry<String, int>> get tiposConConteo {
    final tipos = _conteoPorTipo.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value != a.value
          ? b.value.compareTo(a.value)
          : a.key.compareTo(b.key));
    return tipos;
  }

  int conteoDeTipo(String tipo) => _conteoPorTipo[tipo] ?? 0;

  // Recarga solo si hace falta (nunca cargó, la última falló, o pasaron
  // más de 30s). Pensado para disparadores pasivos: cambio de pestaña,
  // vuelta a primer plano. Si ya hay una carga en curso, no dispara otra.
  Future<void> refrescarSiHaceFalta() async {
    if (_estado == GuardarropaEstado.cargando) return;
    if (haceFaltaRecargar) await cargarPrendas(resetear: true);
  }

  Future<Map<String, dynamic>> _pedirPagina(int pagina) async {
    final queryParams = <String, dynamic>{
      'page': pagina,
      'limit': _limite,
    };
    if (_filtroTipo != null) queryParams['tipo'] = _filtroTipo;
    if (_filtroColor != null) queryParams['color'] = _filtroColor;
    if (_filtroMomento != null) queryParams['momento'] = _filtroMomento;

    final response = await _api.get(
      ApiConfig.listarPrendas,
      queryParams: queryParams,
    );
    return response.data as Map<String, dynamic>;
  }

  // Carga la página 1 y reemplaza la lista (el scroll infinito sigue con
  // cargarMas). `resetear` se conserva por compatibilidad de llamadas: esta
  // carga siempre empieza de cero.
  Future<void> cargarPrendas({bool resetear = true}) async {
    final generacion = ++_generacion;
    final huboDatosPrevios = _prendas.isNotEmpty;
    _estado = GuardarropaEstado.cargando;
    _mensajeError = null;
    _cargandoMas = false;
    _errorCargarMas = false;
    notifyListeners();

    try {
      final data = await _pedirPagina(1);
      if (generacion != _generacion) return;
      final prendasJson = data['prendas'] as List? ?? [];
      // Solo se reemplaza la lista si la respuesta fue exitosa.
      _prendas = prendasJson.map((p) => PrendaModel.fromJson(p)).toList();
      _totalPrendas = data['total'] ?? 0;
      _finForzado = false;
      _estado = GuardarropaEstado.listo;
      _ultimoRefrescoFallo = false;
      registrarCargaExitosa();
    } catch (e) {
      if (generacion != _generacion) return;
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

  // Siguiente página del scroll infinito. Si ya hay una en curso, devuelve
  // esa misma. Si falla, conserva lo cargado y deja errorCargarMas para que
  // la UI ofrezca reintentar.
  Future<void> cargarMas() {
    final enCurso = _cargaMasEnCurso;
    if (enCurso != null) return enCurso;
    if (!hayMas || _estado == GuardarropaEstado.cargando) return Future.value();
    final carga = _cargarMas();
    _cargaMasEnCurso = carga;
    return carga.whenComplete(() => _cargaMasEnCurso = null);
  }

  Future<void> _cargarMas() async {
    final generacion = _generacion;
    _cargandoMas = true;
    _errorCargarMas = false;
    notifyListeners();

    try {
      // La página se deriva de lo ya cargado, no de un contador: tras borrar
      // prendas el backend corre sus offsets, y pedir la página que contiene
      // el siguiente índice (deduplicando) evita saltarse prendas.
      final data = await _pedirPagina(_prendas.length ~/ _limite + 1);
      if (generacion != _generacion) return;
      final ids = _prendas.map((p) => p.id).toSet();
      final nuevas = (data['prendas'] as List? ?? [])
          .map((p) => PrendaModel.fromJson(p))
          .where((p) => !ids.contains(p.id))
          .toList();
      _prendas = [..._prendas, ...nuevas];
      _totalPrendas = data['total'] ?? _totalPrendas;
      if (nuevas.isEmpty) _finForzado = true;
    } catch (_) {
      if (generacion != _generacion) return;
      _errorCargarMas = true;
    }
    _cargandoMas = false;
    notifyListeners();
  }

  // Carga todas las páginas que falten. Devuelve false si alguna falló o si
  // la lista se recargó mientras tanto.
  Future<bool> cargarTodas() async {
    final generacion = _generacion;
    while (hayMas) {
      final antes = _prendas.length;
      await cargarMas();
      if (generacion != _generacion || _errorCargarMas) return false;
      if (_prendas.length == antes && hayMas) return false;
    }
    return generacion == _generacion;
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
        _conteoPorTipo[nuevaPrenda.tipo] = conteoDeTipo(nuevaPrenda.tipo) + 1;
        if (notificar) {
          _estado = GuardarropaEstado.listo;
          notifyListeners();
        }
        return nuevaPrenda;
      }
      _registrarErrorSubida(
          TipoErrorSubida.deLaFoto, 'Error al agregar la prenda', notificar);
    } catch (e) {
      final tipo = _clasificarError(e);
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

  TipoErrorSubida _clasificarError(Object e) {
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

  // Quita una prenda ya borrada en el backend de la lista local, sin recargar.
  void _quitarLocal(String prendaId) {
    final idx = _prendas.indexWhere((p) => p.id == prendaId);
    if (idx != -1) {
      final tipo = _prendas.removeAt(idx).tipo;
      final restante = conteoDeTipo(tipo) - 1;
      if (restante > 0) {
        _conteoPorTipo[tipo] = restante;
      } else {
        _conteoPorTipo.remove(tipo);
      }
    }
    _totalPrendas = (_totalPrendas - 1).clamp(0, 9999);
  }

  // Eliminar prenda
  Future<bool> eliminarPrenda(String prendaId) async {
    try {
      await _api.delete(ApiConfig.eliminarPrenda(prendaId));
      _quitarLocal(prendaId);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // Borra en serie, una por una, con el DELETE individual. Si una falla por
  // un error propio (404, 500…) sigue con las demás; si se pierde la
  // conexión, se detiene. `alAvanzar` recibe (actual, total) antes de cada
  // petición.
  Future<ResultadoEliminacion> eliminarVarias(
    List<String> ids, {
    void Function(int actual, int total)? alAvanzar,
  }) async {
    final eliminadas = <String>[];
    final fallidas = <String>[];
    var conexionPerdida = false;

    for (var i = 0; i < ids.length; i++) {
      alAvanzar?.call(i + 1, ids.length);
      try {
        await _api.delete(ApiConfig.eliminarPrenda(ids[i]));
        _quitarLocal(ids[i]);
        eliminadas.add(ids[i]);
        notifyListeners();
      } catch (e) {
        // receiveTimeout (sinConfirmar) también cuenta como conexión: el
        // servidor no confirmó y seguir solo acumularía más dudas.
        if (_clasificarError(e) != TipoErrorSubida.deLaFoto) {
          conexionPerdida = true;
          break;
        }
        fallidas.add(ids[i]);
      }
    }

    return ResultadoEliminacion(
      eliminadas: eliminadas,
      fallidas: fallidas,
      conexionPerdida: conexionPerdida,
    );
  }

  // Corrige tipo, color y/o clima (solo se envían los que no son null).
  // Devuelve la prenda actualizada o un mensaje de error; nunca lanza.
  // `anterior` es la prenda tal como la veía el usuario antes de editar, para
  // ajustar el conteo por tipo aunque no esté en la página cargada.
  Future<({PrendaModel? prenda, String? error})> editarPrenda(
    PrendaModel anterior, {
    String? tipo,
    String? color,
    String? momento,
  }) async {
    try {
      final response = await _api.patch(
        ApiConfig.editarPrenda(anterior.id),
        data: {
          if (tipo != null) 'tipo': tipo,
          if (color != null) 'color': color,
          if (momento != null) 'momento': momento,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final editada = PrendaModel.fromJson(data['prenda'] as Map<String, dynamic>);
      _aplicarEdicionLocal(anterior, editada);
      notifyListeners();
      return (prenda: editada, error: null);
    } catch (e) {
      if (_clasificarError(e) != TipoErrorSubida.deLaFoto) {
        return (
          prenda: null,
          error: 'Sin conexión: los cambios no se guardaron. Intenta de nuevo.',
        );
      }
      final data = e is DioException ? e.response?.data : null;
      final detalle = (data is Map && data['detail'] is String) ? data['detail'] as String : null;
      return (prenda: null, error: detalle ?? 'No se pudieron guardar los cambios');
    }
  }

  // Misma regla que _filtro_momento del backend: el filtro de un clima
  // incluye las versátiles.
  bool _coincideConClima(String momento) {
    final filtro = _filtroMomento;
    if (filtro == null) return true;
    return momento == filtro || momento == AppConstants.momentoDefault;
  }

  // Refleja una edición sin recargar: reemplaza la prenda en la lista (o la
  // saca si ya no cumple los filtros activos) y mueve el conteo por tipo,
  // que solo cuenta las prendas del clima filtrado.
  void _aplicarEdicionLocal(PrendaModel anterior, PrendaModel editada) {
    if (_coincideConClima(anterior.momento)) {
      final restante = conteoDeTipo(anterior.tipo) - 1;
      if (restante > 0) {
        _conteoPorTipo[anterior.tipo] = restante;
      } else {
        _conteoPorTipo.remove(anterior.tipo);
      }
    }
    if (_coincideConClima(editada.momento)) {
      _conteoPorTipo[editada.tipo] = conteoDeTipo(editada.tipo) + 1;
    }

    final idx = _prendas.indexWhere((p) => p.id == editada.id);
    if (idx == -1) return;
    final sigueEnFiltro = (_filtroTipo == null || editada.tipo == _filtroTipo) &&
        (_filtroColor == null || editada.color == _filtroColor) &&
        _coincideConClima(editada.momento);
    if (sigueEnFiltro) {
      _prendas[idx] = editada;
    } else {
      _prendas.removeAt(idx);
      _totalPrendas = (_totalPrendas - 1).clamp(0, 9999);
    }
  }

  // Estadísticas completas del armario para la hoja "Estadísticas" (ícono
  // de la barra): siempre de TODAS las prendas activas, sin importar el
  // filtro de clima que esté activo en la cuadrícula. Si falla, se
  // conserva lo anterior.
  Future<void> cargarStats() async {
    try {
      final response = await _api.get(ApiConfig.statsGuardarropa);
      _stats = response.data as Map<String, dynamic>;
      notifyListeners();
    } catch (_) {}
  }

  // Conteo por tipo para los chips de filtro: respeta el filtro de clima
  // activo (el backend cuenta sobre las mismas prendas que listar_prendas
  // devolvería con ese filtro), para que el número del chip coincida con
  // la cuadrícula. Si falla, se conserva el conteo anterior.
  Future<void> cargarConteoPorTipo() async {
    try {
      final queryParams = <String, dynamic>{};
      if (_filtroMomento != null) queryParams['momento'] = _filtroMomento;
      final response = await _api.get(
        ApiConfig.statsGuardarropa,
        queryParams: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      final porTipo = data['por_tipo'] as Map? ?? {};
      _conteoPorTipo = {
        for (final e in porTipo.entries)
          e.key.toString(): (e.value as num).toInt(),
      };
      notifyListeners();
    } catch (_) {}
  }

  // Aplicar filtro (reinicia en la página 1). El conteo por tipo de los
  // chips solo depende del clima: se recarga nada más cuando ese filtro
  // cambia (no en cada cambio de tipo).
  void aplicarFiltros({String? tipo, String? color, String? momento}) {
    final climaCambio = momento != _filtroMomento;
    _filtroTipo = tipo;
    _filtroColor = color;
    _filtroMomento = momento;
    cargarPrendas(resetear: true);
    if (climaCambio) cargarConteoPorTipo();
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

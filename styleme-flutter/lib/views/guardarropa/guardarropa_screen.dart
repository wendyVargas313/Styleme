// StyleMe - Pantalla del Guardarropa
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:styleme/app/routes.dart';
import 'package:styleme/config/constants.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/guardarropa_controller.dart';
import 'package:styleme/models/prenda_model.dart';
import 'package:styleme/views/guardarropa/detalle_prenda_screen.dart';
import 'package:styleme/widgets/glass_kit.dart';
import 'package:styleme/widgets/prenda_card.dart';

class GuardarropaScreen extends StatefulWidget {
  const GuardarropaScreen({super.key});

  @override
  State<GuardarropaScreen> createState() => _GuardarropaScreenState();
}

class _GuardarropaScreenState extends State<GuardarropaScreen>
    with SingleTickerProviderStateMixin {
  static const _nivelesColumnas = [2, 3, 4, 6, 10];
  static const _columnasPorDefecto = 3;
  static const _clavePrefColumnas = 'armario_columnas';
  // Distancia (px) al final del contenido a la que se pide la siguiente página.
  static const _umbralCargarMas = 800.0;
  static const _padSuperior = 8.0;

  bool _falloYaAvisado = false;
  final ScrollController _scroll = ScrollController();

  // ── Zoom ─────────────────────────────────────────────────
  int _columnas = _columnasPorDefecto;
  double _anchoGrid = 0;
  double _altoGrid = 0;
  final Map<int, Offset> _punteros = {};
  double? _distanciaInicial;
  bool _nivelCambiadoEnGesto = false;
  // Hubo 2+ dedos desde que bajó el primero: el tap/long press de ese gesto
  // se ignora. Se reinicia al bajar el primer dedo del siguiente gesto (no
  // al levantar, porque el tap se resuelve después del pointer up).
  bool _huboMultitactil = false;
  // Mientras hay 2+ dedos el scroll queda desactivado.
  bool _pinchActivo = false;
  late final AnimationController _animZoom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  double _escalaInicial = 1;
  Alignment _focoZoom = Alignment.center;

  // ── Selección y borrado ──────────────────────────────────
  final Set<String> _seleccion = {};
  bool _cargandoTodas = false;
  bool _borrando = false;
  int _progresoActual = 0;
  int _progresoTotal = 0;
  bool _verificacionRellenoPendiente = false;

  bool get _modoSeleccion => _seleccion.isNotEmpty;
  bool get _bloqueado => _borrando || _cargandoTodas;

  @override
  void initState() {
    super.initState();
    _cargarColumnasGuardadas();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recargarTodo());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El armario vive en un IndexedStack: si la pestaña deja de verse, el
    // modo selección se cierra para que su PopScope no capture el "atrás"
    // de otra pestaña.
    if (!TickerMode.of(context) && _modoSeleccion && !_bloqueado) {
      _seleccion.clear();
    }
  }

  @override
  void dispose() {
    _animZoom.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _recargarTodo() async {
    final ctrl = context.read<GuardarropaController>();
    await Future.wait([ctrl.cargarPrendas(resetear: true), ctrl.cargarStats()]);
  }

  void _snack(String mensaje, {Color? color}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: color));
  }

  void _avisarSiFallo(GuardarropaController ctrl) {
    if (ctrl.ultimoRefrescoFallo && !_falloYaAvisado) {
      _falloYaAvisado = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _snack('Sin conexión. Mostrando la última información disponible.');
      });
    } else if (!ctrl.ultimoRefrescoFallo) {
      _falloYaAvisado = false;
    }
  }

  // ── Persistencia del nivel de zoom ───────────────────────
  Future<void> _cargarColumnasGuardadas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getInt(_clavePrefColumnas);
      if (guardado != null && _nivelesColumnas.contains(guardado) && mounted) {
        setState(() => _columnas = guardado);
      }
    } catch (_) {}
  }

  Future<void> _guardarColumnas(int columnas) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_clavePrefColumnas, columnas);
    } catch (_) {}
  }

  // ── Geometría del grid por nivel ─────────────────────────
  double _padHorizontal(int cols) => cols >= 6 ? 4 : 16;
  double _espaciado(int cols) => switch (cols) { 2 => 12, 3 => 10, 4 => 8, _ => 3 };
  double _aspecto(int cols) => cols >= 6 ? 1.0 : 0.75;

  double _altoFila(int cols) {
    final ancho = (_anchoGrid - 2 * _padHorizontal(cols) - _espaciado(cols) * (cols - 1)) / cols;
    return ancho / _aspecto(cols) + _espaciado(cols);
  }

  // ── Pinch con Listener (fuera de la arena de gestos) ─────
  List<Offset> get _dosPrimeros => _punteros.values.take(2).toList();
  double _distanciaActual() => (_dosPrimeros[0] - _dosPrimeros[1]).distance;
  Offset _focoActual() => (_dosPrimeros[0] + _dosPrimeros[1]) / 2;

  void _alBajarDedo(PointerDownEvent e) {
    if (_punteros.isEmpty) _huboMultitactil = false;
    _punteros[e.pointer] = e.localPosition;
    if (_punteros.length < 2) return;
    _huboMultitactil = true;
    if (_punteros.length == 2 && !_borrando) {
      _distanciaInicial = _distanciaActual();
      _nivelCambiadoEnGesto = false;
      if (!_pinchActivo) setState(() => _pinchActivo = true);
    }
  }

  void _alMoverDedo(PointerMoveEvent e) {
    if (!_punteros.containsKey(e.pointer)) return;
    _punteros[e.pointer] = e.localPosition;
    final inicial = _distanciaInicial;
    if (!_pinchActivo || _nivelCambiadoEnGesto || _punteros.length < 2) return;
    if (inicial == null || inicial < 20) return;
    final proporcion = _distanciaActual() / inicial;
    if (proporcion >= 1.25 || proporcion <= 0.8) {
      _nivelCambiadoEnGesto = true;
      // Separar los dedos acerca (menos columnas); juntarlos aleja.
      _cambiarNivel(proporcion >= 1.25 ? -1 : 1, _focoActual());
    }
  }

  void _alLevantarDedo(PointerEvent e) {
    _punteros.remove(e.pointer);
    if (_punteros.length < 2) {
      _distanciaInicial = null;
      if (_pinchActivo) setState(() => _pinchActivo = false);
    }
  }

  void _cambiarNivel(int paso, Offset foco) {
    final indice = _nivelesColumnas.indexOf(_columnas);
    final nuevoIndice = (indice + paso).clamp(0, _nivelesColumnas.length - 1);
    if (nuevoIndice == indice) return;
    final anteriores = _columnas;
    final nuevas = _nivelesColumnas[nuevoIndice];

    // Mantiene bajo los dedos la prenda que estaba bajo el foco del gesto.
    double? nuevoOffset;
    if (_scroll.hasClients && _anchoGrid > 0) {
      final fila = ((_scroll.offset + foco.dy - _padSuperior) / _altoFila(anteriores))
          .floor()
          .clamp(0, 1 << 30);
      final anchoUtil = _anchoGrid - 2 * _padHorizontal(anteriores);
      final columna = ((foco.dx - _padHorizontal(anteriores)) / anchoUtil * anteriores)
          .floor()
          .clamp(0, anteriores - 1);
      final prenda = fila * anteriores + columna;
      final altoNuevo = _altoFila(nuevas);
      nuevoOffset = _padSuperior + (prenda ~/ nuevas) * altoNuevo + altoNuevo / 2 - foco.dy;
    }

    setState(() {
      _columnas = nuevas;
      // Arranca con las tarjetas del tamaño que tenían y se ajusta a 1.
      _escalaInicial = nuevas / anteriores;
      _focoZoom = Alignment(
        _anchoGrid > 0 ? (foco.dx / _anchoGrid) * 2 - 1 : 0,
        _altoGrid > 0 ? (foco.dy / _altoGrid) * 2 - 1 : 0,
      );
    });
    _animZoom.forward(from: 0);
    HapticFeedback.selectionClick();
    _guardarColumnas(nuevas);

    if (nuevoOffset != null) {
      final destino = nuevoOffset;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final pos = _scroll.position;
        _scroll.jumpTo(destino.clamp(pos.minScrollExtent, pos.maxScrollExtent));
      });
    }
  }

  // ── Tap / long press ─────────────────────────────────────
  bool get _gestoAnulado => _huboMultitactil || _pinchActivo || _bloqueado;

  void _alTocar(PrendaModel prenda) {
    if (_gestoAnulado) return;
    if (_modoSeleccion) {
      _alternar(prenda.id);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetallePrendaScreen(prenda: prenda)),
    );
  }

  void _alMantener(PrendaModel prenda) {
    if (_gestoAnulado) return;
    if (_modoSeleccion) {
      _alternar(prenda.id);
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _seleccion.add(prenda.id));
  }

  void _alternar(String id) {
    setState(() {
      if (!_seleccion.remove(id)) _seleccion.add(id);
    });
  }

  void _salirDeSeleccion() => setState(_seleccion.clear);

  Future<void> _seleccionarTodas(GuardarropaController ctrl) async {
    if (ctrl.hayMas) {
      setState(() => _cargandoTodas = true);
      final ok = await ctrl.cargarTodas();
      if (!mounted) return;
      setState(() => _cargandoTodas = false);
      if (!ok) {
        _snack('No se pudieron cargar todas las prendas. Revisa tu conexión e intenta de nuevo.');
        return;
      }
      // El usuario salió del modo selección mientras cargaba.
      if (!_modoSeleccion) return;
    }
    setState(() => _seleccion.addAll(ctrl.prendas.map((p) => p.id)));
  }

  // ── Borrado múltiple ─────────────────────────────────────
  Future<void> _confirmarYBorrar(GuardarropaController ctrl) async {
    final n = _seleccion.length;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: StyleMeTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          n == 1 ? '¿Eliminar 1 prenda?' : '¿Eliminar $n prendas?',
          style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Esta acción no se puede deshacer desde la app.',
          style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Cancelar', style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text('Eliminar',
                style: GoogleFonts.poppins(color: StyleMeTheme.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    // En el orden en que el usuario las ve.
    final ids = ctrl.prendas.where((p) => _seleccion.contains(p.id)).map((p) => p.id).toList();
    setState(() {
      _borrando = true;
      _progresoActual = 0;
      _progresoTotal = ids.length;
    });

    final resultado = await ctrl.eliminarVarias(
      ids,
      alAvanzar: (actual, total) {
        if (mounted) {
          setState(() {
            _progresoActual = actual;
            _progresoTotal = total;
          });
        }
      },
    );
    if (!mounted) return;

    // Las fallidas y las no intentadas quedan seleccionadas.
    setState(() {
      _borrando = false;
      _seleccion.removeAll(resultado.eliminadas);
    });

    final eliminadas = resultado.eliminadas.length;
    final conError = resultado.fallidas.length;
    final pendientes = ids.length - eliminadas - conError;
    final partes = [
      _plural(eliminadas, 'eliminada', 'eliminadas'),
      if (conError > 0) '$conError con error',
      if (pendientes > 0) _plural(pendientes, 'pendiente', 'pendientes'),
    ];
    if (resultado.conexionPerdida) {
      _snack('Se perdió la conexión y se detuvo la eliminación: ${partes.join(', ')}.',
          color: StyleMeTheme.error);
    } else if (conError > 0) {
      _snack('${partes.join(', ')}.', color: StyleMeTheme.warning);
    } else {
      _snack(eliminadas == 1 ? '1 prenda eliminada' : '$eliminadas prendas eliminadas',
          color: StyleMeTheme.success);
    }
  }

  String _plural(int n, String singular, String plural) => '$n ${n == 1 ? singular : plural}';

  // ── Scroll infinito ──────────────────────────────────────
  void _pedirMasSiToca(GuardarropaController ctrl) {
    if (!ctrl.hayMas || ctrl.cargandoMas || ctrl.errorCargarMas) return;
    if (ctrl.estado == GuardarropaEstado.cargando) return;
    // Fuera del frame actual: cargarMas notifica de inmediato.
    Future.microtask(ctrl.cargarMas);
  }

  // Si lo cargado no alcanza a llenar la pantalla (p. ej. 10 columnas) no
  // habrá scroll que dispare la siguiente página: se pide directamente.
  void _verificarRelleno(GuardarropaController ctrl) {
    if (_verificacionRellenoPendiente) return;
    _verificacionRellenoPendiente = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificacionRellenoPendiente = false;
      if (!mounted || !_scroll.hasClients) return;
      if (_scroll.position.extentAfter < _umbralCargarMas) _pedirMasSiToca(ctrl);
    });
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GuardarropaController>();
    _avisarSiFallo(ctrl);
    if (!_borrando) {
      // Una recarga pudo sacar de la lista prendas que estaban marcadas.
      final ids = ctrl.prendas.map((p) => p.id).toSet();
      _seleccion.retainAll(ids);
    }
    final visible = TickerMode.of(context);

    return PopScope(
      canPop: !(visible && (_modoSeleccion || _bloqueado)),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_borrando) {
          _snack('Espera a que termine la eliminación');
        } else {
          _salirDeSeleccion();
        }
      },
      child: Scaffold(
        backgroundColor: StyleMeTheme.background,
        appBar: _modoSeleccion || _borrando ? _appBarSeleccion(ctrl) : _appBarNormal(ctrl),
        body: Column(
          children: [
            if (_borrando)
              LinearProgressIndicator(
                value: _progresoTotal == 0 ? null : _progresoActual / _progresoTotal,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(StyleMeTheme.error),
              ),
            // Filtros horizontales (inactivos en modo selección)
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: IgnorePointer(
                ignoring: _modoSeleccion || _bloqueado,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _modoSeleccion || _bloqueado ? 0.4 : 1,
                  child: _buildFiltros(ctrl),
                ),
              ),
            ),
            // Grid de prendas
            Expanded(
              child: FadeSlideIn(
                delay: const Duration(milliseconds: 120),
                child: _buildGrid(ctrl),
              ),
            ),
          ],
        ),
        floatingActionButton: _modoSeleccion || _bloqueado
            ? null
            : Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: StyleMeTheme.naranjaGlow,
                ),
                child: FloatingActionButton(
                  onPressed: () async {
                    await Navigator.pushNamed(context, AppRoutes.agregarPrenda);
                    if (mounted) _recargarTodo();
                  },
                  backgroundColor: StyleMeTheme.primary,
                  elevation: 0,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
      ),
    );
  }

  PreferredSizeWidget _appBarNormal(GuardarropaController ctrl) {
    return GlassAppBar(
      title: 'Mi Armario',
      actions: [
        IconButton(
          icon: const Icon(Icons.bar_chart, color: StyleMeTheme.primary),
          onPressed: () => _mostrarStats(context, ctrl),
          tooltip: 'Estadísticas',
        ),
      ],
    );
  }

  PreferredSizeWidget _appBarSeleccion(GuardarropaController ctrl) {
    final todasSeleccionadas = !ctrl.hayMas && _seleccion.length >= ctrl.prendas.length;
    final titulo = _borrando
        ? 'Eliminando $_progresoActual de $_progresoTotal…'
        : _cargandoTodas
            ? 'Cargando todas…'
            : _plural(_seleccion.length, 'seleccionada', 'seleccionadas');
    return GlassAppBar(
      title: titulo,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.close, color: StyleMeTheme.textPrimary),
        tooltip: 'Salir de la selección',
        onPressed: _borrando ? null : _salirDeSeleccion,
      ),
      actions: [
        if (_cargandoTodas)
          const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: StyleMeTheme.primary),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.select_all, color: StyleMeTheme.textPrimary),
            tooltip: 'Seleccionar todas',
            onPressed: _bloqueado || todasSeleccionadas ? null : () => _seleccionarTodas(ctrl),
          ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: StyleMeTheme.error),
          tooltip: 'Eliminar',
          onPressed: _bloqueado || !_modoSeleccion ? null : () => _confirmarYBorrar(ctrl),
        ),
      ],
    );
  }

  Widget _buildFiltros(GuardarropaController ctrl) {
    final tipos = ctrl.tiposConConteo;
    final tipoActivo = ctrl.filtroTipo;
    // El tipo filtrado se muestra aunque ya no le queden prendas, para poder
    // quitar el filtro.
    if (tipoActivo != null && !tipos.any((e) => e.key == tipoActivo)) {
      tipos.add(MapEntry(tipoActivo, 0));
    }
    final filtros = <(String, String?)>[
      ('Todo', null),
      ...tipos.map((e) => ('${AppConstants.etiquetaTipo(e.key)} (${e.value})', e.key)),
    ];

    return Column(
      children: [
        // Filtros por tipo: solo los que el usuario tiene, con su conteo.
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtros.length,
            itemBuilder: (_, i) {
              final (label, tipo) = filtros[i];
              final activo = tipo == tipoActivo;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: activo ? Colors.white : StyleMeTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  selected: activo,
                  // Conserva el filtro de clima; tocar el tipo activo lo quita.
                  onSelected: (_) => ctrl.aplicarFiltros(
                    tipo: activo ? null : tipo,
                    color: ctrl.filtroColor,
                    momento: ctrl.filtroMomento,
                  ),
                  backgroundColor: StyleMeTheme.card,
                  selectedColor: StyleMeTheme.primary,
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                    color: activo ? StyleMeTheme.primary : Colors.transparent,
                  ),
                  showCheckmark: false,
                ),
              );
            },
          ),
        ),
        // Filtros por momento
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: AppConstants.momentosSeleccionables.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                final activo = ctrl.filtroMomento == null;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('Todas', style: GoogleFonts.poppins(color: activo ? Colors.white : StyleMeTheme.textSecondary, fontSize: 12)),
                    selected: activo,
                    onSelected: (_) => ctrl.aplicarFiltros(tipo: ctrl.filtroTipo, color: ctrl.filtroColor),
                    backgroundColor: StyleMeTheme.card,
                    selectedColor: StyleMeTheme.primaryDark,
                    showCheckmark: false,
                    side: BorderSide.none,
                  ),
                );
              }
              // El backend incluye las versátiles en ambos filtros.
              final m = AppConstants.momentosSeleccionables[i - 1];
              final activo = ctrl.filtroMomento == m;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    '${AppConstants.iconoMomento(m)} ${AppConstants.etiquetaMomento(m)}',
                    style: GoogleFonts.poppins(color: activo ? Colors.white : StyleMeTheme.textSecondary, fontSize: 12),
                  ),
                  selected: activo,
                  onSelected: (_) => ctrl.aplicarFiltros(
                    tipo: ctrl.filtroTipo,
                    color: ctrl.filtroColor,
                    momento: activo ? null : m,
                  ),
                  backgroundColor: StyleMeTheme.card,
                  selectedColor: StyleMeTheme.primaryDark,
                  showCheckmark: false,
                  side: BorderSide.none,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildGrid(GuardarropaController ctrl) {
    if (ctrl.estado == GuardarropaEstado.cargando && ctrl.prendas.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: StyleMeTheme.primary),
      );
    }

    if (ctrl.estado == GuardarropaEstado.error && ctrl.prendas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: StyleMeTheme.textSecondary, size: 48),
            const SizedBox(height: 12),
            Text(
              ctrl.mensajeError ?? 'No se pudo cargar tu armario',
              style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _recargarTodo,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: StyleMeTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (ctrl.prendas.isEmpty) {
      final hayFiltros = ctrl.filtroTipo != null || ctrl.filtroMomento != null || ctrl.filtroColor != null;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.checkroom, color: StyleMeTheme.textSecondary, size: 52),
            const SizedBox(height: 12),
            Text(
              hayFiltros ? 'No hay prendas con estos filtros' : 'Tu armario está vacío',
              style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (!hayFiltros) ...[
              const SizedBox(height: 6),
              Text(
                'Agrega tu primera prenda\npresionando el botón +',
                style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    _verificarRelleno(ctrl);
    final padH = _padHorizontal(_columnas);
    final espaciado = _espaciado(_columnas);

    return LayoutBuilder(
      builder: (_, restricciones) {
        _anchoGrid = restricciones.maxWidth;
        _altoGrid = restricciones.maxHeight;
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _alBajarDedo,
          onPointerMove: _alMoverDedo,
          onPointerUp: _alLevantarDedo,
          onPointerCancel: _alLevantarDedo,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _animZoom,
              builder: (_, child) {
                final t = Curves.easeOutCubic.transform(_animZoom.value);
                return Transform.scale(
                  scale: _escalaInicial + (1 - _escalaInicial) * t,
                  alignment: _focoZoom,
                  child: child,
                );
              },
              child: RefreshIndicator(
                color: StyleMeTheme.primary,
                notificationPredicate: (n) => n.depth == 0 && !_modoSeleccion && !_bloqueado,
                onRefresh: _recargarTodo,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.extentAfter < _umbralCargarMas) _pedirMasSiToca(ctrl);
                    return false;
                  },
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: _pinchActivo
                        ? const NeverScrollableScrollPhysics()
                        : const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(padH, _padSuperior, padH, 0),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _columnas,
                            childAspectRatio: _aspecto(_columnas),
                            crossAxisSpacing: espaciado,
                            mainAxisSpacing: espaciado,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (_, i) {
                              final prenda = ctrl.prendas[i];
                              return PrendaCard(
                                key: ValueKey(prenda.id),
                                prenda: prenda,
                                seleccionada: _seleccion.contains(prenda.id),
                                enSeleccion: _modoSeleccion,
                                compacta: _columnas >= 3,
                                soloImagen: _columnas >= 6,
                                onTap: () => _alTocar(prenda),
                                onLongPress: () => _alMantener(prenda),
                              );
                            },
                            childCount: ctrl.prendas.length,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(child: _buildPie(ctrl)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Pie del grid: cargando más / error con reintento / fin. El alto extra
  // deja libre la zona del botón +.
  Widget _buildPie(GuardarropaController ctrl) {
    final estilo = GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 12);
    Widget contenido;
    if (ctrl.cargandoMas) {
      contenido = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: StyleMeTheme.primary),
          ),
          const SizedBox(width: 10),
          Text('Cargando más prendas…', style: estilo),
        ],
      );
    } else if (ctrl.errorCargarMas) {
      contenido = Column(
        children: [
          Text('No se pudieron cargar más prendas', style: estilo),
          TextButton.icon(
            onPressed: ctrl.cargarMas,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reintentar'),
          ),
        ],
      );
    } else if (!ctrl.hayMas) {
      contenido = Text(_plural(ctrl.totalPrendas, 'prenda', 'prendas'), style: estilo);
    } else {
      contenido = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Center(child: contenido),
    );
  }

  void _mostrarStats(BuildContext context, GuardarropaController ctrl) {
    ctrl.cargarStats();
    showModalBottomSheet(
      context: context,
      backgroundColor: StyleMeTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        builder: (_, scrollCtrl) => _StatsSheet(scrollCtrl: scrollCtrl),
      ),
    );
  }
}

class _StatsSheet extends StatelessWidget {
  final ScrollController scrollCtrl;
  const _StatsSheet({required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<GuardarropaController>().stats;

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(width: 36, height: 4, decoration: BoxDecoration(color: StyleMeTheme.textSecondary, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Estadísticas', style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              if (stats.isEmpty)
                const Center(child: CircularProgressIndicator(color: StyleMeTheme.primary))
              else ...[
                _statRow('Total prendas', '${stats['total_prendas'] ?? 0}'),
                _statRow('Nunca usadas', '${stats['prendas_nunca_usadas'] ?? 0}'),
                const SizedBox(height: 12),
                _distribucion('Por tipo', stats['por_tipo'] as Map? ?? {},
                    etiqueta: AppConstants.etiquetaTipo),
                const SizedBox(height: 12),
                _distribucion('Por color', stats['por_color'] as Map? ?? {}),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _statRow(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary)),
          Text(valor, style: GoogleFonts.poppins(color: StyleMeTheme.primary, fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _distribucion(String titulo, Map datos, {String Function(String)? etiqueta}) {
    if (datos.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        ...datos.entries.take(6).map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  etiqueta != null ? etiqueta(e.key.toString()) : e.key.toString(),
                  style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 12),
                ),
              ),
              Text(e.value.toString(), style: GoogleFonts.poppins(color: StyleMeTheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        )),
      ],
    );
  }
}

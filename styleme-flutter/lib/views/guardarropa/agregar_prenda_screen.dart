// StyleMe - Pantalla para agregar prendas (hasta 10 fotos por tanda)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:styleme/config/constants.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/guardarropa_controller.dart';
import 'package:styleme/services/image_service.dart';
import 'package:styleme/widgets/custom_button.dart';

const _maxFotos = 10;

enum _EstadoFoto { pendiente, subiendo, guardada, error, sinConfirmar }

// Estado local de cada foto antes y durante la subida.
class _PrendaPendiente {
  _PrendaPendiente(this.archivo);

  final File archivo;
  String momento = AppConstants.momentoDefault;
  bool seleccionada = false;
  _EstadoFoto estado = _EstadoFoto.pendiente;
  String? mensajeError;

  // Se puede seleccionar, cambiar de momento y (re)subir.
  bool get editable =>
      estado == _EstadoFoto.pendiente || estado == _EstadoFoto.error;

  bool get quitable => editable || estado == _EstadoFoto.sinConfirmar;
}

class AgregarPrendaScreen extends StatefulWidget {
  const AgregarPrendaScreen({super.key});

  @override
  State<AgregarPrendaScreen> createState() => _AgregarPrendaScreenState();
}

class _AgregarPrendaScreenState extends State<AgregarPrendaScreen> {
  final List<_PrendaPendiente> _fotos = [];
  bool _subiendo = false;
  bool _huboCorrida = false;
  bool _cerrando = false;
  int _progresoActual = 0;
  int _progresoTotal = 0;
  String? _avisoDetencion;

  Iterable<_PrendaPendiente> get _seleccionadas =>
      _fotos.where((f) => f.seleccionada);
  Iterable<_PrendaPendiente> get _porSubir => _fotos.where((f) => f.editable);
  int _contar(_EstadoFoto e) => _fotos.where((f) => f.estado == e).length;

  void _snack(String mensaje, {Color? color}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: color));
  }

  // ── Agregar / quitar fotos ──────────────────────────────────
  Future<void> _agregarDeGaleria() async {
    final cupo = _maxFotos - _fotos.length;
    if (cupo <= 0) return;
    final resultado = await ImageService.seleccionarVarias(max: cupo);
    if (!mounted || resultado.archivos.isEmpty) return;
    setState(() => _fotos.addAll(resultado.archivos.map(_PrendaPendiente.new)));
    if (resultado.recortadas) {
      final n = resultado.archivos.length;
      _snack(n == 1
          ? 'Solo se agregó 1 foto (máximo $_maxFotos)'
          : 'Solo se agregaron $n fotos (máximo $_maxFotos)');
    }
  }

  Future<void> _agregarDeCamara() async {
    if (_fotos.length >= _maxFotos) return;
    final archivo = await ImageService.tomarFoto();
    if (!mounted || archivo == null) return;
    setState(() => _fotos.add(_PrendaPendiente(archivo)));
  }

  void _quitar(_PrendaPendiente foto) {
    if (_subiendo || !foto.quitable) return;
    setState(() => _fotos.remove(foto));
  }

  // ── Selección y momento ─────────────────────────────────────
  void _alternarSeleccion(_PrendaPendiente foto) {
    if (_subiendo || !foto.editable) return;
    setState(() => foto.seleccionada = !foto.seleccionada);
  }

  void _asignarMomento(String momento) {
    setState(() {
      for (final f in _seleccionadas.toList()) {
        f.momento = momento;
        f.seleccionada = false;
      }
    });
  }

  void _seleccionarTodas(bool valor) {
    setState(() {
      for (final f in _fotos.where((f) => f.editable)) {
        f.seleccionada = valor;
      }
    });
  }

  // ── Cola de subida (en serie) ───────────────────────────────
  Future<void> _subirCola() async {
    final cola = _porSubir.toList();
    if (cola.isEmpty || _subiendo) return;
    final ctrl = context.read<GuardarropaController>();

    setState(() {
      _subiendo = true;
      _huboCorrida = true;
      _avisoDetencion = null;
      _progresoActual = 0;
      _progresoTotal = cola.length;
      for (final f in _fotos) {
        f.seleccionada = false;
      }
      for (final f in cola) {
        f.estado = _EstadoFoto.pendiente;
        f.mensajeError = null;
      }
    });

    for (final foto in cola) {
      setState(() {
        _progresoActual++;
        foto.estado = _EstadoFoto.subiendo;
      });

      final prenda = await ctrl.agregarPrenda(
        imagen: foto.archivo,
        momento: foto.momento,
        notificar: false,
      );
      if (!mounted) return;

      if (prenda != null) {
        setState(() => foto.estado = _EstadoFoto.guardada);
        continue;
      }

      final tipo = ctrl.ultimoErrorSubida ?? TipoErrorSubida.deLaFoto;
      final mensaje = ctrl.mensajeError ?? 'Error al agregar la prenda';

      if (tipo == TipoErrorSubida.deLaFoto) {
        setState(() {
          foto.estado = _EstadoFoto.error;
          foto.mensajeError = mensaje;
        });
        continue;
      }

      // Conexión o sin confirmar: se detiene la cola; las restantes quedan
      // en pendiente.
      setState(() {
        if (tipo == TipoErrorSubida.conexion) {
          foto.estado = _EstadoFoto.pendiente;
        } else {
          foto.estado = _EstadoFoto.sinConfirmar;
          foto.mensajeError = mensaje;
        }
        _avisoDetencion = mensaje;
      });
      break;
    }

    final total = _fotos.length;
    final todasGuardadas = _contar(_EstadoFoto.guardada) == total;
    setState(() {
      _subiendo = false;
      _cerrando = todasGuardadas;
    });

    if (todasGuardadas) {
      // Al volver, guardarropa_screen recarga el armario.
      _snack(total == 1 ? '1 prenda guardada' : '$total prendas guardadas',
          color: StyleMeTheme.success);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

    if (_avisoDetencion != null) {
      _snack(_avisoDetencion!, color: StyleMeTheme.error);
    }
    await ctrl.cargarPrendas(resetear: true);
  }

  // ── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_subiendo,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _snack('Espera a que terminen las subidas');
      },
      child: Scaffold(
        backgroundColor: StyleMeTheme.background,
        appBar: AppBar(
          title: const Text('Agregar prenda'),
          backgroundColor: StyleMeTheme.background,
        ),
        body: _fotos.isEmpty ? _buildVacio() : _buildConFotos(),
        bottomNavigationBar: _fotos.isEmpty ? null : _buildPanelInferior(),
      ),
    );
  }

  Widget _buildVacio() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fotos de tus prendas',
            style: GoogleFonts.poppins(
              color: StyleMeTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _BotonFuente(
                  icono: Icons.photo_library,
                  texto: 'Galería (hasta $_maxFotos)',
                  onTap: _agregarDeGaleria,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BotonFuente(
                  icono: Icons.camera_alt,
                  texto: 'Cámara',
                  onTap: _agregarDeCamara,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConFotos() {
    final puedeAgregar =
        !_subiendo && !_huboCorrida && _fotos.length < _maxFotos;
    final cupo = _maxFotos - _fotos.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Fotos de tus prendas',
                style: GoogleFonts.poppins(
                  color: StyleMeTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${_fotos.length}/$_maxFotos',
                style: GoogleFonts.poppins(
                  color: StyleMeTheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (puedeAgregar) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _agregarDeGaleria,
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: Text('Galería (hasta $cupo)',
                        style: GoogleFonts.poppins(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _agregarDeCamara,
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: Text('Cámara',
                        style: GoogleFonts.poppins(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Toca las fotos para seleccionarlas y marcarlas como Día o Noche. '
            'Las que no marques quedan en Ambos.',
            style: GoogleFonts.poppins(
                color: StyleMeTheme.textPrimary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _fotos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (_, i) => _buildMiniatura(_fotos[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniatura(_PrendaPendiente foto) {
    return GestureDetector(
      onTap: () => _alternarSeleccion(foto),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: foto.seleccionada ? StyleMeTheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(foto.archivo, fit: BoxFit.cover),
              _buildOverlayEstado(foto),
              // Momento (esquina superior izquierda)
              Positioned(
                top: 4,
                left: 4,
                child: _Insignia(
                  child: Text(AppConstants.iconoMomento(foto.momento),
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
              // Quitar (esquina superior derecha)
              if (foto.quitable && !_subiendo)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _quitar(foto),
                    child: const _Insignia(
                      child: Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              // Seleccionada (esquina inferior derecha)
              if (foto.seleccionada)
                const Positioned(
                  bottom: 4,
                  right: 4,
                  child: Icon(Icons.check_circle,
                      color: StyleMeTheme.primary, size: 22),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayEstado(_PrendaPendiente foto) {
    switch (foto.estado) {
      case _EstadoFoto.pendiente:
        return const SizedBox.shrink();
      case _EstadoFoto.subiendo:
        return Container(
          color: Colors.black.withValues(alpha: 0.55),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(StyleMeTheme.primary),
            ),
          ),
        );
      case _EstadoFoto.guardada:
        return Container(
          color: Colors.black.withValues(alpha: 0.45),
          alignment: Alignment.center,
          child: const Icon(Icons.check_circle,
              color: StyleMeTheme.success, size: 34),
        );
      case _EstadoFoto.error:
      case _EstadoFoto.sinConfirmar:
        final esError = foto.estado == _EstadoFoto.error;
        return Container(
          color: Colors.black.withValues(alpha: 0.45),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () => _snack(
              foto.mensajeError ??
                  (esError ? 'Error al agregar la prenda' : 'Sin confirmar'),
              color: esError ? StyleMeTheme.error : StyleMeTheme.warning,
            ),
            child: Text(esError ? '⚠️' : '⏳',
                style: const TextStyle(fontSize: 28)),
          ),
        );
    }
  }

  // ── Panel inferior: acciones de selección, progreso y botones ──
  Widget _buildPanelInferior() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: StyleMeTheme.surface,
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_subiendo && _seleccionadas.isNotEmpty) ...[
              _buildBarraSeleccion(),
              const SizedBox(height: 10),
            ],
            if (_subiendo)
              _buildProgreso()
            else if (_huboCorrida)
              _buildResultado()
            else
              _buildBotonGuardar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraSeleccion() {
    final editables = _fotos.where((f) => f.editable).length;
    final todasSeleccionadas = _seleccionadas.length == editables;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (momento, texto) in const [
              ('dia', '☀️ Día'),
              ('noche', '🌙 Noche'),
              ('ambos', '🔄 Ambos'),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: OutlinedButton(
                    onPressed: () => _asignarMomento(momento),
                    child: Text(texto,
                        style: GoogleFonts.poppins(fontSize: 12)),
                  ),
                ),
              ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                '${_seleccionadas.length} seleccionada'
                '${_seleccionadas.length == 1 ? '' : 's'}',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    color: StyleMeTheme.textSecondary, fontSize: 12),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!todasSeleccionadas)
                  TextButton(
                    onPressed: () => _seleccionarTodas(true),
                    child: Text('Seleccionar todas',
                        style: GoogleFonts.poppins(fontSize: 12)),
                  ),
                TextButton(
                  onPressed: () => _seleccionarTodas(false),
                  child: Text('Quitar selección',
                      style: GoogleFonts.poppins(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBotonGuardar() {
    final n = _porSubir.length;
    return CustomButton(
      texto: n == 1 ? 'Guardar prenda' : 'Guardar $n prendas',
      onPressed: n > 0 ? _subirCola : null,
      icono: Icons.save,
    );
  }

  Widget _buildProgreso() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Subiendo $_progresoActual de $_progresoTotal…',
          style: GoogleFonts.poppins(
            color: StyleMeTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: _progresoTotal == 0 ? null : _progresoActual / _progresoTotal,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          valueColor:
              const AlwaysStoppedAnimation<Color>(StyleMeTheme.primary),
          borderRadius: BorderRadius.circular(4),
          minHeight: 4,
        ),
      ],
    );
  }

  Widget _buildResultado() {
    final guardadas = _contar(_EstadoFoto.guardada);
    final conError = _contar(_EstadoFoto.error);
    final sinConfirmar = _contar(_EstadoFoto.sinConfirmar);
    final pendientes = _contar(_EstadoFoto.pendiente);
    final todasGuardadas = guardadas == _fotos.length;

    final partes = [
      '$guardadas guardada${guardadas == 1 ? '' : 's'}',
      if (conError > 0) '$conError con error',
      if (sinConfirmar > 0) '$sinConfirmar sin confirmar',
      if (pendientes > 0) '$pendientes pendiente${pendientes == 1 ? '' : 's'}',
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          partes.join(', '),
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: StyleMeTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_avisoDetencion != null) ...[
          const SizedBox(height: 4),
          Text(
            _avisoDetencion!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                color: StyleMeTheme.textSecondary, fontSize: 12),
          ),
        ],
        if (!_cerrando) ...[
          if (!todasGuardadas) ...[
            const SizedBox(height: 12),
            CustomButton(
              texto: 'Reintentar fallidas',
              onPressed: _porSubir.isNotEmpty ? _subirCola : null,
              icono: Icons.refresh,
            ),
          ],
          const SizedBox(height: 8),
          CustomButton(
            texto: 'Terminar',
            outline: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ],
    );
  }
}

class _BotonFuente extends StatelessWidget {
  const _BotonFuente({
    required this.icono,
    required this.texto,
    required this.onTap,
  });

  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: StyleMeTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: StyleMeTheme.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                gradient: StyleMeTheme.gradientePrimario,
                shape: BoxShape.circle,
              ),
              child: Icon(icono, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              texto,
              style: GoogleFonts.poppins(
                color: StyleMeTheme.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Insignia extends StatelessWidget {
  const _Insignia({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

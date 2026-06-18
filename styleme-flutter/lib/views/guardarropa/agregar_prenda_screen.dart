// StyleMe - Pantalla para agregar una nueva prenda
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/config/constants.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/guardarropa_controller.dart';
import 'package:styleme/models/prenda_model.dart';
import 'package:styleme/widgets/camera_widget.dart';
import 'package:styleme/widgets/custom_button.dart';

// Naranja StyleMe
const _naranja = Color(0xFFFF6B00);

// Estados de la pantalla
enum _Estado { inicial, procesando, exito, error }

// Subtextos rotativos durante el procesamiento
const _subtextos = [
  'Detectando tipo de prenda...',
  'Identificando color...',
  'Eliminando fondo...',
  'Guardando en tu armario...',
];

class AgregarPrendaScreen extends StatefulWidget {
  const AgregarPrendaScreen({super.key});

  @override
  State<AgregarPrendaScreen> createState() => _AgregarPrendaScreenState();
}

class _AgregarPrendaScreenState extends State<AgregarPrendaScreen>
    with SingleTickerProviderStateMixin {
  // ── Datos del formulario ────────────────────────────────────
  File? _imagenSeleccionada;
  String _temporadaSeleccionada = 'invierno';
  final _notasCtrl = TextEditingController();

  // ── Estado de la animación ──────────────────────────────────
  _Estado _estado = _Estado.inicial;
  PrendaModel? _prendaGuardada;
  String? _mensajeError;
  int _subtextoIndex = 0;
  Timer? _subtextoTimer;

  // Animación pulse para el ícono de camiseta
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    _subtextoTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Lógica de guardado ──────────────────────────────────────
  Future<void> _guardar() async {
    if (_imagenSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una imagen primero')),
      );
      return;
    }

    // Iniciar estado procesando + timer de subtextos
    setState(() {
      _estado = _Estado.procesando;
      _subtextoIndex = 0;
    });

    _subtextoTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() {
          _subtextoIndex = (_subtextoIndex + 1) % _subtextos.length;
        });
      }
    });

    final ctrl = context.read<GuardarropaController>();
    final prenda = await ctrl.agregarPrenda(
      imagen: _imagenSeleccionada!,
      temporada: _temporadaSeleccionada,
      notas: _notasCtrl.text.trim(),
    );

    _subtextoTimer?.cancel();
    if (!mounted) return;

    if (prenda != null) {
      setState(() {
        _estado = _Estado.exito;
        _prendaGuardada = prenda;
      });
      // Navegar al armario automáticamente después de 1.5 segundos
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      setState(() {
        _estado = _Estado.error;
        _mensajeError = ctrl.mensajeError ?? 'Error al guardar la prenda';
      });
    }
  }

  void _reintentar() {
    setState(() {
      _estado = _Estado.inicial;
      _mensajeError = null;
    });
  }

  // ── Build principal ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StyleMeTheme.background,
      appBar: _estado == _Estado.inicial || _estado == _Estado.error
          ? AppBar(
              title: const Text('Agregar prenda'),
              backgroundColor: StyleMeTheme.background,
            )
          : null,
      body: Stack(
        children: [
          // Formulario base (siempre presente debajo)
          _buildFormulario(),

          // Overlays según estado
          if (_estado == _Estado.procesando) _buildOverlayProcesando(),
          if (_estado == _Estado.exito) _buildOverlayExito(),
          if (_estado == _Estado.error) _buildOverlayError(),
        ],
      ),
    );
  }

  // ── Formulario ──────────────────────────────────────────────
  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de imagen
          Text(
            'Foto de la prenda',
            style: GoogleFonts.poppins(
              color: StyleMeTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          CameraWidget(
            imagenSeleccionada: _imagenSeleccionada,
            onImagenSeleccionada: (f) =>
                setState(() => _imagenSeleccionada = f),
          ),

          const SizedBox(height: 24),

          // Info sobre detección automática
          if (_imagenSeleccionada != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: StyleMeTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: StyleMeTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: StyleMeTheme.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'YOLOv8 detectará el tipo · KMeans el color · rembg eliminará el fondo',
                      style: GoogleFonts.poppins(
                          color: StyleMeTheme.textPrimary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Selector de temporada
          Text(
            'Temporada',
            style: GoogleFonts.poppins(
              color: StyleMeTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: AppConstants.temporadas.map((t) {
              final sel = t == _temporadaSeleccionada;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _temporadaSeleccionada = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: sel
                            ? StyleMeTheme.primary
                            : StyleMeTheme.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel
                              ? StyleMeTheme.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            AppConstants.temporadasIconos[t] ?? '',
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t,
                            style: GoogleFonts.poppins(
                              color: sel
                                  ? Colors.white
                                  : StyleMeTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Notas
          Text(
            'Notas (opcional)',
            style: GoogleFonts.poppins(
              color: StyleMeTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notasCtrl,
            maxLines: 2,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: 'Ej: Comprada en Zara, talla M...',
              hintStyle: GoogleFonts.poppins(fontSize: 13),
              counterStyle: GoogleFonts.poppins(
                  color: StyleMeTheme.textSecondary, fontSize: 11),
            ),
          ),

          const SizedBox(height: 32),

          // Botón guardar
          CustomButton(
            texto: 'Guardar en mi armario',
            onPressed: _estado == _Estado.inicial ? _guardar : null,
            icono: Icons.save,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Estado 1: PROCESANDO ────────────────────────────────────
  Widget _buildOverlayProcesando() {
    return Container(
      color: const Color(0xE60D0D0D), // negro 90% opacidad
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Imagen original con overlay oscuro encima
            if (_imagenSeleccionada != null)
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      _imagenSeleccionada!,
                      height: 220,
                      width: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Container(
                    height: 220,
                    width: 220,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  // Ícono pulse encima de la imagen
                  ScaleTransition(
                    scale: _pulseAnim,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _naranja.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _naranja.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.checkroom,
                        color: _naranja,
                        size: 48,
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 36),

            // Texto principal
            Text(
              'Analizando prenda...',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 10),

            // Subtexto animado (cambia cada 2s)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _subtextos[_subtextoIndex],
                key: ValueKey(_subtextoIndex),
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Barra de progreso naranja indeterminada
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: LinearProgressIndicator(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(_naranja),
                borderRadius: BorderRadius.circular(4),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Estado 2: ÉXITO ─────────────────────────────────────────
  Widget _buildOverlayExito() {
    final prenda = _prendaGuardada!;
    final urlImagen = '${ApiConfig.baseUrl}${prenda.imagenUrl}';

    return Container(
      color: const Color(0xFF0D0D0D),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícono de éxito con ScaleIn
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _naranja.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: _naranja, width: 2),
                ),
                child: const Icon(Icons.check, color: _naranja, size: 40),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Prenda agregada',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${prenda.tipo} · ${prenda.color}',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 28),

            // AnimatedSwitcher: imagen original → imagen procesada con fondo blanco
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: Container(
                key: const ValueKey('procesada'),
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _naranja, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: _naranja.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    urlImagen,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.file(
                      _imagenSeleccionada!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Volviendo al armario...',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Estado 3: ERROR ─────────────────────────────────────────
  Widget _buildOverlayError() {
    return Container(
      color: const Color(0xE60D0D0D),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícono de error
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.5), width: 2),
                ),
                child:
                    const Icon(Icons.close, color: Colors.red, size: 40),
              ),

              const SizedBox(height: 20),

              Text(
                'Algo salió mal',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _mensajeError ?? 'Error desconocido',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 32),

              // Botón reintentar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _reintentar,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: Text(
                    'Reintentar',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _naranja,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

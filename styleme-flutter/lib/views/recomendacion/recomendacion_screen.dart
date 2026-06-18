// StyleMe - Pantalla de Recomendación de Outfits
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:styleme/config/constants.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/guardarropa_controller.dart';
import 'package:styleme/controllers/historial_controller.dart';
import 'package:styleme/controllers/recomendacion_controller.dart';
import 'package:styleme/models/prenda_model.dart';
import 'package:styleme/widgets/custom_button.dart';
import 'package:styleme/widgets/loading_widget.dart';
import 'package:styleme/widgets/outfit_visual_card.dart';
import 'package:styleme/widgets/prenda_card.dart';

class RecomendacionScreen extends StatefulWidget {
  final PrendaModel? prendaInicial;

  const RecomendacionScreen({super.key, this.prendaInicial});

  @override
  State<RecomendacionScreen> createState() => _RecomendacionScreenState();
}

class _RecomendacionScreenState extends State<RecomendacionScreen> {
  PrendaModel? _prendaSeleccionada;
  String _temporadaSeleccionada = 'invierno';

  @override
  void initState() {
    super.initState();
    _prendaSeleccionada = widget.prendaInicial;

    // Cargar prendas si no están cargadas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<GuardarropaController>();
      if (ctrl.prendas.isEmpty) ctrl.cargarPrendas(resetear: true);
    });
  }

  Future<void> _generarOutfit() async {
    if (_prendaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una prenda base')),
      );
      return;
    }

    final recCtrl = context.read<RecomendacionController>();
    await recCtrl.generarOutfit(
      prendaId: _prendaSeleccionada!.id,
      temporada: _temporadaSeleccionada,
    );
  }

  @override
  Widget build(BuildContext context) {
    final recCtrl = context.watch<RecomendacionController>();
    final guardCtrl = context.watch<GuardarropaController>();
    final cargando = recCtrl.estaCargando;

    return LoadingOverlay(
      cargando: cargando,
      mensaje: 'Calculando compatibilidad...',
      child: Scaffold(
        backgroundColor: StyleMeTheme.background,
        appBar: AppBar(
          title: const Text('Crear outfit'),
          backgroundColor: StyleMeTheme.background,
          actions: [
            if (recCtrl.outfitActual != null)
              IconButton(
                icon: const Icon(Icons.refresh, color: StyleMeTheme.primary),
                onPressed: _generarOutfit,
                tooltip: 'Regenerar',
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selector de prenda base
              Text(
                'Prenda base',
                style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              if (guardCtrl.prendas.isEmpty)
                _emptyState()
              else
                _buildSelectorPrendas(guardCtrl),

              const SizedBox(height: 24),

              // Selector de temporada
              Text(
                'Temporada',
                style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Row(
                children: AppConstants.temporadas.map((t) {
                  final sel = t == _temporadaSeleccionada;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _temporadaSeleccionada = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: sel ? StyleMeTheme.primary : StyleMeTheme.card,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(AppConstants.temporadasIconos[t] ?? '', style: const TextStyle(fontSize: 18)),
                              const SizedBox(height: 2),
                              Text(t, style: GoogleFonts.poppins(
                                color: sel ? Colors.white : StyleMeTheme.textSecondary,
                                fontSize: 9,
                                fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                              ), textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),

              // Botón generar
              CustomButton(
                texto: 'Generar outfit',
                onPressed: (_prendaSeleccionada != null && !cargando) ? _generarOutfit : null,
                icono: Icons.auto_awesome,
              ),

              // Resultado del outfit con animación slide-up
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.12),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: recCtrl.outfitActual != null
                    ? Column(
                        key: ValueKey(recCtrl.outfitActual!.id),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 28),
                          Text(
                            'Tu outfit',
                            style: GoogleFonts.poppins(
                              color: StyleMeTheme.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutfitVisualCard.fromOutfitModel(
                            outfit: recCtrl.outfitActual!,
                            onFeedback: (tipo) =>
                                _darFeedback(context, recCtrl.outfitActual!.id, tipo),
                            titulo: 'Tu outfit de hoy',
                          ),
                        ],
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),

              // Error
              if (recCtrl.estado == RecomendacionEstado.error && recCtrl.mensajeError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: StyleMeTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      recCtrl.mensajeError!,
                      style: GoogleFonts.poppins(color: StyleMeTheme.error, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      height: 100,
      decoration: BoxDecoration(color: StyleMeTheme.card, borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Text(
          'Agrega prendas a tu armario primero',
          style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildSelectorPrendas(GuardarropaController ctrl) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: ctrl.prendas.length,
        itemBuilder: (_, i) {
          final prenda = ctrl.prendas[i];
          return SizedBox(
            width: 120,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: PrendaCard(
                prenda: prenda,
                seleccionada: _prendaSeleccionada?.id == prenda.id,
                onTap: () => setState(() => _prendaSeleccionada = prenda),
              ),
            ),
          );
        },
      ),
    );
  }

  void _darFeedback(BuildContext context, String outfitId, String tipo) {
    context.read<HistorialController>().darFeedback(outfitId, tipo);
    final msg = tipo == 'liked' ? '❤️ ¡Me gusta!' : tipo == 'saved' ? '🔖 Guardado' : '✕ Descartado';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }
}

// StyleMe - Pantalla del Historial de Outfits
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/historial_controller.dart';
import 'package:styleme/models/feedback_model.dart';
import 'package:styleme/widgets/outfit_card.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistorialController>().cargarHistorial();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<HistorialController>();

    return Scaffold(
      backgroundColor: StyleMeTheme.background,
      appBar: AppBar(
        backgroundColor: StyleMeTheme.background,
        title: Column(
          children: [
            Text('Historial', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('${ctrl.total} outfits', style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 12)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filtros de tabs
          _buildFiltrosTabs(ctrl),
          const SizedBox(height: 4),
          // Lista de outfits
          Expanded(child: _buildLista(ctrl)),
        ],
      ),
    );
  }

  Widget _buildFiltrosTabs(HistorialController ctrl) {
    final filtros = [
      ('Todos', 'all', Icons.grid_view),
      ('Me gusta', 'liked', Icons.favorite),
      ('Guardados', 'saved', Icons.bookmark),
      ('No gusta', 'disliked', Icons.close),
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: filtros.map((f) {
          final activo = ctrl.filtroActivo == f.$2;
          return Expanded(
            child: GestureDetector(
              onTap: () => ctrl.cargarHistorial(filtro: f.$2, resetear: true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: activo ? StyleMeTheme.primary : StyleMeTheme.card,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(f.$3, size: 14, color: activo ? Colors.white : StyleMeTheme.textSecondary),
                    const SizedBox(height: 2),
                    Text(
                      f.$1,
                      style: GoogleFonts.poppins(
                        color: activo ? Colors.white : StyleMeTheme.textSecondary,
                        fontSize: 9,
                        fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLista(HistorialController ctrl) {
    if (ctrl.estado == HistorialEstado.cargando) {
      return const Center(child: CircularProgressIndicator(color: StyleMeTheme.primary));
    }

    if (ctrl.outfits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, color: StyleMeTheme.textSecondary, size: 48),
            const SizedBox(height: 12),
            Text(
              ctrl.filtroActivo == 'all' ? 'Sin outfits en el historial' : 'Sin outfits con este filtro',
              style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: StyleMeTheme.primary,
      onRefresh: () => ctrl.cargarHistorial(filtro: ctrl.filtroActivo, resetear: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: ctrl.outfits.length,
        itemBuilder: (_, i) {
          final outfit = ctrl.outfits[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Dismissible(
              key: Key(outfit.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: StyleMeTheme.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_outline, color: StyleMeTheme.error),
              ),
              confirmDismiss: (_) => _confirmarEliminar(context),
              onDismissed: (_) => ctrl.eliminarOutfit(outfit.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fecha y feedback badge
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatearFecha(outfit.generadoEn),
                          style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 11),
                        ),
                        if (outfit.feedback != 'none')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _colorFeedback(outfit.feedback).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${FeedbackModel.emoji(outfit.feedback)} ${FeedbackModel.texto(outfit.feedback)}',
                              style: GoogleFonts.poppins(color: _colorFeedback(outfit.feedback), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                  OutfitCard(
                    outfit: outfit,
                    onLike: () => ctrl.darFeedback(outfit.id, 'liked'),
                    onSave: () => ctrl.darFeedback(outfit.id, 'saved'),
                    onDislike: () => ctrl.darFeedback(outfit.id, 'disliked'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _confirmarEliminar(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: StyleMeTheme.surface,
            title: Text('Eliminar outfit', style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary)),
            content: Text('¿Eliminar este outfit del historial?', style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar', style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary))),
              TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Eliminar', style: GoogleFonts.poppins(color: StyleMeTheme.error, fontWeight: FontWeight.w600))),
            ],
          ),
        ) ??
        false;
  }

  Color _colorFeedback(String f) {
    if (f == 'liked') return StyleMeTheme.success;
    if (f == 'saved') return StyleMeTheme.accent;
    if (f == 'disliked') return StyleMeTheme.error;
    return StyleMeTheme.textSecondary;
  }

  String _formatearFecha(String fecha) {
    if (fecha.isEmpty) return '';
    try {
      final dt = DateTime.parse(fecha);
      final ahora = DateTime.now();
      final diff = ahora.difference(dt);
      if (diff.inDays == 0) return 'Hoy';
      if (diff.inDays == 1) return 'Ayer';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return fecha;
    }
  }
}

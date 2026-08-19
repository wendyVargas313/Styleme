// StyleMe - Pantalla de Historial de Recomendaciones para Eventos (banco de pruebas)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:styleme/app/routes.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/agente_evento_controller.dart';
import 'package:styleme/models/recomendacion_evento_model.dart';
import 'package:styleme/widgets/custom_button.dart';
import 'package:styleme/widgets/loading_widget.dart';

class HistorialEventosScreen extends StatefulWidget {
  const HistorialEventosScreen({super.key});

  @override
  State<HistorialEventosScreen> createState() => _HistorialEventosScreenState();
}

class _HistorialEventosScreenState extends State<HistorialEventosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AgenteEventoController>().cargarHistorial();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AgenteEventoController>();

    return Scaffold(
      backgroundColor: StyleMeTheme.background,
      appBar: AppBar(
        backgroundColor: StyleMeTheme.surface,
        elevation: 0,
        title: Text(
          'Mis recomendaciones',
          style: GoogleFonts.poppins(
            color: StyleMeTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(child: _buildContenido(ctrl)),
    );
  }

  Widget _buildContenido(AgenteEventoController ctrl) {
    if (ctrl.estadoHistorial == HistorialEstado.cargando) {
      return const LoadingWidget(mensaje: 'Cargando historial...');
    }

    if (ctrl.estadoHistorial == HistorialEstado.error) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            Text(
              ctrl.mensajeErrorHistorial ?? 'Error desconocido',
              style: GoogleFonts.poppins(color: StyleMeTheme.error, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CustomButton(
              texto: 'Reintentar',
              onPressed: () => ctrl.cargarHistorial(),
            ),
          ],
        ),
      );
    }

    if (ctrl.estadoHistorial == HistorialEstado.listo && ctrl.historial.isEmpty) {
      return _buildVacio(context);
    }

    final hayMasPorMostrar = ctrl.totalHistorial > ctrl.historial.length;

    return RefreshIndicator(
      onRefresh: () => ctrl.cargarHistorial(),
      color: StyleMeTheme.primary,
      backgroundColor: StyleMeTheme.card,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: ctrl.historial.length + (hayMasPorMostrar ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == ctrl.historial.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Mostrando ${ctrl.historial.length} de ${ctrl.totalHistorial}',
                style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            );
          }
          return _buildCard(context, ctrl.historial[i]);
        },
      ),
    );
  }

  Widget _buildVacio(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_note, color: StyleMeTheme.textSecondary, size: 56),
            const SizedBox(height: 16),
            Text(
              'Aún no has generado recomendaciones',
              style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CustomButton(
              texto: 'Generar recomendación',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.agenteEvento),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, RecomendacionResumen r) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.detalleRecomendacion,
        arguments: r.id,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: StyleMeTheme.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.descripcionEvento,
              style: GoogleFonts.poppins(
                color: StyleMeTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${r.lugar} · ${r.fecha}',
              style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatearCreadoEn(r.creadoEn),
                  style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 11),
                ),
                Text(
                  '${r.totalOutfits} outfits',
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatearCreadoEn(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }
}

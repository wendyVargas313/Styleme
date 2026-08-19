// StyleMe - Pantalla de Recomendación de Outfits para Eventos (banco de pruebas)
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
import 'package:styleme/widgets/recomendacion_evento_view.dart';

class AgenteEventoScreen extends StatefulWidget {
  const AgenteEventoScreen({super.key});

  @override
  State<AgenteEventoScreen> createState() => _AgenteEventoScreenState();
}

class _AgenteEventoScreenState extends State<AgenteEventoScreen> {
  final _descripcionCtrl = TextEditingController();
  final _lugarCtrl = TextEditingController();
  DateTime? _fechaSeleccionada;

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _lugarCtrl.dispose();
    super.dispose();
  }

  bool get _formularioValido =>
      _descripcionCtrl.text.trim().isNotEmpty &&
      _lugarCtrl.text.trim().isNotEmpty &&
      _fechaSeleccionada != null;

  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada ?? hoy,
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 365)),
    );
    if (fecha != null) {
      setState(() => _fechaSeleccionada = fecha);
    }
  }

  Future<void> _generar() async {
    await context.read<AgenteEventoController>().recomendarParaEvento(
          descripcionEvento: _descripcionCtrl.text.trim(),
          lugar: _lugarCtrl.text.trim(),
          fecha: DateFormat('yyyy-MM-dd').format(_fechaSeleccionada!),
        );
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
          'Recomendación para evento',
          style: GoogleFonts.poppins(
            color: StyleMeTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: StyleMeTheme.textPrimary),
            tooltip: 'Mis recomendaciones',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.historialEventos),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildContenido(ctrl),
        ),
      ),
    );
  }

  Widget _buildContenido(AgenteEventoController ctrl) {
    if (ctrl.estado == AgenteEventoEstado.cargando) {
      return const LoadingWidget(
        mensaje: 'Consultando el clima y generando outfits...',
      );
    }

    if (ctrl.estado == AgenteEventoEstado.error) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            Text(
              ctrl.mensajeError ?? 'Error desconocido',
              style: GoogleFonts.poppins(color: StyleMeTheme.error, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CustomButton(
              texto: 'Reintentar',
              onPressed: _generar,
            ),
          ],
        ),
      );
    }

    if (ctrl.estado == AgenteEventoEstado.listo && ctrl.recomendacion != null) {
      return _buildResultado(ctrl.recomendacion!);
    }

    return _buildFormulario(ctrl);
  }

  Widget _buildFormulario(AgenteEventoController ctrl) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Descripción del evento',
            style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descripcionCtrl,
            maxLines: 4,
            style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Ej: Entrevista de trabajo formal',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Text(
            'Lugar',
            style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _lugarCtrl,
            style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Ej: Bogotá',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Text(
            'Fecha',
            style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _seleccionarFecha,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: StyleMeTheme.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: StyleMeTheme.textSecondary, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    _fechaSeleccionada != null
                        ? DateFormat('dd/MM/yyyy').format(_fechaSeleccionada!)
                        : 'Selecciona una fecha',
                    style: GoogleFonts.poppins(
                      color: _fechaSeleccionada != null
                          ? StyleMeTheme.textPrimary
                          : StyleMeTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          CustomButton(
            texto: 'Generar recomendación',
            onPressed: (_formularioValido && ctrl.estado != AgenteEventoEstado.cargando)
                ? _generar
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildResultado(RecomendacionEvento rec) {
    return SingleChildScrollView(
      child: RecomendacionEventoView(
        recomendacion: rec,
        recomendacionId: rec.id,
        footer: CustomButton(
          texto: 'Nueva búsqueda',
          outline: true,
          onPressed: () => context.read<AgenteEventoController>().limpiar(),
        ),
      ),
    );
  }
}

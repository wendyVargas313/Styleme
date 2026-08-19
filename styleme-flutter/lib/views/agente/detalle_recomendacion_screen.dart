// StyleMe - Pantalla de Detalle de una Recomendación del Historial
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/agente_evento_controller.dart';
import 'package:styleme/models/recomendacion_evento_model.dart';
import 'package:styleme/widgets/custom_button.dart';
import 'package:styleme/widgets/loading_widget.dart';
import 'package:styleme/widgets/recomendacion_evento_view.dart';

class DetalleRecomendacionScreen extends StatefulWidget {
  final String id;

  const DetalleRecomendacionScreen({super.key, required this.id});

  @override
  State<DetalleRecomendacionScreen> createState() => _DetalleRecomendacionScreenState();
}

class _DetalleRecomendacionScreenState extends State<DetalleRecomendacionScreen> {
  late final Future<RecomendacionEvento?> _futureDetalle;

  @override
  void initState() {
    super.initState();
    _futureDetalle = context.read<AgenteEventoController>().cargarDetalle(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StyleMeTheme.background,
      appBar: AppBar(
        backgroundColor: StyleMeTheme.surface,
        elevation: 0,
        title: Text(
          'Detalle de recomendación',
          style: GoogleFonts.poppins(
            color: StyleMeTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<RecomendacionEvento?>(
            future: _futureDetalle,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingWidget(mensaje: 'Cargando recomendación...');
              }

              final rec = snapshot.data;
              if (rec == null) {
                return _buildError(context);
              }

              return SingleChildScrollView(
                child: RecomendacionEventoView(recomendacion: rec, recomendacionId: widget.id),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final mensaje = context.read<AgenteEventoController>().mensajeErrorDetalle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        Text(
          mensaje ?? 'No se pudo cargar la recomendación',
          style: GoogleFonts.poppins(color: StyleMeTheme.error, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        CustomButton(
          texto: 'Volver',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

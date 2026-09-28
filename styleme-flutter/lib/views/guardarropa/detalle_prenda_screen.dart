// StyleMe - Pantalla de detalle de una prenda
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:styleme/app/routes.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/config/constants.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/guardarropa_controller.dart';
import 'package:styleme/models/prenda_model.dart';
import 'package:styleme/widgets/editar_prenda_sheet.dart';

class DetallePrendaScreen extends StatefulWidget {
  final PrendaModel prenda;

  const DetallePrendaScreen({super.key, required this.prenda});

  @override
  State<DetallePrendaScreen> createState() => _DetallePrendaScreenState();
}

class _DetallePrendaScreenState extends State<DetallePrendaScreen> {
  // Se reemplaza tras una edición para que el detalle se vea actualizado sin
  // volver al armario.
  late PrendaModel _prenda = widget.prenda;

  Future<void> _editar() async {
    final editada = await EditarPrendaSheet.mostrar(context, _prenda);
    if (editada == null || !mounted) return;
    setState(() => _prenda = editada);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prenda actualizada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prenda = _prenda;
    return Scaffold(
      backgroundColor: StyleMeTheme.background,
      body: CustomScrollView(
        slivers: [
          // Imagen grande con AppBar superpuesto
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: StyleMeTheme.background,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: prenda.imagenUrlCompleta(ApiConfig.baseUrl),
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: StyleMeTheme.surface,
                      child: const Icon(Icons.checkroom, size: 80, color: StyleMeTheme.textSecondary),
                    ),
                  ),
                  // Gradiente oscuro en la parte inferior
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, StyleMeTheme.background],
                        stops: [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Información de la prenda
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (prenda.requiereRevision) ...[
                  _avisoRevision(),
                  const SizedBox(height: 16),
                ],
                // Nombre del tipo
                Text(
                  AppConstants.etiquetaTipo(prenda.tipo),
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                // Chips de info
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(prenda.color, Icons.palette, StyleMeTheme.primary),
                    _chip(
                      '${AppConstants.iconoMomento(prenda.momento)} ${AppConstants.etiquetaMomento(prenda.momento)}',
                      Icons.wb_sunny_outlined,
                      StyleMeTheme.accent,
                    ),
                    _chip('${prenda.vecesUsado} uso${prenda.vecesUsado != 1 ? 's' : ''}', Icons.replay, StyleMeTheme.textSecondary),
                  ],
                ),
                const SizedBox(height: 20),

                // Detalles adicionales
                _infoCard('Información de la prenda', [
                  ('Tipo', AppConstants.etiquetaTipo(prenda.tipo)),
                  ('Color predominante', prenda.color),
                  ('Clima', AppConstants.etiquetaMomento(prenda.momento)),
                  ('Agregada', _formatearFecha(prenda.creadoEn)),
                ]),

                if (prenda.notas.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _infoCard('Notas', [('', prenda.notas)]),
                ],

                const SizedBox(height: 28),

                // Botón crear outfit
                _botonAccion(
                  context,
                  texto: 'Crear outfit con esta prenda',
                  icono: Icons.auto_awesome,
                  color: StyleMeTheme.primary,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.recomendacion,
                    arguments: prenda,
                  ),
                ),
                const SizedBox(height: 12),

                // Botón editar
                _botonAccion(
                  context,
                  texto: 'Editar prenda',
                  icono: Icons.edit_outlined,
                  color: StyleMeTheme.primary,
                  onTap: _editar,
                  outline: true,
                ),
                const SizedBox(height: 12),

                // Botón eliminar
                _botonAccion(
                  context,
                  texto: 'Eliminar prenda',
                  icono: Icons.delete_outline,
                  color: StyleMeTheme.error,
                  onTap: () => _confirmarEliminar(context),
                  outline: true,
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avisoRevision() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: StyleMeTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StyleMeTheme.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: StyleMeTheme.warning, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'La IA no está segura de esta prenda. Revisa el tipo y el color.',
              style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _editar,
            child: Text(
              'Editar',
              style: GoogleFonts.poppins(color: StyleMeTheme.warning, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String texto, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: color, size: 14),
          const SizedBox(width: 6),
          Text(texto, style: GoogleFonts.poppins(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _infoCard(String titulo, List<(String, String)> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StyleMeTheme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          ...items.map((item) {
            if (item.$1.isEmpty) {
              return Text(item.$2, style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 14));
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.$1, style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13)),
                  Text(item.$2, style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _botonAccion(
    BuildContext context, {
    required String texto,
    required IconData icono,
    required Color color,
    required VoidCallback onTap,
    bool outline = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: outline ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(12),
          border: outline ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: outline ? color : Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(texto, style: GoogleFonts.poppins(color: outline ? color : Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminar(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: StyleMeTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar prenda', style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('¿Seguro que quieres eliminar "${AppConstants.etiquetaTipo(_prenda.tipo)}"? Esta acción no se puede deshacer.',
            style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Cerrar dialog
              final ctrl = context.read<GuardarropaController>();
              final ok = await ctrl.eliminarPrenda(_prenda.id);
              if (context.mounted) {
                Navigator.pop(context); // Volver al guardarropa
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Prenda eliminada')),
                  );
                }
              }
            },
            child: Text('Eliminar', style: GoogleFonts.poppins(color: StyleMeTheme.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(String fecha) {
    if (fecha.isEmpty) return '';
    try {
      final dt = DateTime.parse(fecha);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return fecha;
    }
  }
}

// StyleMe - Card de prenda para el guardarropa
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/config/constants.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/models/prenda_model.dart';

class PrendaCard extends StatelessWidget {
  final PrendaModel prenda;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEliminar;
  final bool seleccionada;
  // Modo selección activo: las no marcadas muestran un círculo vacío.
  final bool enSeleccion;
  // Tarjeta pequeña (3–4 columnas): mismos datos con tamaños reducidos.
  final bool compacta;
  // Tarjeta muy pequeña (6+ columnas): solo la imagen, sin textos ni insignias.
  final bool soloImagen;

  const PrendaCard({
    super.key,
    required this.prenda,
    this.onTap,
    this.onLongPress,
    this.onEliminar,
    this.seleccionada = false,
    this.enSeleccion = false,
    this.compacta = false,
    this.soloImagen = false,
  });

  double get _radio => soloImagen ? 6 : (compacta ? 12 : 16);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: StyleMeTheme.card,
          borderRadius: BorderRadius.circular(_radio),
          border: seleccionada
              ? Border.all(color: StyleMeTheme.primary, width: 2)
              : Border.all(color: Colors.transparent),
          boxShadow: soloImagen
              ? null
              : (seleccionada ? StyleMeTheme.sombraNaranja : StyleMeTheme.sombraCard),
        ),
        child: soloImagen ? _buildSoloImagen() : _buildCompleta(),
      ),
    );
  }

  Widget _buildSoloImagen() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_radio - 1),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildImagen(),
          Positioned(top: 3, left: 3, child: _marcaSeleccion(11)),
        ],
      ),
    );
  }

  Widget _buildCompleta() {
    final margen = compacta ? 4.0 : 8.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Imagen de la prenda
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(_radio)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildImagen(),
                // Badge de confianza
                Positioned(
                  top: margen,
                  right: margen,
                  child: Container(
                    padding: compacta
                        ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1)
                        : const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(compacta ? 6 : 8),
                    ),
                    child: Text(
                      prenda.confianzaTexto,
                      style: GoogleFonts.poppins(
                        color: StyleMeTheme.primary,
                        fontSize: compacta ? 8.5 : 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: margen,
                  left: margen,
                  child: _marcaSeleccion(compacta ? 11 : 14),
                ),
              ],
            ),
          ),
        ),
        // Info de la prenda
        Padding(
          padding: EdgeInsets.all(compacta ? 6 : 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConstants.etiquetaTipo(prenda.tipo),
                style: GoogleFonts.poppins(
                  color: StyleMeTheme.textPrimary,
                  fontSize: compacta ? 11 : 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: compacta ? 2 : 6),
              compacta ? _filaCompacta() : _filaChips(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filaChips() {
    return Row(
      children: [
        Flexible(
          child: _chip(prenda.color, StyleMeTheme.primary.withValues(alpha: 0.2)),
        ),
        const SizedBox(width: 4),
        _chip(AppConstants.iconoMomento(prenda.momento), StyleMeTheme.card),
      ],
    );
  }

  // Sin fondos de chip: en 3–4 columnas el ícono doble ☀️🌧️ más un chip de
  // color no caben; el color cede espacio (se recorta) y el clima siempre se ve.
  Widget _filaCompacta() {
    final estilo = GoogleFonts.poppins(
      color: StyleMeTheme.textSecondary,
      fontSize: 9.5,
      fontWeight: FontWeight.w500,
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            prenda.color,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: estilo,
          ),
        ),
        const SizedBox(width: 2),
        Text(AppConstants.iconoMomento(prenda.momento), style: estilo),
      ],
    );
  }

  Widget _marcaSeleccion(double tam) {
    if (seleccionada) {
      return Container(
        padding: EdgeInsets.all(tam * 0.25),
        decoration: const BoxDecoration(
          color: StyleMeTheme.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check, color: Colors.white, size: tam),
      );
    }
    if (enSeleccion) {
      return Container(
        width: tam * 1.5,
        height: tam * 1.5,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildImagen() {
    final url = prenda.imagenUrlCompleta(ApiConfig.baseUrl);
    final tamIcono = soloImagen ? 16.0 : (compacta ? 24.0 : 36.0);
    Widget respaldo(BuildContext _) => Container(
          color: StyleMeTheme.surface,
          child: Center(
            child: Icon(Icons.checkroom, color: StyleMeTheme.textSecondary, size: tamIcono),
          ),
        );
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (c, __) => respaldo(c),
      errorWidget: (c, __, ___) => respaldo(c),
    );
  }

  Widget _chip(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          color: StyleMeTheme.textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

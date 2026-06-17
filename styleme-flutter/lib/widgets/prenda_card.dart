// StyleMe - Card de prenda para el guardarropa
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/models/prenda_model.dart';

class PrendaCard extends StatelessWidget {
  final PrendaModel prenda;
  final VoidCallback? onTap;
  final VoidCallback? onEliminar;
  final bool seleccionada;

  const PrendaCard({
    super.key,
    required this.prenda,
    this.onTap,
    this.onEliminar,
    this.seleccionada = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: StyleMeTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: seleccionada
              ? Border.all(color: StyleMeTheme.primary, width: 2)
              : Border.all(color: Colors.transparent),
          boxShadow: seleccionada ? StyleMeTheme.sombraNaranja : StyleMeTheme.sombraCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen de la prenda
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImagen(),
                    // Badge de confianza
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          prenda.confianzaTexto,
                          style: GoogleFonts.poppins(
                            color: StyleMeTheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // Icono de seleccionada
                    if (seleccionada)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: StyleMeTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Info de la prenda
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prenda.tipo,
                    style: GoogleFonts.poppins(
                      color: StyleMeTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _chip(prenda.color, StyleMeTheme.primary.withValues(alpha: 0.2)),
                      const SizedBox(width: 4),
                      _chip(_temporadaEmoji(prenda.temporada), StyleMeTheme.card),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagen() {
    final url = prenda.imagenUrlCompleta(ApiConfig.baseUrl);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: StyleMeTheme.surface,
        child: const Center(
          child: Icon(Icons.checkroom, color: StyleMeTheme.textSecondary, size: 36),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: StyleMeTheme.surface,
        child: const Center(
          child: Icon(Icons.checkroom, color: StyleMeTheme.textSecondary, size: 36),
        ),
      ),
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
        style: GoogleFonts.poppins(
          color: StyleMeTheme.textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _temporadaEmoji(String temporada) {
    const emojis = {
      'primavera': '🌸',
      'verano': '☀️',
      'otono': '🍂',
      'invierno': '❄️',
    };
    return emojis[temporada] ?? temporada;
  }
}

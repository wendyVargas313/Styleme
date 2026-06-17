// StyleMe - Card de outfit para recomendaciones e historial
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/models/outfit_model.dart';
import 'package:styleme/models/prenda_model.dart';

class OutfitCard extends StatelessWidget {
  final OutfitModel outfit;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onDislike;
  final bool mostrarFeedback;

  const OutfitCard({
    super.key,
    required this.outfit,
    this.onLike,
    this.onSave,
    this.onDislike,
    this.mostrarFeedback = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: StyleMeTheme.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: StyleMeTheme.sombraCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prenda base
          if (outfit.prendaBase != null)
            _buildPrendaBase(outfit.prendaBase!),

          const Divider(height: 1),

          // Complementos
          if (outfit.complementos.isNotEmpty)
            _buildComplementos(),

          // Botones de feedback
          if (mostrarFeedback) _buildFeedbackButtons(),
        ],
      ),
    );
  }

  Widget _buildPrendaBase(PrendaModel prenda) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 70,
              height: 70,
              child: CachedNetworkImage(
                imageUrl: prenda.imagenUrlCompleta(ApiConfig.baseUrl),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: StyleMeTheme.surface,
                  child: const Icon(Icons.checkroom, color: StyleMeTheme.textSecondary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: StyleMeTheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'BASE',
                        style: GoogleFonts.poppins(
                          color: StyleMeTheme.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  prenda.tipo,
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${prenda.color} • ${prenda.temporada}',
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplementos() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Complementos sugeridos',
            style: GoogleFonts.poppins(
              color: StyleMeTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...outfit.complementos.map((comp) => _buildComplementoItem(comp)),
        ],
      ),
    );
  }

  Widget _buildComplementoItem(ComplementoOutfit comp) {
    // Convertir score a color
    final score = comp.score;
    final color = score > 0.7
        ? StyleMeTheme.success
        : score > 0.5
            ? StyleMeTheme.primary
            : StyleMeTheme.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: CachedNetworkImage(
                imageUrl: comp.prenda.imagenUrlCompleta(ApiConfig.baseUrl),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: StyleMeTheme.surface,
                  child: const Icon(Icons.checkroom, size: 20, color: StyleMeTheme.textSecondary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comp.prenda.tipo,
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  comp.prenda.color,
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Score badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              comp.porcentaje,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackButtons() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _feedbackBtn(
            icono: Icons.close,
            color: StyleMeTheme.error,
            activo: outfit.esDisliked,
            onTap: onDislike,
            tooltip: 'No me gusta',
          ),
          _feedbackBtn(
            icono: Icons.bookmark_border,
            color: StyleMeTheme.accent,
            activo: outfit.esSaved,
            onTap: onSave,
            tooltip: 'Guardar',
          ),
          _feedbackBtn(
            icono: Icons.favorite_border,
            color: StyleMeTheme.success,
            activo: outfit.esLiked,
            onTap: onLike,
            tooltip: 'Me gusta',
          ),
        ],
      ),
    );
  }

  Widget _feedbackBtn({
    required IconData icono,
    required Color color,
    required bool activo,
    VoidCallback? onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: activo ? color.withValues(alpha: 0.2) : StyleMeTheme.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(
            activo ? _iconoActivo(icono) : icono,
            color: activo ? color : StyleMeTheme.textSecondary,
            size: 22,
          ),
        ),
      ),
    );
  }

  IconData _iconoActivo(IconData icono) {
    if (icono == Icons.favorite_border) return Icons.favorite;
    if (icono == Icons.bookmark_border) return Icons.bookmark;
    return icono;
  }
}

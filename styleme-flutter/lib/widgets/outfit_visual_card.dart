// StyleMe - Widget visual de outfit con grid de prendas reales
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/models/outfit_model.dart';

class OutfitVisualCard extends StatelessWidget {
  final Map<String, dynamic> prendaBase;
  final List<Map<String, dynamic>> complementos;
  final Function(String)? onFeedback;
  final String? feedbackActual;
  final bool modoCompacto;
  final String titulo;

  const OutfitVisualCard({
    super.key,
    required this.prendaBase,
    required this.complementos,
    this.onFeedback,
    this.feedbackActual,
    this.modoCompacto = false,
    this.titulo = 'Tu outfit ✨',
  });

  // Factory para OutfitModel (usuarios registrados)
  factory OutfitVisualCard.fromOutfitModel({
    Key? key,
    required OutfitModel outfit,
    Function(String)? onFeedback,
    bool modoCompacto = false,
    String titulo = 'Tu outfit ✨',
  }) {
    final base = outfit.prendaBase != null
        ? {
            'tipo': outfit.prendaBase!.tipo,
            'color': outfit.prendaBase!.color,
            'confianza': outfit.prendaBase!.confianzaYolo,
            'imagen_url': outfit.prendaBase!.imagenUrlCompleta(ApiConfig.baseUrl),
          }
        : <String, dynamic>{};

    final comps = outfit.complementos
        .map((c) => {
              'tipo': c.prenda.tipo,
              'color': c.prenda.color,
              'score': c.score,
              'imagen_url': c.prenda.imagenUrlCompleta(ApiConfig.baseUrl),
            })
        .toList();

    return OutfitVisualCard(
      key: key,
      prendaBase: base,
      complementos: comps,
      onFeedback: onFeedback,
      feedbackActual: outfit.feedback,
      modoCompacto: modoCompacto,
      titulo: titulo,
    );
  }

  double get _scorePromedio {
    if (complementos.isEmpty) return (prendaBase['confianza'] as num?)?.toDouble() ?? 0.0;
    final sum = complementos.fold<double>(
        0, (acc, c) => acc + ((c['score'] as num?)?.toDouble() ?? 0.0));
    return sum / complementos.length;
  }

  Color _colorParaNombre(String nombre) {
    const mapa = {
      'negro': Color(0xFF1A1A1A),
      'blanco': Color(0xFFF5F5F5),
      'gris': Color(0xFF808080),
      'rojo': Color(0xFFE53935),
      'rosa': Color(0xFFEC407A),
      'azul': Color(0xFF1E88E5),
      'azul marino': Color(0xFF1A237E),
      'verde': Color(0xFF43A047),
      'amarillo': Color(0xFFFDD835),
      'naranja': Color(0xFFFF6B00),
      'morado': Color(0xFF8E24AA),
      'beige': Color(0xFFF5DEB3),
      'cafe': Color(0xFF795548),
    };
    return mapa[nombre.toLowerCase()] ?? StyleMeTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return modoCompacto ? _buildCompacto() : _buildCompleto(context);
  }

  // ── Card completa ────────────────────────────────────────
  Widget _buildCompleto(BuildContext context) {
    final todasLasPrendas = [prendaBase, ...complementos];
    final score = _scorePromedio;
    final pct = (score * 100).toStringAsFixed(1);
    final scoreColor = score >= 0.6 ? StyleMeTheme.primary : StyleMeTheme.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: StyleMeTheme.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: StyleMeTheme.sombraCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: StyleMeTheme.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: GoogleFonts.poppins(
                      color: StyleMeTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scoreColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$pct%',
                    style: GoogleFonts.poppins(
                      color: scoreColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Grid de prendas ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildGrid(todasLasPrendas),
          ),
          const SizedBox(height: 14),

          // ── Barra de compatibilidad ──────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Compatibilidad del conjunto',
                      style: GoogleFonts.poppins(
                          color: StyleMeTheme.textSecondary, fontSize: 11),
                    ),
                    Text(
                      '$pct%',
                      style: GoogleFonts.poppins(
                          color: scoreColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score.clamp(0.0, 1.0),
                    backgroundColor: StyleMeTheme.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          // ── Botones de feedback ──────────────────────────
          if (onFeedback != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            _buildFeedbackButtons(),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Grid 2 columnas ──────────────────────────────────────
  Widget _buildGrid(List<Map<String, dynamic>> prendas) {
    final items = prendas.take(4).toList();

    return Column(
      children: [
        // Primera fila (siempre visible)
        Row(
          children: [
            Expanded(
              child: _buildPrendaItem(
                  items.isNotEmpty ? items[0] : {}, isBase: true),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildPrendaItem(
                  items.length > 1 ? items[1] : {}, isBase: false),
            ),
          ],
        ),
        // Segunda fila (si hay más de 2 prendas)
        if (items.length > 2) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildPrendaItem(items[2], isBase: false),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPrendaItem(
                    items.length > 3 ? items[3] : {}, isBase: false),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPrendaItem(Map<String, dynamic> p, {required bool isBase}) {
    if (p.isEmpty) {
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    final tipo = (p['tipo'] as String? ?? '').replaceAll('-', ' ');
    final color = p['color'] as String? ?? '';
    final score = (p['score'] as num?)?.toDouble() ??
        (p['confianza'] as num?)?.toDouble() ??
        0.0;
    final imagenUrl = p['imagen_url'] as String? ?? '';
    final scoreColor = score >= 0.6 ? StyleMeTheme.primary : StyleMeTheme.textSecondary;

    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          // Card con imagen
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: isBase
                  ? Border.all(color: StyleMeTheme.primary, width: 1.5)
                  : Border.all(color: Colors.black12, width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Imagen
                Expanded(
                  child: _buildImagen(imagenUrl),
                ),
                // Info
                Container(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tipo,
                          style: GoogleFonts.poppins(
                            color: StyleMeTheme.textPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (color.isNotEmpty)
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: _colorParaNombre(color),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Badge BASE
          if (isBase)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: StyleMeTheme.primary,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'BASE',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          // Badge score
          if (score > 0 && !isBase)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${(score * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagen(String url) {
    if (url.isEmpty) return _placeholder();
    // Archivo local (modo invitado)
    if (!url.startsWith('http')) {
      final file = File(url);
      return Image.file(file, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _placeholder());
    }
    // Imagen de red (usuario registrado — siempre fondo blanco 512x512)
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      placeholder: (_, __) => Container(color: Colors.white),
      errorWidget: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Icon(Icons.checkroom,
            color: StyleMeTheme.primary.withValues(alpha: 0.6), size: 30),
      ),
    );
  }

  // ── Botones de feedback ──────────────────────────────────
  Widget _buildFeedbackButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _feedbackBtn('disliked', Icons.close, 'No me gusta', StyleMeTheme.error),
          const SizedBox(width: 8),
          _feedbackBtn('saved', Icons.bookmark_border, 'Guardar', StyleMeTheme.accent),
          const SizedBox(width: 8),
          _feedbackBtn('liked', Icons.favorite_border, 'Me gusta', StyleMeTheme.success),
        ],
      ),
    );
  }

  Widget _feedbackBtn(String tipo, IconData icono, String label, Color color) {
    final activo = feedbackActual == tipo;
    return Expanded(
      child: GestureDetector(
        onTap: () => onFeedback?.call(tipo),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: activo ? color.withValues(alpha: 0.15) : StyleMeTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: activo ? color.withValues(alpha: 0.5) : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Icon(
                activo ? _iconoActivo(icono) : icono,
                color: activo ? color : StyleMeTheme.textSecondary,
                size: 19,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: activo ? color : StyleMeTheme.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
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

  // ── Versión compacta para Home ───────────────────────────
  Widget _buildCompacto() {
    final score = _scorePromedio;
    final pct = (score * 100).toStringAsFixed(0);
    final img1 = prendaBase['imagen_url'] as String? ?? '';
    final img2 = complementos.isNotEmpty
        ? complementos[0]['imagen_url'] as String? ?? ''
        : '';

    return Container(
      width: 156,
      decoration: BoxDecoration(
        color: StyleMeTheme.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: StyleMeTheme.sombraCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildImagen(img1),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: img2.isNotEmpty ? _buildImagen(img2) : _placeholder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score.clamp(0.0, 1.0),
                    backgroundColor: StyleMeTheme.surface,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(StyleMeTheme.primary),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$pct% compatible',
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// StyleMe - Pantalla de detalle de un outfit generado
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/historial_controller.dart';
import 'package:styleme/models/feedback_model.dart';
import 'package:styleme/models/outfit_model.dart';
import 'package:styleme/models/prenda_model.dart';

class OutfitDetalleScreen extends StatefulWidget {
  final OutfitModel outfit;

  const OutfitDetalleScreen({super.key, required this.outfit});

  @override
  State<OutfitDetalleScreen> createState() => _OutfitDetalleScreenState();
}

class _OutfitDetalleScreenState extends State<OutfitDetalleScreen> {
  late OutfitModel _outfit;

  @override
  void initState() {
    super.initState();
    _outfit = widget.outfit;
  }

  void _darFeedback(String tipo) async {
    final ctrl = context.read<HistorialController>();
    final ok = await ctrl.darFeedback(_outfit.id, tipo);

    if (ok && mounted) {
      setState(() {
        _outfit = OutfitModel(
          id: _outfit.id,
          prendaBase: _outfit.prendaBase,
          complementos: _outfit.complementos,
          feedback: tipo,
          temporada: _outfit.temporada,
          tipoGeneracion: _outfit.tipoGeneracion,
          generadoEn: _outfit.generadoEn,
        );
      });

      final msg = {
        'liked': '❤️ ¡Te gustó este outfit!',
        'saved': '🔖 Outfit guardado',
        'disliked': '✕ Outfit descartado',
      }[tipo] ?? '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = _outfit.prendaBase;
    final complementos = _outfit.complementos;

    return Scaffold(
      backgroundColor: StyleMeTheme.background,
      appBar: AppBar(
        backgroundColor: StyleMeTheme.background,
        title: const Text('Detalle del outfit'),
        actions: [
          // Badge de feedback actual
          if (_outfit.feedback != 'none')
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                label: Text(
                  '${FeedbackModel.emoji(_outfit.feedback)} ${FeedbackModel.texto(_outfit.feedback)}',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                backgroundColor: _colorFeedback(_outfit.feedback).withValues(alpha: 0.15),
                side: BorderSide.none,
              ),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Sección prenda base
                _seccionHeader('Prenda base', StyleMeTheme.primary),
                const SizedBox(height: 12),
                if (base != null) _prendaDetalle(base, esBase: true),

                const SizedBox(height: 24),

                // Sección complementos
                _seccionHeader('Complementos sugeridos', StyleMeTheme.textSecondary),
                const SizedBox(height: 12),
                ...complementos.asMap().entries.map((entry) {
                  final i = entry.key;
                  final comp = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _complementoDetalle(comp, posicion: i + 1),
                  );
                }),

                const SizedBox(height: 24),

                // Score global del outfit
                _scoreGlobal(complementos),

                const SizedBox(height: 28),

                // Botones de feedback
                _buildFeedbackSection(),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionHeader(String titulo, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(titulo, style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _prendaDetalle(PrendaModel prenda, {bool esBase = false}) {
    return Container(
      decoration: BoxDecoration(
        color: StyleMeTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: esBase ? Border.all(color: StyleMeTheme.primary.withValues(alpha: 0.4), width: 1.5) : null,
      ),
      child: Row(
        children: [
          // Imagen
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: SizedBox(
              width: 100,
              height: 100,
              child: CachedNetworkImage(
                imageUrl: prenda.imagenUrlCompleta(ApiConfig.baseUrl),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: StyleMeTheme.surface,
                  child: const Icon(Icons.checkroom, color: StyleMeTheme.textSecondary, size: 36),
                ),
              ),
            ),
          ),
          // Información
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (esBase)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: StyleMeTheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('BASE', style: GoogleFonts.poppins(color: StyleMeTheme.primary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    ),
                  Text(prenda.tipo, style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  _infoChip(prenda.color, Icons.palette),
                  const SizedBox(height: 4),
                  _infoChip(prenda.temporada, Icons.wb_sunny_outlined),
                  const SizedBox(height: 4),
                  _infoChip('Confianza: ${prenda.confianzaTexto}', Icons.psychology),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _complementoDetalle(ComplementoOutfit comp, {required int posicion}) {
    final score = comp.score;
    final colorScore = score > 0.7 ? StyleMeTheme.success : score > 0.5 ? StyleMeTheme.primary : StyleMeTheme.textSecondary;

    return Container(
      decoration: BoxDecoration(color: StyleMeTheme.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            children: [
              // Número de posición
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: StyleMeTheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('$posicion', style: GoogleFonts.poppins(color: StyleMeTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              // Imagen prenda
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 60,
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comp.prenda.tipo, style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('${comp.prenda.color} • ${comp.prenda.temporada}',
                        style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              // Score
              Container(
                margin: const EdgeInsets.only(right: 14),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: colorScore.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(comp.porcentaje, style: GoogleFonts.poppins(color: colorScore, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          // Desglose del score
          if (comp.detalle.isNotEmpty) _desglosScore(comp.detalle),
        ],
      ),
    );
  }

  Widget _desglosScore(Map<String, dynamic> detalle) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          _scoreItem('Co-ocurrencia', detalle['coocurrencia'] ?? 0, 'x0.5'),
          _scoreItem('Color', detalle['color'] ?? 0, 'x0.3'),
          _scoreItem('Temporada', detalle['temporada'] ?? 0, 'x0.2'),
        ].map((w) => Expanded(child: w)).toList(),
      ),
    );
  }

  Widget _scoreItem(String label, dynamic valor, String peso) {
    final v = (valor is double ? valor : double.tryParse(valor.toString()) ?? 0.0);
    final color = v > 0.7 ? StyleMeTheme.success : v > 0.5 ? StyleMeTheme.primary : StyleMeTheme.textSecondary;
    return Column(
      children: [
        Text('${(v * 100).toStringAsFixed(0)}%', style: GoogleFonts.poppins(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        Text(label, style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 9)),
        Text(peso, style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 9)),
      ],
    );
  }

  Widget _scoreGlobal(List<ComplementoOutfit> complementos) {
    if (complementos.isEmpty) return const SizedBox();
    final avgScore = complementos.fold<double>(0, (s, c) => s + c.score) / complementos.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [StyleMeTheme.primary.withValues(alpha: 0.15), StyleMeTheme.primaryDark.withValues(alpha: 0.1)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: StyleMeTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Compatibilidad del outfit', style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 12)),
                Text('${(avgScore * 100).toStringAsFixed(1)}% promedio', style: GoogleFonts.poppins(color: StyleMeTheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection() {
    return Column(
      children: [
        Text('¿Qué te parece este outfit?', style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _feedbackBtn('✕ No me gusta', 'disliked', StyleMeTheme.error)),
            const SizedBox(width: 10),
            Expanded(child: _feedbackBtn('🔖 Guardar', 'saved', StyleMeTheme.accent)),
            const SizedBox(width: 10),
            Expanded(child: _feedbackBtn('❤️ Me gusta', 'liked', StyleMeTheme.success)),
          ],
        ),
      ],
    );
  }

  Widget _feedbackBtn(String texto, String tipo, Color color) {
    final activo = _outfit.feedback == tipo;
    return GestureDetector(
      onTap: () => _darFeedback(tipo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: activo ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: activo ? color : color.withValues(alpha: 0.3)),
        ),
        child: Text(
          texto,
          style: GoogleFonts.poppins(color: activo ? Colors.white : color, fontSize: 11, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _infoChip(String texto, IconData icono) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 11, color: StyleMeTheme.textSecondary),
        const SizedBox(width: 4),
        Text(texto, style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 11)),
      ],
    );
  }

  Color _colorFeedback(String f) {
    if (f == 'liked') return StyleMeTheme.success;
    if (f == 'saved') return StyleMeTheme.accent;
    if (f == 'disliked') return StyleMeTheme.error;
    return StyleMeTheme.textSecondary;
  }
}

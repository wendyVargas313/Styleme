// StyleMe - Presentación de una RecomendacionEvento (clima + outfits + notas + meta)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/config/constants.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/agente_evento_controller.dart';
import 'package:styleme/models/recomendacion_evento_model.dart';

class RecomendacionEventoView extends StatefulWidget {
  final RecomendacionEvento recomendacion;
  // Id de la recomendación en recomendaciones_evento. Sin él no se pueden
  // llamar los endpoints de guardar/eliminar outfit, así que los botones no
  // se muestran (caso de la recomendación recién generada por POST, que
  // todavía no expone su id en la respuesta).
  final String? recomendacionId;
  final Widget? footer;

  const RecomendacionEventoView({
    super.key,
    required this.recomendacion,
    this.recomendacionId,
    this.footer,
  });

  @override
  State<RecomendacionEventoView> createState() => _RecomendacionEventoViewState();
}

class _RecomendacionEventoViewState extends State<RecomendacionEventoView> {
  // Copia local editable de los outfits: la vista se usa tanto con la
  // recomendación del controller (agente_evento_screen) como con la que
  // entrega el FutureBuilder del detalle (detalle_recomendacion_screen), que
  // no comparten estado entre sí. Mantener la copia aquí hace que el toggle
  // de "me gusta" y la eliminación se reflejen igual en ambas pantallas sin
  // tocar ninguna de las dos arquitecturas.
  late List<OutfitEvento> _outfits;

  // Índices con una acción (guardar/eliminar) en curso, para deshabilitar
  // solo los botones de ese outfit.
  final Set<int> _accionEnCurso = {};

  @override
  void initState() {
    super.initState();
    _outfits = List.of(widget.recomendacion.outfits);
  }

  bool get _puedeAccionar => widget.recomendacionId != null;

  Future<void> _alternarCorazon(int indice) async {
    if (!_puedeAccionar || _accionEnCurso.contains(indice)) return;

    setState(() => _accionEnCurso.add(indice));

    final ctrl = context.read<AgenteEventoController>();
    final exito = await ctrl.alternarGuardadoOutfit(widget.recomendacionId!, indice);

    if (!mounted) return;

    setState(() {
      _accionEnCurso.remove(indice);
      if (exito) {
        final actual = _outfits[indice];
        // El backend ya persistió el id real; a la vista solo le hace falta
        // distinguir "guardado" de "no guardado" para pintar el corazón.
        _outfits[indice] = actual.copyWith(
          outfitGuardadoId: actual.outfitGuardadoId == null ? 'guardado' : null,
        );
      }
    });

    if (!exito) {
      _mostrarError(ctrl.mensajeErrorAccion);
    }
  }

  Future<void> _confirmarYEliminar(int indice) async {
    if (!_puedeAccionar || _accionEnCurso.contains(indice)) return;

    final confirmar = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: StyleMeTheme.surface,
            title: Text(
              'Eliminar outfit',
              style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary),
            ),
            content: Text(
              '¿Eliminar este outfit de la recomendación?',
              style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar', style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Eliminar',
                  style: GoogleFonts.poppins(color: StyleMeTheme.error, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmar || !mounted) return;

    setState(() => _accionEnCurso.add(indice));

    final ctrl = context.read<AgenteEventoController>();
    final exito = await ctrl.eliminarOutfitRecomendacion(widget.recomendacionId!, indice);

    if (!mounted) return;

    setState(() {
      _accionEnCurso.remove(indice);
      if (exito) _outfits.removeAt(indice);
    });

    if (!exito) {
      _mostrarError(ctrl.mensajeErrorAccion);
    }
  }

  void _mostrarError(String? mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje ?? 'Ocurrió un error'),
        backgroundColor: StyleMeTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.recomendacion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rec.evento,
          style: GoogleFonts.poppins(
            color: StyleMeTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${rec.clima.lugar} · ${rec.clima.descripcion}',
          style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          'Temp: ${rec.clima.tempMin.toStringAsFixed(0)}° - ${rec.clima.tempMax.toStringAsFixed(0)}° '
          '(prom. ${rec.clima.tempPromedio.toStringAsFixed(0)}°) · '
          'Humedad ${rec.clima.humedad}% · '
          'Lluvia ${rec.clima.precipitacionMm.toStringAsFixed(1)}mm',
          style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 24),
        if (_outfits.isEmpty)
          _buildOutfitsVacios()
        else
          for (int i = 0; i < _outfits.length; i++) _buildOutfitCard(i, _outfits[i]),
        if (rec.notas.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Notas',
            style: GoogleFonts.poppins(
              color: StyleMeTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          ...rec.notas.map(
            (n) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $n',
                style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: StyleMeTheme.card,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'meta: prendas_consideradas=${rec.meta.prendasConsideradas}, '
            'prendas_totales=${rec.meta.prendasTotales}, '
            'outfits_descartados=${rec.meta.outfitsDescartados}, '
            'modelo=${rec.meta.modelo}, '
            'tokens_prompt=${rec.meta.tokensPrompt}, '
            'latencia_ms=${rec.meta.latenciaMs}',
            style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 11),
          ),
        ),
        if (widget.footer != null) ...[
          const SizedBox(height: 20),
          widget.footer!,
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildOutfitsVacios() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: StyleMeTheme.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.checkroom_outlined, color: StyleMeTheme.textSecondary, size: 32),
          const SizedBox(height: 8),
          Text(
            'No quedan outfits en esta recomendación',
            style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitCard(int indice, OutfitEvento outfit) {
    final enCurso = _accionEnCurso.contains(indice);
    final guardado = outfit.outfitGuardadoId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StyleMeTheme.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            outfit.nombre,
            style: GoogleFonts.poppins(
              color: StyleMeTheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int i = 0; i < outfit.prendas.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _buildMiniaturaPrenda(outfit.prendas[i])),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            outfit.justificacion,
            style: GoogleFonts.poppins(
              color: StyleMeTheme.textSecondary,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (_puedeAccionar) ...[
            const SizedBox(height: 8),
            _buildAccionesOutfit(indice, guardado, enCurso),
          ],
        ],
      ),
    );
  }

  Widget _buildAccionesOutfit(int indice, bool guardado, bool enCurso) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (enCurso)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: StyleMeTheme.primary),
            ),
          ),
        IconButton(
          onPressed: enCurso ? null : () => _alternarCorazon(indice),
          icon: Icon(
            guardado ? Icons.favorite : Icons.favorite_border,
            color: guardado ? StyleMeTheme.primary : StyleMeTheme.textSecondary,
          ),
          tooltip: guardado ? 'Quitar de mi historial' : 'Guardar en mi historial',
        ),
        IconButton(
          onPressed: enCurso ? null : () => _confirmarYEliminar(indice),
          icon: const Icon(Icons.close, color: StyleMeTheme.error),
          tooltip: 'Eliminar outfit',
        ),
      ],
    );
  }

  Widget _buildMiniaturaPrenda(PrendaEnOutfit p) {
    final url = p.imagenUrlCompleta(ApiConfig.baseUrl);

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: url == null
                ? _buildPlaceholderPrenda()
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderPrenda(),
                    loadingBuilder: (context, child, progreso) {
                      if (progreso == null) return child;
                      return _buildPlaceholderPrenda();
                    },
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${AppConstants.etiquetaTipo(p.tipo)} ${p.color}',
          style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 11),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPlaceholderPrenda() {
    return Container(
      color: StyleMeTheme.surface,
      child: const Center(
        child: Icon(Icons.checkroom, color: StyleMeTheme.textSecondary, size: 28),
      ),
    );
  }
}

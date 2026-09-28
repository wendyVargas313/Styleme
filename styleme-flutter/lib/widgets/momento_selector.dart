// StyleMe - Selector del clima de una prenda: ☀️ Soleado / 🌧️ Lluvioso
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:styleme/config/constants.dart';
import 'package:styleme/config/theme.dart';

// Dos chips independientes. Entrada/salida: 'soleado' | 'lluvioso' | 'ambos'
// (los dos marcados = prenda versátil).
class MomentoSelector extends StatelessWidget {
  const MomentoSelector({
    super.key,
    required this.valor,
    required this.onChanged,
    this.mixto = false,
  });

  static const _versatil = 'ambos';

  final String valor;
  final ValueChanged<String> onChanged;

  // Varias prendas con valores distintos: ningún chip marcado y al tocar uno
  // se asigna solo ese valor.
  final bool mixto;

  Set<String> _marcados() {
    if (mixto) return {};
    final v = AppConstants.normalizarMomento(valor) ?? AppConstants.momentoDefault;
    return AppConstants.momentosSeleccionables.contains(v)
        ? {v}
        : AppConstants.momentosSeleccionables.toSet();
  }

  void _alternar(String opcion) {
    if (mixto) {
      onChanged(opcion);
      return;
    }
    final marcados = _marcados();
    if (marcados.contains(opcion)) {
      if (marcados.length == 1) return;
      marcados.remove(opcion);
    } else {
      marcados.add(opcion);
    }
    onChanged(marcados.length > 1 ? _versatil : marcados.single);
  }

  @override
  Widget build(BuildContext context) {
    final marcados = _marcados();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final opcion in AppConstants.momentosSeleccionables)
              FilterChip(
                label: Text(
                  '${AppConstants.iconoMomento(opcion)} ${AppConstants.etiquetaMomento(opcion)}',
                  style: GoogleFonts.poppins(
                    color: marcados.contains(opcion)
                        ? Colors.white
                        : StyleMeTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                selected: marcados.contains(opcion),
                onSelected: (_) => _alternar(opcion),
                backgroundColor: StyleMeTheme.card,
                selectedColor: StyleMeTheme.primary,
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: marcados.contains(opcion)
                      ? StyleMeTheme.primary
                      : Colors.transparent,
                ),
              ),
            if (mixto)
              Text(
                'Valores mixtos',
                style: GoogleFonts.poppins(
                  color: StyleMeTheme.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Marca los dos si la prenda sirve con cualquier clima.',
          style: GoogleFonts.poppins(
            color: StyleMeTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

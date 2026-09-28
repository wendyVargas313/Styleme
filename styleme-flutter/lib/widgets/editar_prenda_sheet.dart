// StyleMe - Hoja inferior para corregir tipo, color y clima de una prenda
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:styleme/config/constants.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/guardarropa_controller.dart';
import 'package:styleme/models/prenda_model.dart';
import 'package:styleme/widgets/custom_button.dart';
import 'package:styleme/widgets/momento_selector.dart';

class EditarPrendaSheet extends StatefulWidget {
  final PrendaModel prenda;

  const EditarPrendaSheet({super.key, required this.prenda});

  // Abre la hoja; devuelve la prenda actualizada si se guardó.
  static Future<PrendaModel?> mostrar(BuildContext context, PrendaModel prenda) {
    return showModalBottomSheet<PrendaModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: StyleMeTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EditarPrendaSheet(prenda: prenda),
    );
  }

  @override
  State<EditarPrendaSheet> createState() => _EditarPrendaSheetState();
}

class _EditarPrendaSheetState extends State<EditarPrendaSheet> {
  // Las clases comodín del detector van al final: son la salida de "no sé".
  static const _tiposAlFinal = ['other', 'not sure'];

  late String _tipo = widget.prenda.tipo;
  late String _color = widget.prenda.color;
  late String _momento = widget.prenda.momento;
  bool _guardando = false;
  String? _error;

  bool get _hayCambios =>
      _tipo != widget.prenda.tipo ||
      _color != widget.prenda.color ||
      _momento != widget.prenda.momento;

  List<String> get _tiposOrdenados {
    final tipos = AppConstants.tipoEtiquetas.keys
        .where((t) => !_tiposAlFinal.contains(t))
        .toList()
      ..sort((a, b) => AppConstants.etiquetaTipo(a).compareTo(AppConstants.etiquetaTipo(b)));
    return [...tipos, ..._tiposAlFinal];
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final original = widget.prenda;
    final resultado = await context.read<GuardarropaController>().editarPrenda(
          original,
          tipo: _tipo != original.tipo ? _tipo : null,
          color: _color != original.color ? _color : null,
          momento: _momento != original.momento ? _momento : null,
        );
    if (!mounted) return;
    if (resultado.prenda != null) {
      Navigator.pop(context, resultado.prenda);
      return;
    }
    // Lo elegido se conserva: la hoja sigue abierta para reintentar.
    setState(() {
      _guardando = false;
      _error = resultado.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_guardando,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: StyleMeTheme.textSecondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Editar prenda',
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _titulo('Tipo'),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final t in _tiposOrdenados)
                      ChoiceChip(
                        label: Text(
                          AppConstants.etiquetaTipo(t),
                          style: GoogleFonts.poppins(
                            color: t == _tipo ? Colors.white : StyleMeTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        selected: t == _tipo,
                        onSelected: _guardando ? null : (_) => setState(() => _tipo = t),
                        selectedColor: StyleMeTheme.primary,
                        backgroundColor: StyleMeTheme.card,
                        showCheckmark: false,
                        side: BorderSide.none,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _titulo('Color'),
                Wrap(
                  spacing: 6,
                  runSpacing: 10,
                  children: [
                    for (final (nombre, muestra) in AppConstants.colores)
                      _circuloColor(nombre, muestra),
                  ],
                ),
                const SizedBox(height: 20),
                _titulo('Clima'),
                IgnorePointer(
                  ignoring: _guardando,
                  child: MomentoSelector(
                    valor: _momento,
                    onChanged: (m) => setState(() => _momento = m),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: GoogleFonts.poppins(color: StyleMeTheme.error, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                CustomButton(
                  texto: 'Guardar cambios',
                  icono: Icons.check,
                  cargando: _guardando,
                  onPressed: _hayCambios ? _guardar : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _titulo(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: GoogleFonts.poppins(
          color: StyleMeTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _circuloColor(String nombre, Color muestra) {
    final seleccionado = nombre == _color;
    final checkClaro = muestra.computeLuminance() < 0.5;
    return GestureDetector(
      onTap: _guardando ? null : () => setState(() => _color = nombre),
      child: SizedBox(
        width: 58,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: muestra,
                shape: BoxShape.circle,
                border: Border.all(
                  color: seleccionado ? StyleMeTheme.primary : Colors.white24,
                  width: seleccionado ? 3 : 1,
                ),
              ),
              child: seleccionado
                  ? Icon(Icons.check, size: 18, color: checkClaro ? Colors.white : Colors.black87)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              AppConstants.etiquetaColor(nombre),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: seleccionado ? StyleMeTheme.textPrimary : StyleMeTheme.textSecondary,
                fontSize: 10,
                fontWeight: seleccionado ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

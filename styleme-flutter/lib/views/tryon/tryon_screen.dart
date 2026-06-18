// StyleMe - Virtual Try-On Screen
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/tryon_controller.dart';

class TryonScreen extends StatelessWidget {
  const TryonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TryonController(),
      child: const _TryonView(),
    );
  }
}

class _TryonView extends StatelessWidget {
  const _TryonView();

  static const _categorias = [
    {'value': 'upper',   'label': 'Parte superior', 'icon': Icons.dry_cleaning},
    {'value': 'lower',   'label': 'Parte inferior',  'icon': Icons.straighten},
    {'value': 'dresses', 'label': 'Vestidos',         'icon': Icons.accessibility_new},
  ];

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<TryonController>();

    return Scaffold(
      backgroundColor: StyleMeTheme.background,
      appBar: AppBar(
        backgroundColor: StyleMeTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: StyleMeTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Virtual Try-On',
          style: GoogleFonts.poppins(
            color: StyleMeTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (ctrl.estado != TryonEstado.inicial)
            TextButton(
              onPressed: ctrl.reiniciar,
              child: Text(
                'Reiniciar',
                style: GoogleFonts.poppins(
                  color: StyleMeTheme.primary,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: ctrl.estado == TryonEstado.listo && ctrl.imagenResultadoBase64 != null
          ? _buildResultado(context, ctrl)
          : _buildForm(context, ctrl),
    );
  }

  // ── Formulario ─────────────────────────────────────────────
  Widget _buildForm(BuildContext context, TryonController ctrl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('1. Sube tu foto'),
          const SizedBox(height: 10),
          _selectorImagen(
            context,
            imagen: ctrl.imagenPersona,
            placeholder: 'Tu foto de cuerpo completo',
            icono: Icons.person_outline,
            onTap: () => _seleccionarImagen(context, esPersona: true),
          ),
          const SizedBox(height: 20),
          _label('2. Sube la prenda'),
          const SizedBox(height: 10),
          _selectorImagen(
            context,
            imagen: ctrl.imagenPrenda,
            placeholder: 'Foto de la prenda',
            icono: Icons.checkroom_outlined,
            onTap: () => _seleccionarImagen(context, esPersona: false),
          ),
          const SizedBox(height: 24),
          _label('3. Tipo de prenda'),
          const SizedBox(height: 10),
          _buildCategorias(context, ctrl),
          const SizedBox(height: 32),
          if (ctrl.estado == TryonEstado.procesando)
            _buildCargando()
          else ...[
            if (ctrl.estado == TryonEstado.error && ctrl.mensajeError != null)
              _buildError(ctrl.mensajeError!),
            _buildBoton(context, ctrl),
          ],
        ],
      ),
    );
  }

  Widget _label(String texto) {
    return Text(
      texto,
      style: GoogleFonts.poppins(
        color: StyleMeTheme.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _selectorImagen(
    BuildContext context, {
    required File? imagen,
    required String placeholder,
    required IconData icono,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: StyleMeTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: imagen != null
                ? StyleMeTheme.primary
                : StyleMeTheme.textSecondary.withValues(alpha: 0.3),
            width: imagen != null ? 2 : 1,
          ),
        ),
        child: imagen != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(imagen, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icono, color: StyleMeTheme.textSecondary, size: 40),
                  const SizedBox(height: 10),
                  Text(
                    placeholder,
                    style: GoogleFonts.poppins(
                      color: StyleMeTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toca para seleccionar',
                    style: GoogleFonts.poppins(
                      color: StyleMeTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCategorias(BuildContext context, TryonController ctrl) {
    return Row(
      children: _categorias.map((cat) {
        final seleccionado = ctrl.categoria == cat['value'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => ctrl.setCategoria(cat['value'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: seleccionado
                      ? StyleMeTheme.primary.withValues(alpha: 0.15)
                      : StyleMeTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: seleccionado
                        ? StyleMeTheme.primary
                        : StyleMeTheme.textSecondary.withValues(alpha: 0.2),
                    width: seleccionado ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      cat['icon'] as IconData,
                      color: seleccionado
                          ? StyleMeTheme.primary
                          : StyleMeTheme.textSecondary,
                      size: 22,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat['label'] as String,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: seleccionado
                            ? StyleMeTheme.primary
                            : StyleMeTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: seleccionado
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCargando() {
    return Column(
      children: [
        const CircularProgressIndicator(color: StyleMeTheme.primary),
        const SizedBox(height: 16),
        Text(
          'Generando tu look...',
          style: GoogleFonts.poppins(
            color: StyleMeTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Puede tardar entre 10 y 20 segundos',
          style: GoogleFonts.poppins(
            color: StyleMeTheme.textSecondary.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildError(String mensaje) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: GoogleFonts.poppins(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoton(BuildContext context, TryonController ctrl) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: ctrl.listo ? () => ctrl.generarTryon() : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: StyleMeTheme.primary,
          disabledBackgroundColor:
              StyleMeTheme.textSecondary.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_fix_high, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Generar Try-On',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Resultado ──────────────────────────────────────────────
  Widget _buildResultado(BuildContext context, TryonController ctrl) {
    final bytes = base64Decode(ctrl.imagenResultadoBase64!);

    return Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          color: StyleMeTheme.surface,
          child: Column(
            children: [
              if (ctrl.tiempoInferencia != null)
                Text(
                  'Inferencia: ${ctrl.tiempoInferencia!.toStringAsFixed(1)}s',
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: ctrl.reiniciar,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: StyleMeTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Nuevo try-on',
                        style: GoogleFonts.poppins(
                          color: StyleMeTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _seleccionarImagen(
    BuildContext context, {
    required bool esPersona,
  }) async {
    final ctrl = context.read<TryonController>();
    final picker = ImagePicker();

    final opcion = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: StyleMeTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: StyleMeTheme.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: StyleMeTheme.primary),
                title: Text('Cámara',
                    style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: StyleMeTheme.primary),
                title: Text('Galería',
                    style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (opcion == null) return;
    final xfile = await picker.pickImage(source: opcion, imageQuality: 85);
    if (xfile == null) return;

    final file = File(xfile.path);
    if (esPersona) {
      ctrl.setImagenPersona(file);
    } else {
      ctrl.setImagenPrenda(file);
    }
  }
}

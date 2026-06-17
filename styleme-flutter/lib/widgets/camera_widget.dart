// StyleMe - Widget selector de imagen (cámara o galería)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/services/image_service.dart';

class CameraWidget extends StatelessWidget {
  final File? imagenSeleccionada;
  final Function(File) onImagenSeleccionada;

  const CameraWidget({
    super.key,
    this.imagenSeleccionada,
    required this.onImagenSeleccionada,
  });

  @override
  Widget build(BuildContext context) {
    if (imagenSeleccionada != null) {
      return _buildPreview(context);
    }
    return _buildSelector(context);
  }

  Widget _buildSelector(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _botonFuente(
                context,
                icono: Icons.camera_alt,
                texto: 'Cámara',
                onTap: () async {
                  final imagen = await ImageService.tomarFoto();
                  if (imagen != null) onImagenSeleccionada(imagen);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _botonFuente(
                context,
                icono: Icons.photo_library,
                texto: 'Galería',
                onTap: () async {
                  final imagen = await ImageService.seleccionarDeGaleria();
                  if (imagen != null) onImagenSeleccionada(imagen);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _botonFuente(
    BuildContext context, {
    required IconData icono,
    required String texto,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: StyleMeTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: StyleMeTheme.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                gradient: StyleMeTheme.gradientePrimario,
                shape: BoxShape.circle,
              ),
              child: Icon(icono, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              texto,
              style: GoogleFonts.poppins(
                color: StyleMeTheme.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            imagenSeleccionada!,
            height: 240,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _mostrarOpciones(context),
          icon: const Icon(Icons.edit, size: 16),
          label: Text(
            'Cambiar imagen',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          style: TextButton.styleFrom(foregroundColor: StyleMeTheme.primary),
        ),
      ],
    );
  }

  void _mostrarOpciones(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: StyleMeTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: StyleMeTheme.textSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: StyleMeTheme.primary),
              title: Text('Tomar foto', style: GoogleFonts.poppins()),
              onTap: () async {
                Navigator.pop(context);
                final imagen = await ImageService.tomarFoto();
                if (imagen != null) onImagenSeleccionada(imagen);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: StyleMeTheme.primary),
              title: Text('Seleccionar de galería', style: GoogleFonts.poppins()),
              onTap: () async {
                Navigator.pop(context);
                final imagen = await ImageService.seleccionarDeGaleria();
                if (imagen != null) onImagenSeleccionada(imagen);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

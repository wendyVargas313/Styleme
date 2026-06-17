// StyleMe - Pantalla para agregar una nueva prenda
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:styleme/config/constants.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/guardarropa_controller.dart';
import 'package:styleme/widgets/camera_widget.dart';
import 'package:styleme/widgets/custom_button.dart';
import 'package:styleme/widgets/loading_widget.dart';

class AgregarPrendaScreen extends StatefulWidget {
  const AgregarPrendaScreen({super.key});

  @override
  State<AgregarPrendaScreen> createState() => _AgregarPrendaScreenState();
}

class _AgregarPrendaScreenState extends State<AgregarPrendaScreen> {
  File? _imagenSeleccionada;
  String _temporadaSeleccionada = 'invierno';
  final _notasCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_imagenSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una imagen primero')),
      );
      return;
    }

    setState(() => _guardando = true);

    final ctrl = context.read<GuardarropaController>();
    final prenda = await ctrl.agregarPrenda(
      imagen: _imagenSeleccionada!,
      temporada: _temporadaSeleccionada,
      notas: _notasCtrl.text.trim(),
    );

    setState(() => _guardando = false);

    if (!mounted) return;

    if (prenda != null) {
      // Mostrar resultado de la detección ML
      _mostrarResultado(prenda.tipo, prenda.color, prenda.confianzaTexto);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ctrl.mensajeError ?? 'Error al guardar la prenda'),
          backgroundColor: StyleMeTheme.error,
        ),
      );
    }
  }

  void _mostrarResultado(String tipo, String color, String confianza) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: StyleMeTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: StyleMeTheme.success.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: StyleMeTheme.success, size: 20),
            ),
            const SizedBox(width: 10),
            Text('¡Prenda detectada!', style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _deteccionRow('Tipo detectado', tipo, Icons.checkroom),
            const SizedBox(height: 12),
            _deteccionRow('Color', color, Icons.palette),
            const SizedBox(height: 12),
            _deteccionRow('Confianza ML', confianza, Icons.psychology),
            const SizedBox(height: 12),
            _deteccionRow('Temporada', _temporadaSeleccionada, Icons.wb_sunny_outlined),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Cerrar dialog
              Navigator.of(context).pop(); // Volver al guardarropa
            },
            child: Text('Perfecto', style: GoogleFonts.poppins(color: StyleMeTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _deteccionRow(String label, String valor, IconData icono) {
    return Row(
      children: [
        Icon(icono, color: StyleMeTheme.primary, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13))),
        Text(valor, style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      cargando: _guardando,
      mensaje: 'YOLO analizando tu prenda...',
      child: Scaffold(
        backgroundColor: StyleMeTheme.background,
        appBar: AppBar(
          title: const Text('Agregar prenda'),
          backgroundColor: StyleMeTheme.background,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selector de imagen
              Text(
                'Foto de la prenda',
                style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              CameraWidget(
                imagenSeleccionada: _imagenSeleccionada,
                onImagenSeleccionada: (f) => setState(() => _imagenSeleccionada = f),
              ),

              const SizedBox(height: 24),

              // Info sobre detección automática
              if (_imagenSeleccionada != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: StyleMeTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: StyleMeTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: StyleMeTheme.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'YOLOv8 detectará automáticamente el tipo y KMeans el color',
                          style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Selector de temporada
              Text(
                'Temporada',
                style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Row(
                children: AppConstants.temporadas.map((t) {
                  final sel = t == _temporadaSeleccionada;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _temporadaSeleccionada = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: sel ? StyleMeTheme.primary : StyleMeTheme.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: sel ? StyleMeTheme.primary : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(AppConstants.temporadasIconos[t] ?? '', style: const TextStyle(fontSize: 20)),
                              const SizedBox(height: 4),
                              Text(
                                t,
                                style: GoogleFonts.poppins(
                                  color: sel ? Colors.white : StyleMeTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Notas
              Text(
                'Notas (opcional)',
                style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notasCtrl,
                maxLines: 2,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Ej: Comprada en Zara, talla M...',
                  hintStyle: GoogleFonts.poppins(fontSize: 13),
                  counterStyle: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 11),
                ),
              ),

              const SizedBox(height: 32),

              // Botón guardar
              CustomButton(
                texto: 'Guardar en mi armario',
                onPressed: _guardando ? null : _guardar,
                cargando: _guardando,
                icono: Icons.save,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

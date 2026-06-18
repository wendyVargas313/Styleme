// StyleMe - Pantalla de modo invitado
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:styleme/app/routes.dart';
import 'package:styleme/config/api_config.dart';
import 'package:styleme/config/constants.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/services/api_service.dart';
import 'package:styleme/services/image_service.dart';
import 'package:styleme/widgets/custom_button.dart';
import 'package:styleme/widgets/loading_widget.dart';
import 'package:styleme/widgets/outfit_visual_card.dart';

class GuestScreen extends StatefulWidget {
  const GuestScreen({super.key});

  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> {
  final ApiService _api = ApiService();
  final String _deviceId = _generarDeviceId();

  static String _generarDeviceId() {
    final rnd = Random();
    const chars = 'abcdef0123456789';
    return List.generate(32, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  List<File> _imagenes = [];
  String _temporadaSeleccionada = 'invierno';
  bool _procesando = false;
  Map<String, dynamic>? _resultado;

  Future<void> _seleccionarImagenes() async {
    final archivos = await ImageService.seleccionarMultiples(max: 10);
    if (archivos.isNotEmpty) {
      setState(() => _imagenes = archivos);
    }
  }

  Future<void> _probar() async {
    if (_imagenes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una imagen')),
      );
      return;
    }

    setState(() => _procesando = true);

    try {
      final files = await Future.wait(
        _imagenes.map((f) async => MapEntry(
              'imagenes',
              await MultipartFile.fromFile(f.path, filename: f.path.split('/').last),
            )),
      );

      final formData = FormData.fromMap({
        'imagenes': files.map((e) => e.value).toList(),
        'device_id': _deviceId,
        'temporada': _temporadaSeleccionada,
      });

      dev.log('[GuestScreen] POST ${ApiConfig.invitadoProbar}');
      dev.log('[GuestScreen] device_id=$_deviceId | temporada=$_temporadaSeleccionada | imágenes=${_imagenes.length}');

      final response = await _api.postFormData(ApiConfig.invitadoProbar, formData);

      dev.log('[GuestScreen] Respuesta HTTP: ${response.statusCode}');
      dev.log('[GuestScreen] Body: ${response.data}');

      setState(() {
        _resultado = response.data as Map<String, dynamic>;
        _procesando = false;
      });
    } on Exception catch (e) {
      dev.log('[GuestScreen] ❌ ERROR: ${e.runtimeType}: $e');
      setState(() => _procesando = false);
      if (!mounted) return;

      // Extraer mensaje legible del DioException
      String mensaje = 'Error procesando las imágenes';
      if (e.toString().contains('429')) {
        mensaje = 'Ya usaste el modo invitado hoy. ¡Crea una cuenta!';
      } else if (e.toString().contains('DioException')) {
        // Mostrar el detail del backend si existe
        try {
          final dioErr = e as dynamic;
          final detail = dioErr.response?.data?['detail'] ?? dioErr.message ?? e.toString();
          mensaje = detail.toString();
          dev.log('[GuestScreen] Backend detail: $detail');
        } catch (_) {
          mensaje = e.toString();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: StyleMeTheme.error,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      cargando: _procesando,
      mensaje: 'Analizando tus prendas con ML...',
      child: Scaffold(
        backgroundColor: StyleMeTheme.background,
        appBar: AppBar(
          title: const Text('Probar StyleMe'),
          backgroundColor: StyleMeTheme.background,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _resultado == null ? _buildForm() : _buildResultado(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: StyleMeTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: StyleMeTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: StyleMeTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '1 prueba gratis por día • Máx 10 prendas\nSin necesidad de registrarte',
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Sube fotos de tus prendas',
          style: GoogleFonts.poppins(
            color: StyleMeTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _seleccionarImagenes,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: StyleMeTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: StyleMeTheme.primary.withValues(alpha: 0.3), width: 1.5),
            ),
            child: _imagenes.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate, color: StyleMeTheme.primary, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'Toca para seleccionar imágenes',
                        style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _imagenes.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_imagenes[i], width: 80, height: 80, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Temporada',
          style: GoogleFonts.poppins(
            color: StyleMeTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: AppConstants.temporadas.map((t) {
            final sel = t == _temporadaSeleccionada;
            return ChoiceChip(
              label: Text(
                '${AppConstants.temporadasIconos[t]} $t',
                style: GoogleFonts.poppins(
                  color: sel ? Colors.white : StyleMeTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              selected: sel,
              selectedColor: StyleMeTheme.primary,
              backgroundColor: StyleMeTheme.card,
              onSelected: (_) => setState(() => _temporadaSeleccionada = t),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        CustomButton(
          texto: 'Generar mi outfit',
          onPressed: _probar,
          icono: Icons.auto_awesome,
        ),
      ],
    );
  }

  Widget _buildResultado() {
    final prendas = (_resultado!['prendas_detectadas'] as List? ?? []).cast<Map<String, dynamic>>();
    final outfitPrueba = _resultado!['outfit_prueba'] as Map<String, dynamic>?;

    // Construir maps para OutfitVisualCard con archivos locales como imágenes
    Map<String, dynamic> prendaBase = {};
    List<Map<String, dynamic>> complementos = [];

    if (outfitPrueba != null) {
      final baseData = outfitPrueba['prenda_base'] as Map<String, dynamic>? ?? {};
      prendaBase = {
        'tipo': baseData['tipo'] ?? '',
        'color': baseData['color'] ?? '',
        'confianza': (baseData['confianza'] ?? 0.0).toDouble(),
        'imagen_url': _imagenes.isNotEmpty ? _imagenes[0].path : '',
      };

      final compsRaw = outfitPrueba['complementos'] as List? ?? [];
      int imgIdx = 1;
      for (final c in compsRaw) {
        final cMap = c as Map<String, dynamic>;
        final pData = cMap['prenda'] as Map<String, dynamic>? ?? cMap;
        complementos.add({
          'tipo': pData['tipo'] ?? '',
          'color': pData['color'] ?? '',
          'score': ((cMap['score'] ?? pData['confianza'] ?? 0.0) as num).toDouble(),
          'imagen_url': imgIdx < _imagenes.length ? _imagenes[imgIdx].path : '',
        });
        imgIdx++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título
        Text(
          'Tu outfit StyleMe ✨',
          style: GoogleFonts.poppins(
            color: StyleMeTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Basado en ${prendas.length} prenda${prendas.length != 1 ? 's' : ''} detectada${prendas.length != 1 ? 's' : ''}',
          style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),

        // Grid de imágenes subidas con chips de detección
        if (_imagenes.isNotEmpty) ...[          
          Text(
            'Prendas analizadas',
            style: GoogleFonts.poppins(
              color: StyleMeTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imagenes.length,
              itemBuilder: (_, i) {
                final p = i < prendas.length ? prendas[i] : null;
                final conf = ((p?['confianza'] ?? 0.0) as num) * 100;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _imagenes[i],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (p != null)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.72),
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(10)),
                            ),
                            child: Text(
                              '${p['tipo']} • ${conf.toStringAsFixed(0)}%',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],

        // OutfitVisualCard
        if (prendaBase.isNotEmpty)
          OutfitVisualCard(
            prendaBase: prendaBase,
            complementos: complementos,
            titulo: 'Tu outfit de hoy',
          )
        else
          ...prendas.map((p) => _prendaDetectada(p)),

        const SizedBox(height: 20),

        // CTA Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                StyleMeTheme.primary.withValues(alpha: 0.14),
                StyleMeTheme.primaryDark.withValues(alpha: 0.07),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: StyleMeTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                '🎉 ¿Te gustó StyleMe?',
                style: GoogleFonts.poppins(
                  color: StyleMeTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Crea tu cuenta gratis para guardar tus outfits y acceder a todas las funciones',
                style: GoogleFonts.poppins(
                    color: StyleMeTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              CustomButton(
                texto: 'Crear cuenta gratis',
                onPressed: () => Navigator.pushNamed(context, AppRoutes.registro),
                icono: Icons.person_add,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() {
                  _resultado = null;
                  _imagenes = [];
                }),
                child: Text(
                  'Seguir explorando',
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _prendaDetectada(Map<String, dynamic> p) {
    final confianza = (((p['confianza'] ?? 0.0) as num) * 100).toStringAsFixed(0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StyleMeTheme.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.checkroom, color: StyleMeTheme.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['tipo'] ?? '',
                  style: GoogleFonts.poppins(
                      color: StyleMeTheme.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  '${p['color']} • ${p['temporada']}',
                  style: GoogleFonts.poppins(
                      color: StyleMeTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '$confianza%',
            style: GoogleFonts.poppins(
                color: StyleMeTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 15),
          ),
        ],
      ),
    );
  }
}

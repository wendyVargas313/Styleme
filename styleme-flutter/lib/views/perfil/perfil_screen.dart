// StyleMe - Pantalla de Perfil de Usuario
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:styleme/app/routes.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/auth_controller.dart';
import 'package:styleme/controllers/guardarropa_controller.dart';
import 'package:styleme/controllers/historial_controller.dart';
import 'package:styleme/widgets/glass_kit.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  bool _subiendoFoto = false;
  bool _subiendoAvatar = false;
  static const _naranja = Color(0xFFFF6B00);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthController>().refrescarPerfil();
    });
  }

  Future<void> _seleccionarFoto() async {
    final picker = ImagePicker();
    final opcion = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: StyleMeTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Seleccionar foto',
                style: GoogleFonts.poppins(
                    color: StyleMeTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _naranja),
              title: Text('Cámara',
                  style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _naranja),
              title: Text('Galería',
                  style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (opcion == null || !mounted) return;

    final picked = await picker.pickImage(source: opcion, imageQuality: 90);
    if (picked == null || !mounted) return;

    setState(() => _subiendoFoto = true);
    final ok = await context.read<AuthController>().subirFotoPerfil(File(picked.path));
    if (!mounted) return;
    setState(() => _subiendoFoto = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Foto actualizada' : 'Error al subir la foto'),
      backgroundColor: ok ? _naranja : StyleMeTheme.error,
    ));
  }

  Future<void> _seleccionarAvatar() async {
    final picker = ImagePicker();
    final opcion = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: StyleMeTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Seleccionar avatar',
                style: GoogleFonts.poppins(
                    color: StyleMeTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _naranja),
              title: Text('Cámara',
                  style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _naranja),
              title: Text('Galería',
                  style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (opcion == null || !mounted) return;

    final picked = await picker.pickImage(source: opcion, imageQuality: 90);
    if (picked == null || !mounted) return;

    setState(() => _subiendoAvatar = true);
    final ok = await context.read<AuthController>().subirAvatar(File(picked.path));
    if (!mounted) return;
    setState(() => _subiendoAvatar = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Avatar actualizado' : 'Error al subir el avatar'),
      backgroundColor: ok ? _naranja : StyleMeTheme.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final authCtrl = context.watch<AuthController>();
    final guardCtrl = context.watch<GuardarropaController>();
    final histCtrl = context.watch<HistorialController>();
    final usuario = authCtrl.usuario;

    return Scaffold(
      backgroundColor: StyleMeTheme.background,
      appBar: GlassAppBar(
        title: 'Perfil',
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: StyleMeTheme.error),
            onPressed: () => _confirmarCerrarSesion(context, authCtrl),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar y nombre
            FadeSlideIn(
             child: GlassCard(
              radius: 20,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar con foto (o inicial como fallback) + badge de cámara
                  GestureDetector(
                    onTap: _subiendoAvatar ? null : _seleccionarAvatar,
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            gradient: StyleMeTheme.gradientePrimario,
                            shape: BoxShape.circle,
                            boxShadow: StyleMeTheme.naranjaGlow,
                          ),
                          child: ClipOval(
                            child: authCtrl.fotoAvatarUrlCompleta != null
                                ? Image.network(
                                    authCtrl.fotoAvatarUrlCompleta!,
                                    fit: BoxFit.cover,
                                    width: 80,
                                    height: 80,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        usuario?.inicial ?? 'S',
                                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      usuario?.inicial ?? 'S',
                                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                          ),
                        ),
                        // Indicador de carga sobre el avatar
                        if (_subiendoAvatar)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Badge de cámara
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: _naranja,
                              shape: BoxShape.circle,
                              border: Border.all(color: StyleMeTheme.surface, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    usuario?.nombre ?? '',
                    style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    usuario?.email ?? '',
                    style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: StyleMeTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      usuario?.genero ?? 'otro',
                      style: GoogleFonts.poppins(color: StyleMeTheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
             ),
            ),

            const SizedBox(height: 16),

            // Sección: Mi foto para Try-On
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: _buildSeccionFoto(authCtrl),
            ),

            const SizedBox(height: 20),

            // Estadísticas
            FadeSlideIn(
              delay: const Duration(milliseconds: 140),
              child: Row(
                children: [
                  Expanded(child: _statCard('Prendas', '${guardCtrl.totalPrendas}', Icons.checkroom)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Outfits', '${usuario?.totalOutfitsGenerados ?? 0}', Icons.auto_awesome)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Guardados', '${_contarGuardados(histCtrl)}', Icons.bookmark)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Opciones del perfil
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: Column(
                children: [
                  _opcionCard(
                    'Mi armario',
                    Icons.checkroom_outlined,
                    subtitulo: '${guardCtrl.totalPrendas} prendas',
                    onTap: () {},
                  ),
                  const SizedBox(height: 10),
                  _opcionCard(
                    'Historial de outfits',
                    Icons.history_outlined,
                    subtitulo: '${histCtrl.total} outfits generados',
                    onTap: () {},
                  ),
                  const SizedBox(height: 10),
                  _opcionCard(
                    'Acerca de StyleMe',
                    Icons.info_outline,
                    subtitulo: 'Trabajo de Grado - UMB',
                    onTap: () => _mostrarAcercaDe(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Botón cerrar sesión
            GestureDetector(
              onTap: () => _confirmarCerrarSesion(context, authCtrl),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: StyleMeTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: StyleMeTheme.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout, color: StyleMeTheme.error, size: 18),
                    const SizedBox(width: 10),
                    Text('Cerrar sesión', style: GoogleFonts.poppins(color: StyleMeTheme.error, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionFoto(AuthController authCtrl) {
    final fotoUrl = authCtrl.fotoPerfilUrlCompleta;
    final tieneFoto = fotoUrl != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StyleMeTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tieneFoto
              ? _naranja.withValues(alpha: 0.4)
              : StyleMeTheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Avatar circular con foto o placeholder
          GestureDetector(
            onTap: _subiendoFoto ? null : _seleccionarFoto,
            child: Stack(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tieneFoto ? _naranja : StyleMeTheme.primary.withValues(alpha: 0.3),
                      width: tieneFoto ? 2.5 : 1.5,
                    ),
                    color: StyleMeTheme.surface,
                  ),
                  child: ClipOval(
                    child: tieneFoto
                        ? Image.network(
                            fotoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              color: StyleMeTheme.textSecondary,
                              size: 36,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            color: StyleMeTheme.textSecondary,
                            size: 36,
                          ),
                  ),
                ),
                // Indicador de carga sobre el avatar
                if (_subiendoFoto)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(_naranja),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // Texto y botón
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mi foto para Try-On',
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tieneFoto
                      ? 'Usada para el virtual try-on'
                      : 'Necesaria para el virtual try-on',
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _subiendoFoto ? null : _seleccionarFoto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _subiendoFoto
                          ? _naranja.withValues(alpha: 0.4)
                          : _naranja,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tieneFoto ? Icons.edit : Icons.add_a_photo,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tieneFoto ? 'Cambiar foto' : 'Agregar mi foto',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String valor, IconData icono) {
    return GlassCard(
      radius: 14,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: StyleMeTheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: StyleMeTheme.primary, size: 18),
          ),
          const SizedBox(height: 8),
          Text(valor, style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _opcionCard(String titulo, IconData icono, {String? subtitulo, VoidCallback? onTap}) {
    return GlassCard(
      radius: 14,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: StyleMeTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icono, color: StyleMeTheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontWeight: FontWeight.w500)),
                if (subtitulo != null)
                  Text(subtitulo, style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: StyleMeTheme.textSecondary, size: 18),
        ],
      ),
    );
  }

  int _contarGuardados(HistorialController ctrl) {
    return ctrl.outfits.where((o) => o.esSaved || o.esLiked).length;
  }

  void _confirmarCerrarSesion(BuildContext context, AuthController authCtrl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: StyleMeTheme.surface,
        title: Text('Cerrar sesión', style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('¿Deseas cerrar sesión?', style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await authCtrl.cerrarSesion();
              if (context.mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            child: Text('Cerrar sesión', style: GoogleFonts.poppins(color: StyleMeTheme.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _mostrarAcercaDe(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: StyleMeTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('StyleMe', style: GoogleFonts.poppins(color: StyleMeTheme.primary, fontWeight: FontWeight.bold, fontSize: 22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recomendación inteligente de outfits con Machine Learning', style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 13)),
            const SizedBox(height: 12),
            _infoItem('Universidad', 'Manuela Beltrán'),
            _infoItem('Ciudad', 'Bogotá, Colombia'),
            _infoItem('Versión', '1.0.0'),
            _infoItem('Modelos ML', 'YOLOv8 + KMeans + Co-ocurrencia'),
            _infoItem('Dataset', 'Clothing-Detection-6 (8,359 imgs)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: GoogleFonts.poppins(color: StyleMeTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text('$label: ', style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 12)),
          Expanded(child: Text(valor, style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

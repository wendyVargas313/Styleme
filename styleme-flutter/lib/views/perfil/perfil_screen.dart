// StyleMe - Pantalla de Perfil de Usuario
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:styleme/app/routes.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/auth_controller.dart';
import 'package:styleme/controllers/guardarropa_controller.dart';
import 'package:styleme/controllers/historial_controller.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthController>().refrescarPerfil();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authCtrl = context.watch<AuthController>();
    final guardCtrl = context.watch<GuardarropaController>();
    final histCtrl = context.watch<HistorialController>();
    final usuario = authCtrl.usuario;

    return Scaffold(
      backgroundColor: StyleMeTheme.background,
      appBar: AppBar(
        backgroundColor: StyleMeTheme.background,
        title: Text('Perfil', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [StyleMeTheme.card, StyleMeTheme.surface],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  // Avatar con inicial
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: StyleMeTheme.gradientePrimario,
                      shape: BoxShape.circle,
                      boxShadow: StyleMeTheme.sombraNaranja,
                    ),
                    child: Center(
                      child: Text(
                        usuario?.inicial ?? 'S',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
                      ),
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

            const SizedBox(height: 20),

            // Estadísticas
            Row(
              children: [
                Expanded(child: _statCard('Prendas', '${guardCtrl.totalPrendas}', Icons.checkroom)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Outfits', '${usuario?.totalOutfitsGenerados ?? 0}', Icons.auto_awesome)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Guardados', '${_contarGuardados(histCtrl)}', Icons.bookmark)),
              ],
            ),

            const SizedBox(height: 20),

            // Opciones del perfil
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

  Widget _statCard(String label, String valor, IconData icono) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: StyleMeTheme.card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Icon(icono, color: StyleMeTheme.primary, size: 22),
          const SizedBox(height: 6),
          Text(valor, style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _opcionCard(String titulo, IconData icono, {String? subtitulo, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: StyleMeTheme.card, borderRadius: BorderRadius.circular(14)),
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

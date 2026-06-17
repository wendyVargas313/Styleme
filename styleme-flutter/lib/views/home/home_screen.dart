// StyleMe - Home Screen principal con bottom navigation
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/auth_controller.dart';
import 'package:styleme/controllers/guardarropa_controller.dart';
import 'package:styleme/controllers/recomendacion_controller.dart';
import 'package:styleme/views/guardarropa/guardarropa_screen.dart';
import 'package:styleme/views/historial/historial_screen.dart';
import 'package:styleme/views/perfil/perfil_screen.dart';
import 'package:styleme/widgets/outfit_card.dart';
import 'package:styleme/widgets/loading_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabActual = 0;
  final String _temporada = 'invierno';

  final List<Widget> _pantallas = [
    const _HomeTab(),
    const GuardarropaScreen(),
    const HistorialScreen(),
    const PerfilScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Cargar datos iniciales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarDatosIniciales();
    });
  }

  Future<void> _cargarDatosIniciales() async {
    final recCtrl = context.read<RecomendacionController>();
    final guarCtrl = context.read<GuardarropaController>();
    await recCtrl.cargarOutfitsDiarios(temporada: _temporada);
    guarCtrl.cargarPrendas(resetear: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabActual,
        children: _pantallas,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: StyleMeTheme.surface,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _tabActual,
          onTap: (i) => setState(() => _tabActual = i),
          backgroundColor: Colors.transparent,
          selectedItemColor: StyleMeTheme.primary,
          unselectedItemColor: StyleMeTheme.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.checkroom_outlined), activeIcon: Icon(Icons.checkroom), label: 'Armario'),
            BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'Historial'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}

// ── Tab de inicio ──────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final authCtrl = context.watch<AuthController>();
    final recCtrl = context.watch<RecomendacionController>();
    final nombre = authCtrl.usuario?.nombre.split(' ').first ?? 'usuario';

    return Scaffold(
      backgroundColor: StyleMeTheme.background,
      body: CustomScrollView(
        slivers: [
          // Header con saludo
          SliverAppBar(
            backgroundColor: StyleMeTheme.background,
            expandedHeight: 120,
            floating: true,
            snap: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hola, $nombre 👋',
                              style: GoogleFonts.poppins(
                                color: StyleMeTheme.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '¿Qué te vas a poner hoy?',
                              style: GoogleFonts.poppins(
                                color: StyleMeTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        // Avatar
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            gradient: StyleMeTheme.gradientePrimario,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              authCtrl.usuario?.inicial ?? 'S',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Sección outfits del día
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _sectionHeader('Outfits del día', onRefresh: () {
                  context.read<RecomendacionController>().cargarOutfitsDiarios();
                }),
                const SizedBox(height: 12),
                _buildOutfitsDiarios(context, recCtrl),
                const SizedBox(height: 24),
                _buildAccesosRapidos(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String titulo, {VoidCallback? onRefresh}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          titulo,
          style: GoogleFonts.poppins(
            color: StyleMeTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (onRefresh != null)
          IconButton(
            icon: const Icon(Icons.refresh, color: StyleMeTheme.primary, size: 20),
            onPressed: onRefresh,
            tooltip: 'Regenerar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  Widget _buildOutfitsDiarios(BuildContext context, RecomendacionController recCtrl) {
    if (recCtrl.estado == RecomendacionEstado.cargando) {
      return const SizedBox(
        height: 200,
        child: LoadingWidget(mensaje: 'Generando outfits del día...'),
      );
    }

    if (recCtrl.outfitsDelDia.isEmpty) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: StyleMeTheme.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.checkroom, color: StyleMeTheme.textSecondary, size: 32),
              const SizedBox(height: 8),
              Text(
                'Agrega prendas a tu armario',
                style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 340,
      child: PageView.builder(
        itemCount: recCtrl.outfitsDelDia.length,
        controller: PageController(viewportFraction: 0.92),
        itemBuilder: (_, i) {
          final outfit = recCtrl.outfitsDelDia[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutfitCard(
              outfit: outfit,
              mostrarFeedback: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccesosRapidos(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accesos rápidos',
          style: GoogleFonts.poppins(
            color: StyleMeTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _accesoRapido(
                context,
                icono: Icons.add_photo_alternate,
                titulo: 'Agregar\nprenda',
                onTap: () => Navigator.pushNamed(context, '/agregar-prenda'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _accesoRapido(
                context,
                icono: Icons.auto_awesome,
                titulo: 'Crear\noutfit',
                onTap: () => Navigator.pushNamed(context, '/recomendacion'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _accesoRapido(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: StyleMeTheme.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: StyleMeTheme.sombraCard,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: StyleMeTheme.gradientePrimario,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo,
                style: GoogleFonts.poppins(
                  color: StyleMeTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: StyleMeTheme.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

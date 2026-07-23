// StyleMe - Home Screen principal con bottom navigation
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/auth_controller.dart';
import 'package:styleme/controllers/guardarropa_controller.dart';
import 'package:styleme/controllers/recomendacion_controller.dart';
import 'package:styleme/models/outfit_ia_model.dart';
import 'package:styleme/views/guardarropa/guardarropa_screen.dart';
import 'package:styleme/views/historial/historial_screen.dart';
import 'package:styleme/views/perfil/perfil_screen.dart';
import 'package:styleme/controllers/historial_controller.dart';
import 'package:styleme/widgets/glass_kit.dart';
import 'package:styleme/widgets/outfit_visual_card.dart';
import 'package:styleme/widgets/loading_widget.dart';

const _naranja = Color(0xFFFF6B00);

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

  // Permite que widgets hijos naveguen entre tabs
  void navegarA(int index) => setState(() => _tabActual = index);

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
    // Cargar outfits KNN y guardarropa en paralelo
    await Future.wait([
      recCtrl.cargarOutfitsDiarios(temporada: _temporada),
      guarCtrl.cargarPrendas(resetear: true),
    ]);
    // Lanzar generación IA (lenta) sin bloquear la UI
    recCtrl.cargarOutfitsIA(temporada: _temporada);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabActual,
        children: _pantallas,
      ),
      bottomNavigationBar: GlassBottomNav(
        currentIndex: _tabActual,
        onTap: (i) => setState(() => _tabActual = i),
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
                child: FadeSlideIn(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Hola, $nombre 👋',
                            style: GoogleFonts.poppins(
                              color: StyleMeTheme.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
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
                      // Avatar glass (foto si existe, inicial como fallback)
                      Container(
                        width: 46,
                        height: 46,
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
                                  width: 46,
                                  height: 46,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(
                                      authCtrl.usuario?.inicial ?? 'S',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Secciones principales
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Sección IA ─────────────────────────────
                FadeSlideIn(
                  delay: const Duration(milliseconds: 60),
                  child: _sectionHeader(
                    'Tu look de hoy con IA',
                    onRefresh: () =>
                        context.read<RecomendacionController>().cargarOutfitsIA(),
                  ),
                ),
                const SizedBox(height: 12),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: _buildSeccionIA(context, recCtrl),
                ),
                const SizedBox(height: 24),

                // ── Sección outfits clásicos ────────────────
                FadeSlideIn(
                  delay: const Duration(milliseconds: 180),
                  child: _sectionHeader('Combinaciones del día', onRefresh: () {
                    context.read<RecomendacionController>().cargarOutfitsDiarios();
                  }),
                ),
                const SizedBox(height: 12),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 240),
                  child: _buildOutfitsDiarios(context, recCtrl),
                ),
                const SizedBox(height: 24),

                FadeSlideIn(
                  delay: const Duration(milliseconds: 300),
                  child: _buildAccesosRapidos(context),
                ),
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

  // ── Sección Outfits IA ──────────────────────────────────────
  Widget _buildSeccionIA(BuildContext context, RecomendacionController recCtrl) {
    // Estado: generando → skeleton naranja
    if (recCtrl.generandoIA) {
      return _buildSkeletonIA();
    }

    // Estado: sin foto de perfil → banner de acción
    if (recCtrl.sinFotoPerfil) {
      return _buildBannerSinFoto(context);
    }

    // Estado: error
    if (recCtrl.errorIA != null) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: StyleMeTheme.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            recCtrl.errorIA!,
            style: GoogleFonts.poppins(
              color: StyleMeTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    // Estado: sin outfits IA aún
    if (recCtrl.outfitsIA.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: StyleMeTheme.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome,
                  color: StyleMeTheme.textSecondary, size: 28),
              const SizedBox(height: 6),
              Text(
                'Agrega prendas para generar tu look',
                style: GoogleFonts.poppins(
                    color: StyleMeTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // Estado: outfits IA listos → carrusel de tarjetas
    return SizedBox(
      height: 320,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recCtrl.outfitsIA.length,
        itemBuilder: (_, i) {
          final outfit = recCtrl.outfitsIA[i];
          return Padding(
            padding: EdgeInsets.only(right: i < recCtrl.outfitsIA.length - 1 ? 14 : 0),
            child: GestureDetector(
              onTap: () => _abrirOutfitIAModal(context, outfit),
              child: _OutfitIACard(outfit: outfit),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeletonIA() {
    return SizedBox(
      height: 320,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (_, i) => Padding(
          padding: EdgeInsets.only(right: i < 2 ? 14 : 0),
          child: const _SkeletonCard(),
        ),
      ),
    );
  }

  Widget _buildBannerSinFoto(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _naranja.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _naranja.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _naranja.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_a_photo, color: _naranja, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agrega tu foto de perfil',
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Para ver cómo te ves con cada outfit generado por IA',
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              // Navegar a la pestaña Perfil (índice 3)
              final homeState = context.findAncestorStateOfType<_HomeScreenState>();
              homeState?.navegarA(3);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _naranja,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Ir',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirOutfitIAModal(BuildContext context, OutfitIAModel outfit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: StyleMeTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        builder: (__, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: StyleMeTheme.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Imagen IA grande
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  base64Decode(outfit.imagenGeneradaBase64),
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              // Info prenda base
              Text(
                '${outfit.tipoPrendaBase} · ${outfit.colorPrendaBase}',
                style: GoogleFonts.poppins(
                  color: StyleMeTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${outfit.totalComplementos} complementos sugeridos',
                style: GoogleFonts.poppins(
                  color: StyleMeTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              // Tag tiempo generación
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _naranja.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _naranja.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Generado por CatVTON en ${outfit.tiempoGeneracion.toStringAsFixed(1)}s',
                  style: GoogleFonts.poppins(
                    color: _naranja,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recCtrl.outfitsDelDia.length,
        itemBuilder: (_, i) {
          final outfit = recCtrl.outfitsDelDia[i];
          return Padding(
            padding: EdgeInsets.only(right: 12, left: i == 0 ? 0 : 0),
            child: GestureDetector(
              onTap: () => _abrirOutfitModal(context, outfit),
              child: OutfitVisualCard.fromOutfitModel(
                outfit: outfit,
                modoCompacto: true,
              ),
            ),
          );
        },
      ),
    );
  }

  void _abrirOutfitModal(BuildContext context, outfit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: StyleMeTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (__, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: StyleMeTheme.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              OutfitVisualCard.fromOutfitModel(
                outfit: outfit,
                titulo: 'Outfit del día',
                onFeedback: (tipo) {
                  context.read<HistorialController>().darFeedback(outfit.id, tipo);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
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
                titulo: 'Agregar prenda',
                onTap: () => Navigator.pushNamed(context, '/agregar-prenda'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _accesoRapido(
                context,
                icono: Icons.auto_awesome,
                titulo: 'Crear outfit',
                onTap: () => Navigator.pushNamed(context, '/recomendacion'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _accesoRapido(
                context,
                icono: Icons.dry_cleaning,
                titulo: 'Virtual Try-On',
                onTap: () => Navigator.pushNamed(context, '/tryon'),
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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: StyleMeTheme.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: StyleMeTheme.sombraCard,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: StyleMeTheme.gradientePrimario,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              titulo,
              textAlign: TextAlign.center,
              softWrap: true,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: StyleMeTheme.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta de outfit generado por IA ──────────────────────
class _OutfitIACard extends StatelessWidget {
  final OutfitIAModel outfit;
  const _OutfitIACard({required this.outfit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: StyleMeTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _naranja.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _naranja.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen IA
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.memory(
                base64Decode(outfit.imagenGeneradaBase64),
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outfit.tipoPrendaBase,
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: StyleMeTheme.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      outfit.colorPrendaBase,
                      style: GoogleFonts.poppins(
                        color: StyleMeTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _naranja.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'IA',
                        style: GoogleFonts.poppins(
                          color: _naranja,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton loader con shimmer naranja ─────────────────────
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 200,
        decoration: BoxDecoration(
          color: StyleMeTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: _naranja.withValues(alpha: _anim.value * 0.5), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen placeholder
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  color:
                      _naranja.withValues(alpha: _anim.value * 0.25),
                ),
              ),
            ),
            // Texto placeholder
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 13,
                    width: 100,
                    decoration: BoxDecoration(
                      color: StyleMeTheme.surface.withValues(alpha: _anim.value + 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 70,
                    decoration: BoxDecoration(
                      color: StyleMeTheme.surface.withValues(alpha: _anim.value + 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

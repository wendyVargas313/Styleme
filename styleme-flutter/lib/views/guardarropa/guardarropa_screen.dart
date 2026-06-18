// StyleMe - Pantalla del Guardarropa
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:styleme/app/routes.dart';
import 'package:styleme/config/constants.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/guardarropa_controller.dart';
import 'package:styleme/views/guardarropa/detalle_prenda_screen.dart';
import 'package:styleme/widgets/glass_kit.dart';
import 'package:styleme/widgets/prenda_card.dart';

class GuardarropaScreen extends StatefulWidget {
  const GuardarropaScreen({super.key});

  @override
  State<GuardarropaScreen> createState() => _GuardarropaScreenState();
}

class _GuardarropaScreenState extends State<GuardarropaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GuardarropaController>().cargarPrendas(resetear: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GuardarropaController>();

    return Scaffold(
      backgroundColor: StyleMeTheme.background,
      appBar: GlassAppBar(
        title: 'Mi Armario',
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, color: StyleMeTheme.primary),
            onPressed: () => _mostrarStats(context, ctrl),
            tooltip: 'Estadísticas',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros horizontales
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: _buildFiltros(ctrl),
          ),
          // Grid de prendas
          Expanded(
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: _buildGrid(ctrl),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: StyleMeTheme.naranjaGlow,
        ),
        child: FloatingActionButton(
          onPressed: () async {
            await Navigator.pushNamed(context, AppRoutes.agregarPrenda);
            if (mounted) ctrl.cargarPrendas(resetear: true);
          },
          backgroundColor: StyleMeTheme.primary,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFiltros(GuardarropaController ctrl) {
    final filtros = [
      ('Todo', null, null, null),
      ...AppConstants.tiposPrendas.take(8).map((t) => (t, t, null, null)),
    ];

    return Column(
      children: [
        // Filtros por tipo
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtros.length,
            itemBuilder: (_, i) {
              final (label, tipo, color, temporada) = filtros[i];
              final activo = tipo == ctrl.filtroTipo && color == ctrl.filtroColor;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: activo ? Colors.white : StyleMeTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  selected: activo,
                  onSelected: (_) {
                    if (tipo == null) {
                      ctrl.limpiarFiltros();
                    } else {
                      ctrl.aplicarFiltros(tipo: tipo);
                    }
                  },
                  backgroundColor: StyleMeTheme.card,
                  selectedColor: StyleMeTheme.primary,
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                    color: activo ? StyleMeTheme.primary : Colors.transparent,
                  ),
                  showCheckmark: false,
                ),
              );
            },
          ),
        ),
        // Filtros por temporada
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: AppConstants.temporadas.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                final activo = ctrl.filtroTemporada == null;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('Todas', style: GoogleFonts.poppins(color: activo ? Colors.white : StyleMeTheme.textSecondary, fontSize: 12)),
                    selected: activo,
                    onSelected: (_) => ctrl.aplicarFiltros(tipo: ctrl.filtroTipo, color: ctrl.filtroColor),
                    backgroundColor: StyleMeTheme.card,
                    selectedColor: StyleMeTheme.primaryDark,
                    showCheckmark: false,
                    side: BorderSide.none,
                  ),
                );
              }
              final t = AppConstants.temporadas[i - 1];
              final activo = ctrl.filtroTemporada == t;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    '${AppConstants.temporadasIconos[t]} $t',
                    style: GoogleFonts.poppins(color: activo ? Colors.white : StyleMeTheme.textSecondary, fontSize: 12),
                  ),
                  selected: activo,
                  onSelected: (_) => ctrl.aplicarFiltros(
                    tipo: ctrl.filtroTipo,
                    color: ctrl.filtroColor,
                    temporada: activo ? null : t,
                  ),
                  backgroundColor: StyleMeTheme.card,
                  selectedColor: StyleMeTheme.primaryDark,
                  showCheckmark: false,
                  side: BorderSide.none,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildGrid(GuardarropaController ctrl) {
    if (ctrl.estado == GuardarropaEstado.cargando && ctrl.prendas.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: StyleMeTheme.primary),
      );
    }

    if (ctrl.prendas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.checkroom, color: StyleMeTheme.textSecondary, size: 52),
            const SizedBox(height: 12),
            Text(
              'Tu armario está vacío',
              style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Agrega tu primera prenda\npresionando el botón +',
              style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: StyleMeTheme.primary,
      onRefresh: () => ctrl.cargarPrendas(resetear: true),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: ctrl.prendas.length,
        itemBuilder: (_, i) => PrendaCard(
          prenda: ctrl.prendas[i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetallePrendaScreen(prenda: ctrl.prendas[i])),
          ),
        ),
      ),
    );
  }

  void _mostrarStats(BuildContext context, GuardarropaController ctrl) {
    ctrl.cargarStats();
    showModalBottomSheet(
      context: context,
      backgroundColor: StyleMeTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        builder: (_, scrollCtrl) => _StatsSheet(scrollCtrl: scrollCtrl),
      ),
    );
  }
}

class _StatsSheet extends StatelessWidget {
  final ScrollController scrollCtrl;
  const _StatsSheet({required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<GuardarropaController>().stats;

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(width: 36, height: 4, decoration: BoxDecoration(color: StyleMeTheme.textSecondary, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Estadísticas', style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              if (stats.isEmpty)
                const Center(child: CircularProgressIndicator(color: StyleMeTheme.primary))
              else ...[
                _statRow('Total prendas', '${stats['total_prendas'] ?? 0}'),
                _statRow('Nunca usadas', '${stats['prendas_nunca_usadas'] ?? 0}'),
                const SizedBox(height: 12),
                _distribucion('Por tipo', stats['por_tipo'] as Map? ?? {}),
                const SizedBox(height: 12),
                _distribucion('Por color', stats['por_color'] as Map? ?? {}),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _statRow(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary)),
          Text(valor, style: GoogleFonts.poppins(color: StyleMeTheme.primary, fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _distribucion(String titulo, Map datos) {
    if (datos.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: GoogleFonts.poppins(color: StyleMeTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        ...datos.entries.take(6).map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(child: Text(e.key.toString(), style: GoogleFonts.poppins(color: StyleMeTheme.textSecondary, fontSize: 12))),
              Text(e.value.toString(), style: GoogleFonts.poppins(color: StyleMeTheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        )),
      ],
    );
  }
}

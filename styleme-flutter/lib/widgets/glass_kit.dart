// StyleMe - Kit de widgets glassmorphism
// GlassCard, GlassAppBar, GlassBottomNav, FadeSlideIn
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:styleme/config/theme.dart';

// ── GlassCard ───────────────────────────────────────────────
// Tarjeta con BackdropFilter blur(12) + fondo blanco 7% + borde blanco 15%
class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsets? padding;
  final double sigma;
  final VoidCallback? onTap;
  final List<BoxShadow>? boxShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = 16,
    this.padding,
    this.sigma = 12,
    this.onTap,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: boxShadow ??
                [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

// Variante con borde naranja sutil (para tarjetas destacadas)
class GlassCardOrange extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  const GlassCardOrange({
    super.key,
    required this.child,
    this.radius = 16,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: radius,
      padding: padding,
      onTap: onTap,
      boxShadow: const [
        BoxShadow(color: Color(0x1AFF6B00), blurRadius: 16, spreadRadius: 1, offset: Offset(0, 4)),
        BoxShadow(color: Colors.black26, blurRadius: 8),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: StyleMeTheme.primary.withValues(alpha: 0.35), width: 1.2),
        ),
        child: child,
      ),
    );
  }
}

// ── FadeSlideIn ─────────────────────────────────────────────
// Anima entrada: FadeIn + SlideUp desde offset (0, +20px → 0)
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 480),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ── GlassAppBar ─────────────────────────────────────────────
// AppBar transparente con blur de fondo
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final bool showBorder;

  const GlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.showBorder = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            border: showBorder
                ? Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.10),
                      width: 1,
                    ),
                  )
                : null,
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Leading
                  if (leading != null)
                    leading!
                  else if (Navigator.of(context).canPop())
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: StyleMeTheme.textPrimary, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  else
                    const SizedBox(width: 48),

                  // Title
                  Expanded(
                    child: Text(
                      title,
                      textAlign: centerTitle ? TextAlign.center : TextAlign.start,
                      style: GoogleFonts.poppins(
                        color: StyleMeTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // Actions
                  if (actions != null && actions!.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: actions!)
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── GlassBottomNav ──────────────────────────────────────────
// Bottom navigation con efecto de vidrio
class GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: onTap,
            backgroundColor: Colors.transparent,
            selectedItemColor: StyleMeTheme.primary,
            unselectedItemColor: StyleMeTheme.textSecondary,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedLabelStyle:
                GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Inicio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.checkroom_outlined),
                activeIcon: Icon(Icons.checkroom),
                label: 'Armario',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history_outlined),
                activeIcon: Icon(Icons.history),
                label: 'Historial',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── GlassGradientSection ────────────────────────────────────
// Contenedor con gradiente sutil de fondo (para secciones)
class GlassGradientSection extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const GlassGradientSection({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            StyleMeTheme.primary.withValues(alpha: 0.06),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: StyleMeTheme.primary.withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

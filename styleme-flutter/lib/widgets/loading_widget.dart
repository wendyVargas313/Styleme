// StyleMe - Widget de loading con animación ML
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:styleme/config/theme.dart';

class LoadingWidget extends StatefulWidget {
  final String mensaje;
  final bool fullScreen;

  const LoadingWidget({
    super.key,
    this.mensaje = 'Procesando...',
    this.fullScreen = false,
  });

  @override
  State<LoadingWidget> createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<LoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.8, end: 1.0).animate(
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
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _pulse,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: StyleMeTheme.gradientePrimario,
              boxShadow: StyleMeTheme.sombraNaranja,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          widget.mensaje,
          style: GoogleFonts.poppins(
            color: StyleMeTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'ML procesando tu imagen...',
          style: GoogleFonts.poppins(
            color: StyleMeTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            backgroundColor: StyleMeTheme.card,
            valueColor: const AlwaysStoppedAnimation<Color>(StyleMeTheme.primary),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );

    if (widget.fullScreen) {
      return Container(
        color: StyleMeTheme.background,
        child: Center(child: content),
      );
    }

    return Center(child: content);
  }
}

// Loading overlay para superponerse sobre otra pantalla
class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool cargando;
  final String mensaje;

  const LoadingOverlay({
    super.key,
    required this.child,
    required this.cargando,
    this.mensaje = 'Analizando con ML...',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (cargando)
          Container(
            color: Colors.black.withValues(alpha: 0.75),
            child: LoadingWidget(mensaje: mensaje, fullScreen: true),
          ),
      ],
    );
  }
}

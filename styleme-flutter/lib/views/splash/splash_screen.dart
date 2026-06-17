// StyleMe - Splash Screen con animación
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:styleme/app/routes.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/auth_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );

    _ctrl.forward();
    _inicializar();
  }

  Future<void> _inicializar() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final authCtrl = context.read<AuthController>();
    await authCtrl.verificarSesion();

    if (!mounted) return;
    if (authCtrl.estaAutenticado) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StyleMeTheme.background,
      body: Stack(
        children: [
          // Partículas decorativas naranjas
          ...List.generate(6, (i) => _particula(i)),
          // Logo central
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo círculo naranja
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: StyleMeTheme.gradientePrimario,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: StyleMeTheme.primary.withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.checkroom,
                        color: Colors.white,
                        size: 52,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Nombre app
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          StyleMeTheme.gradientePrimario.createShader(bounds),
                      child: Text(
                        'StyleMe',
                        style: GoogleFonts.poppins(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tu guardarropa inteligente',
                      style: GoogleFonts.poppins(
                        color: StyleMeTheme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Indicador de carga
                    SizedBox(
                      width: 140,
                      child: LinearProgressIndicator(
                        backgroundColor: StyleMeTheme.surface,
                        valueColor: const AlwaysStoppedAnimation<Color>(StyleMeTheme.primary),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Créditos al fondo
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Text(
                'Universidad Manuela Beltrán • Bogotá',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: StyleMeTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _particula(int index) {
    final posiciones = [
      const Offset(40, 120), const Offset(300, 80),
      const Offset(80, 500), const Offset(340, 400),
      const Offset(160, 680), const Offset(260, 200),
    ];
    final tamanios = [8.0, 12.0, 6.0, 10.0, 7.0, 9.0];
    final opacidades = [0.15, 0.10, 0.20, 0.12, 0.18, 0.14];

    return Positioned(
      left: posiciones[index].dx,
      top: posiciones[index].dy,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          width: tamanios[index],
          height: tamanios[index],
          decoration: BoxDecoration(
            color: StyleMeTheme.primary.withValues(alpha: opacidades[index]),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

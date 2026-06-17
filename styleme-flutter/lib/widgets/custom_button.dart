// StyleMe - Botón personalizado con gradiente naranja
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:styleme/config/theme.dart';

class CustomButton extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;
  final bool outline;
  final IconData? icono;
  final double? ancho;
  final double alto;

  const CustomButton({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
    this.outline = false,
    this.icono,
    this.ancho,
    this.alto = 52,
  });

  @override
  Widget build(BuildContext context) {
    if (outline) {
      return SizedBox(
        width: ancho ?? double.infinity,
        height: alto,
        child: OutlinedButton(
          onPressed: cargando ? null : onPressed,
          child: _contenido(),
        ),
      );
    }

    return Container(
      width: ancho ?? double.infinity,
      height: alto,
      decoration: BoxDecoration(
        gradient: onPressed != null && !cargando
            ? StyleMeTheme.gradientePrimario
            : const LinearGradient(
                colors: [Color(0xFF555555), Color(0xFF444444)],
              ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: onPressed != null && !cargando ? StyleMeTheme.sombraNaranja : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: cargando ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(child: _contenido()),
        ),
      ),
    );
  }

  Widget _contenido() {
    if (cargando) {
      return const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (icono != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 20, color: outline ? StyleMeTheme.primary : Colors.white),
          const SizedBox(width: 8),
          Text(
            texto,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: outline ? StyleMeTheme.primary : Colors.white,
            ),
          ),
        ],
      );
    }

    return Text(
      texto,
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: outline ? StyleMeTheme.primary : Colors.white,
      ),
    );
  }
}

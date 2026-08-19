// StyleMe - Rutas nombradas de la aplicación
import 'package:flutter/material.dart';
import 'package:styleme/models/prenda_model.dart';
import 'package:styleme/views/agente/agente_evento_screen.dart';
import 'package:styleme/views/agente/detalle_recomendacion_screen.dart';
import 'package:styleme/views/agente/historial_eventos_screen.dart';
import 'package:styleme/views/auth/guest_screen.dart';
import 'package:styleme/views/auth/login_screen.dart';
import 'package:styleme/views/auth/register_screen.dart';
import 'package:styleme/views/guardarropa/agregar_prenda_screen.dart';
import 'package:styleme/views/home/home_screen.dart';
import 'package:styleme/views/recomendacion/recomendacion_screen.dart';
import 'package:styleme/views/splash/splash_screen.dart';
import 'package:styleme/views/tryon/tryon_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String registro = '/registro';
  static const String invitado = '/invitado';
  static const String home = '/home';
  static const String agregarPrenda = '/agregar-prenda';
  static const String recomendacion = '/recomendacion';
  static const String tryon = '/tryon';
  static const String agenteEvento = '/agente-evento';
  static const String historialEventos = '/historial-eventos';
  static const String detalleRecomendacion = '/detalle-recomendacion';

  static Map<String, WidgetBuilder> get rutas => {
        splash: (_) => const SplashScreen(),
        login: (_) => const LoginScreen(),
        registro: (_) => const RegisterScreen(),
        invitado: (_) => const GuestScreen(),
        home: (_) => const HomeScreen(),
        agregarPrenda: (_) => const AgregarPrendaScreen(),
        recomendacion: (ctx) {
          // Acepta una PrendaModel como argumento opcional
          final prenda = ModalRoute.of(ctx)?.settings.arguments as PrendaModel?;
          return RecomendacionScreen(prendaInicial: prenda);
        },
        tryon: (_) => const TryonScreen(),
        agenteEvento: (_) => const AgenteEventoScreen(),
        historialEventos: (_) => const HistorialEventosScreen(),
        detalleRecomendacion: (ctx) {
          // Requiere el id de la recomendación como argumento
          final id = ModalRoute.of(ctx)?.settings.arguments as String;
          return DetalleRecomendacionScreen(id: id);
        },
      };
}

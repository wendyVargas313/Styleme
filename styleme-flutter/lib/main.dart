// StyleMe - Punto de entrada principal
// Universidad Manuela Beltrán — Trabajo de Grado Ingeniería de Software
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:styleme/app/app.dart';
import 'package:styleme/services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Forzar orientación vertical
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Estilo del status bar (transparente, iconos claros)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF1A1A1A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Inicializar el servicio API (Dio)
  ApiService().init();

  runApp(const StyleMeApp());
}

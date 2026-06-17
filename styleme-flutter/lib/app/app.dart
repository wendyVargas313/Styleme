// StyleMe - Configuración principal de la aplicación MaterialApp
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:styleme/app/routes.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/auth_controller.dart';
import 'package:styleme/controllers/guardarropa_controller.dart';
import 'package:styleme/controllers/historial_controller.dart';
import 'package:styleme/controllers/recomendacion_controller.dart';

class StyleMeApp extends StatelessWidget {
  const StyleMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => GuardarropaController()),
        ChangeNotifierProvider(create: (_) => RecomendacionController()),
        ChangeNotifierProvider(create: (_) => HistorialController()),
      ],
      child: MaterialApp(
        title: 'StyleMe',
        debugShowCheckedModeBanner: false,
        theme: StyleMeTheme.tema,
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.rutas,
      ),
    );
  }
}

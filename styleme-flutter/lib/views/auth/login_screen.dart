// StyleMe - Pantalla de inicio de sesión
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:styleme/app/routes.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/auth_controller.dart';
import 'package:styleme/widgets/custom_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _verPassword = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authCtrl = context.read<AuthController>();
    final exito = await authCtrl.login(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );

    if (!mounted) return;
    if (exito) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authCtrl.mensajeError ?? 'Error al iniciar sesión'),
          backgroundColor: StyleMeTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authCtrl = context.watch<AuthController>();
    final cargando = authCtrl.estado == AuthEstado.cargando;

    return Scaffold(
      backgroundColor: StyleMeTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 48),
                // Logo
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: StyleMeTheme.gradientePrimario,
                    shape: BoxShape.circle,
                    boxShadow: StyleMeTheme.sombraNaranja,
                  ),
                  child: const Icon(Icons.checkroom, color: Colors.white, size: 38),
                ),
                const SizedBox(height: 16),
                ShaderMask(
                  shaderCallback: (b) => StyleMeTheme.gradientePrimario.createShader(b),
                  child: Text(
                    'StyleMe',
                    style: GoogleFonts.poppins(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bienvenido de vuelta',
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 40),
                // Campo email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu email';
                    if (!v.contains('@')) return 'Email no válido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Campo contraseña
                TextFormField(
                  controller: _passCtrl,
                  obscureText: !_verPassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _verPassword = !_verPassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                // Botón iniciar sesión
                CustomButton(
                  texto: 'Iniciar sesión',
                  onPressed: cargando ? null : _login,
                  cargando: cargando,
                  icono: Icons.login,
                ),
                const SizedBox(height: 16),
                // Botón probar sin cuenta
                CustomButton(
                  texto: 'Probar sin cuenta',
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.invitado),
                  outline: true,
                  icono: Icons.explore,
                ),
                const SizedBox(height: 28),
                // Link a registro
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿No tienes cuenta? ',
                      style: GoogleFonts.poppins(
                        color: StyleMeTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.registro),
                      child: Text(
                        'Regístrate',
                        style: GoogleFonts.poppins(
                          color: StyleMeTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

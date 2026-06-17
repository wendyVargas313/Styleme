// StyleMe - Pantalla de registro
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:styleme/app/routes.dart';
import 'package:styleme/config/constants.dart';
import 'package:styleme/config/theme.dart';
import 'package:styleme/controllers/auth_controller.dart';
import 'package:styleme/widgets/custom_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  String _generoSeleccionado = 'femenino';
  bool _aceptaTerminos = false;
  bool _verPassword = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _registro() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_aceptaTerminos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acepta los términos y condiciones')),
      );
      return;
    }

    final authCtrl = context.read<AuthController>();
    final exito = await authCtrl.registro(
      nombre: _nombreCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      genero: _generoSeleccionado,
    );

    if (!mounted) return;
    if (exito) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authCtrl.mensajeError ?? 'Error al registrarse'),
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
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        backgroundColor: StyleMeTheme.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Únete a StyleMe',
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Tu guardarropa inteligente te espera',
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                // Nombre
                TextFormField(
                  controller: _nombreCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 2) return 'Ingresa tu nombre';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || !v.contains('@')) return 'Email no válido';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                // Password
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
                    if (v == null || v.length < 8) return 'Mínimo 8 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                // Confirmar password
                TextFormField(
                  controller: _confirmPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) {
                    if (v != _passCtrl.text) return 'Las contraseñas no coinciden';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Selector de género
                Text(
                  'Género',
                  style: GoogleFonts.poppins(
                    color: StyleMeTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: AppConstants.generos.map((g) {
                    final seleccionado = g == _generoSeleccionado;
                    return ChoiceChip(
                      label: Text(
                        g[0].toUpperCase() + g.substring(1),
                        style: GoogleFonts.poppins(
                          color: seleccionado ? Colors.white : StyleMeTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      selected: seleccionado,
                      selectedColor: StyleMeTheme.primary,
                      backgroundColor: StyleMeTheme.card,
                      onSelected: (_) => setState(() => _generoSeleccionado = g),
                      side: BorderSide(
                        color: seleccionado ? StyleMeTheme.primary : Colors.transparent,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                // Términos y condiciones
                Row(
                  children: [
                    Checkbox(
                      value: _aceptaTerminos,
                      onChanged: (v) => setState(() => _aceptaTerminos = v ?? false),
                      activeColor: StyleMeTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    Expanded(
                      child: Text(
                        'Acepto los términos y condiciones de StyleMe',
                        style: GoogleFonts.poppins(
                          color: StyleMeTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Botón crear cuenta
                CustomButton(
                  texto: 'Crear cuenta',
                  onPressed: cargando ? null : _registro,
                  cargando: cargando,
                  icono: Icons.person_add,
                ),
                const SizedBox(height: 20),
                // Link a login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿Ya tienes cuenta? ',
                      style: GoogleFonts.poppins(
                        color: StyleMeTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'Inicia sesión',
                        style: GoogleFonts.poppins(
                          color: StyleMeTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

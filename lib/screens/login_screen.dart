import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/configuracion_store.dart';
import '../data/usuarios_store.dart';
import '../models/mock_user.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import 'home_screen.dart';

// Login: correo + contraseña contra `usuarios`.
// TODO backend: reemplazar _submit() por la autenticación real.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _imagenLogin = 'assets/images/login_cocina.jpg';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1)); // simula latencia de red
    setState(() => _isLoading = false);

    if (!mounted) return;

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    MockUser? usuario;
    for (final u in usuarios) {
      if (u.email.toLowerCase() == email && u.password == password) {
        usuario = u;
        break;
      }
    }

    if (usuario == null) {
      showAppToast(
        context,
        'Correo o contraseña incorrectos',
        type: ToastType.error,
      );
      return;
    }

    if (!usuario.activo) {
      showAppToast(
        context,
        'Este usuario está inactivo',
        type: ToastType.error,
      );
      return;
    }

    final sede =
        sedes.where((s) => s.id == usuario!.sedeId).firstOrNull ??
        sedes.first;
    final usuarioEncontrado = usuario;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(sede: sede, usuario: usuarioEncontrado),
      ),
    );
  }

  Widget _etiqueta(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
  );

  InputDecoration _decoracion(String hint, IconData icono, {Widget? sufijo}) {
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
      prefixIcon: Icon(icono, size: 18, color: Colors.grey.shade600),
      suffixIcon: sufijo,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: borde,
      enabledBorder: borde,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryGreenDark, width: 1.5),
      ),
    );
  }

  Widget _formulario(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Image.asset('assets/images/logo_bijao.png', height: 38),
          ),
          const SizedBox(height: 32),
          const Text(
            'Bienvenido',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ingresa tus credenciales para continuar',
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 30),
          _etiqueta('Correo electrónico'),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 14),
            decoration: _decoracion('Ingresa tu correo', LucideIcons.mail),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa tu correo';
              }
              if (!value.contains('@')) return 'Correo inválido';
              return null;
            },
          ),
          const SizedBox(height: 18),
          _etiqueta('Contraseña'),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(fontSize: 14),
            onFieldSubmitted: (_) => _isLoading ? null : _submit(),
            decoration: _decoracion(
              'Ingresa tu contraseña',
              LucideIcons.lock,
              sufijo: IconButton(
                icon: Icon(
                  _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa tu contraseña';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryGreenDark,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.7),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryGreenDark,
                      ),
                    )
                  : const Text(
                      'Iniciar sesión',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _copyright() => Text(
    '© ${DateTime.now().year} Kumo Systems. Todos los derechos reservados',
    textAlign: TextAlign.center,
    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
  );

  Widget _foto({double? alto, BorderRadius? radio}) {
    return ClipRRect(
      borderRadius: radio ?? BorderRadius.zero,
      child: Image.asset(
        _imagenLogin,
        fit: BoxFit.cover,
        width: double.infinity,
        height: alto ?? double.infinity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = AppBreakpoints.esMobile(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: mobile ? _buildMobile(context) : _buildEscritorio(context),
    );
  }

  // Mobile: foto arriba, panel verde con el formulario debajo.
  Widget _buildMobile(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _foto(alto: 170, radio: BorderRadius.circular(20)),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _formulario(context),
                  const SizedBox(height: 24),
                  _copyright(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Escritorio y tablet: tarjeta con foto a la izquierda y panel verde con
  // el formulario a la derecha.
  Widget _buildEscritorio(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 640),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  Expanded(child: _foto()),
                  Expanded(
                    child: Container(
                      color: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 32,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                child: _formulario(context),
                              ),
                            ),
                          ),
                          _copyright(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

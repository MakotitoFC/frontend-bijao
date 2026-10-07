import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/configuracion_store.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/patron_cocina.dart';
import '../widgets/server_connection_dialog.dart';
import 'home_screen.dart';

// Login: correo + contraseña contra `usuarios`.
// TODO backend: reemplazar _submit() por la autenticación real.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _recordarme = false;

  @override
  void initState() {
    super.initState();
    if (AuthService.instance.isAuthenticated && AuthService.instance.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final user = AuthService.instance.currentUser!;
        final sede = sedes.where((s) => s.id == user.sedeId).firstOrNull ?? sedes.first;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(sede: sede, usuario: user),
          ),
        );
      });
    }

    AuthService.instance.getSavedEmail().then((saved) {
      if (saved != null && saved.isNotEmpty && mounted) {
        setState(() {
          _emailController.text = saved;
          _recordarme = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final identifier = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.instance.login(
        usuario: identifier,
        password: password,
        rememberEmail: _recordarme,
      );

      if (!mounted) return;

      final sede = sedes.where((s) => s.id == user.sedeId).firstOrNull ?? sedes.first;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(sede: sede, usuario: user),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        e.toString(),
        type: ToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _decoracion(String hint, IconData icono, {Widget? sufijo}) {
    final linea = UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    return InputDecoration(
      filled: false,
      hintText: hint,
      hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
      prefixIcon: Icon(icono, size: 18, color: Colors.grey.shade500),
      suffixIcon: sufijo,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      border: linea,
      enabledBorder: linea,
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: _fondoVerde, width: 2),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }

  // Formulario sobre el lado blanco.
  Widget _formulario(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Iniciar sesión',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF3D4452),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: _fondoVerde,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ingresa tus credenciales para continuar',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 34),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.text,
            style: const TextStyle(fontSize: 14),
            decoration: _decoracion('Usuario o correo', LucideIcons.user),
            validator: (value) {
              final v = value?.trim();
              if (v == null || v.isEmpty) {
                return 'Ingresa tu usuario o correo';
              }
              if (v.length < 3) {
                return 'Debe tener al menos 3 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(fontSize: 14),
            onFieldSubmitted: (_) => _isLoading ? null : _submit(),
            decoration: _decoracion(
              'Contraseña',
              LucideIcons.lock,
              sufijo: IconButton(
                icon: Icon(
                  _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: 18,
                  color: Colors.grey.shade500,
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
          const SizedBox(height: 18),
          _recordarmeYOlvido(),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _fondoVerde,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _fondoVerde.withValues(alpha: 0.6),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'INGRESAR',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.8,
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              children: const [
                TextSpan(text: '¿Problemas para ingresar? '),
                TextSpan(
                  text: 'Contacta al administrador',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Casilla "Recordarme" y enlace de contraseña olvidada.
  Widget _recordarmeYOlvido() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _recordarme = !_recordarme),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _recordarme,
                    onChanged: (v) => setState(() => _recordarme = v ?? false),
                    activeColor: _fondoVerde,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Recordarme',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => showAppToast(
            context,
            'Contacta al administrador para restablecer tu contraseña.',
            type: ToastType.info,
            titulo: 'Contraseña olvidada',
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '¿Olvidaste tu contraseña?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _fondoVerde,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Lado verde: título, descripción y ventajas del sistema.
  Widget _bienvenida() {
    const alinTexto = TextAlign.start;
    final titulo = GoogleFonts.spaceGrotesk(
      fontSize: 46,
      height: 1.05,
      fontWeight: FontWeight.w700,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sistema POS',
          textAlign: alinTexto,
          style: titulo.copyWith(color: Colors.white),
        ),
        Text(
          'Control total',
          textAlign: alinTexto,
          style: titulo.copyWith(
            color: _verdeNeon,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Desde la primera orden hasta la última mesa. Acceso seguro para '
          'equipos que nunca se detienen.',
          textAlign: alinTexto,
          style: TextStyle(
            fontSize: 14,
            height: 1.55,
            color: const Color(0xFF9CC9B0).withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 44),
        _ventaja(LucideIcons.zap, 'Rápido: Toma órdenes en segundos'),
        _ventaja(LucideIcons.chartLine, 'Claro: Reportes en tiempo real'),
        _ventaja(LucideIcons.shieldCheck, 'Seguro: Datos protegidos'),
      ],
    );
  }

  static const _verdeNeon = Color(0xFF3DFF7A);

  Widget _ventaja(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 22, color: _verdeNeon),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  static const _fondoVerde = Color(0xFF0A3622);

  Widget _copyright(Color color, {TextAlign alinear = TextAlign.center}) =>
      Text(
        '© ${DateTime.now().year} Kumo Systems. Todos los derechos reservados',
        textAlign: alinear,
        style: TextStyle(fontSize: 12, color: color),
      );

  @override
  Widget build(BuildContext context) {
    final mobile = AppBreakpoints.esMobile(context);
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'server_conn_btn',
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.black87,
        elevation: 1,
        onPressed: () => ServerConnectionDialog.show(context),
        icon: const Icon(LucideIcons.wifi, size: 16),
        label: const Text('Servidor / Red', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      body: mobile ? _buildMobile(context) : _buildEscritorio(context),
    );
  }

  // Mobile: solo el ingreso de credenciales; el panel verde se oculta.
  Widget _buildMobile(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: _formulario(context),
          ),
        ),
      ),
    );
  }

  // Escritorio y tablet: la vista se parte a la mitad, verde (mezclado con el
  // oscuro) y blanco, cada lado con su patrón de íconos de cocina.
  Widget _buildEscritorio(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipPath(
            clipper: const _BordeZigzag(),
            child: Container(
              color: _fondoVerde,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: PatronCocina(
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(120, 32, 48, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 440,
                                ),
                                child: _bienvenida(),
                              ),
                            ),
                          ),
                        ),
                        _copyright(
                          Colors.white.withValues(alpha: 0.75),
                          alinear: TextAlign.start,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: _formulario(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Borde derecho del panel verde en zigzag (dientes hacia la sección blanca).
class _BordeZigzag extends CustomClipper<Path> {
  const _BordeZigzag();

  static const _profundidad = 18.0;
  static const _altoDiente = 36.0;

  @override
  Path getClip(Size size) {
    final dientes = math.max(2, (size.height / _altoDiente).round());
    final paso = size.height / dientes;
    final camino = Path()..moveTo(0, 0);
    for (var i = 0; i <= dientes; i++) {
      final x = i.isEven ? size.width - _profundidad : size.width;
      camino.lineTo(x, i * paso);
    }
    camino
      ..lineTo(0, size.height)
      ..close();
    return camino;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

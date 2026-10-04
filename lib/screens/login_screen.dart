import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/configuracion_store.dart';
import '../data/usuarios_store.dart';
import '../models/usuario.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/patron_cocina.dart';
import 'home_screen.dart';

// Login: correo + contraseña contra `usuarios`.
// TODO backend: reemplazar _submit() por la autenticación real.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // "Recordarme": correo guardado mientras no haya almacenamiento real.
  // TODO backend: persistir la sesión/correo en el dispositivo.
  static String? _correoRecordado;

  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(text: _correoRecordado);
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  late bool _recordarme = _correoRecordado != null;

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
    Usuario? usuario;
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

    _correoRecordado = _recordarme ? _emailController.text.trim() : null;
    final sede =
        sedes.where((s) => s.id == usuario!.sedeId).firstOrNull ?? sedes.first;
    final usuarioEncontrado = usuario;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(sede: sede, usuario: usuarioEncontrado),
      ),
    );
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
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 14),
            decoration: _decoracion('Correo electrónico', LucideIcons.mail),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa tu correo';
              }
              if (!value.contains('@')) return 'Correo inválido';
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

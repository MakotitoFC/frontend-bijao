import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../data/mock_sedes.dart';
import '../data/usuarios_store.dart';
import '../models/mock_user.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_toast.dart';
import 'home_screen.dart';

// Login con datos mock (sin backend). Los campos son correo y contraseña;
// la sede se resuelve automáticamente del usuario autenticado
// (`usuario.sedeId`), no se elige en esta pantalla.
// Solo desktop: split-screen (panel a la izquierda, tarjeta flotante
// centrada a la derecha).
// TODO: al conectar el servidor local de la laptop, reemplazar
// _submit() por la llamada real de autenticación (usuarios/mockSedes).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;

  // Anula por completo el borde redondeado del tema global (que solo
  // sobreescribir `border` no basta: enabledBorder/focusedBorder del tema
  // tienen prioridad sobre él).
  static const _sinBorde = InputDecoration(
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    filled: false,
    isDense: true,
    contentPadding: EdgeInsets.zero,
  );

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(_onFocusChange);
    _passwordFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _emailFocus.removeListener(_onFocusChange);
    _passwordFocus.removeListener(_onFocusChange);
    _emailFocus.dispose();
    _passwordFocus.dispose();
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
        'Correo o contraseña incorrectos (usuarios de prueba)',
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
        mockSedes.where((s) => s.id == usuario!.sedeId).firstOrNull ??
        mockSedes.first;
    final usuarioEncontrado = usuario;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(sede: sede, usuario: usuarioEncontrado),
      ),
    );
  }

  Widget _fieldRow({required bool active, required Widget child}) {
    return SizedBox(
      height: 66,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: child,
      ),
    );
  }

  Widget _fieldLabel(String texto) => Text(
    texto,
    style: const TextStyle(
      color: AppColors.loginInputAccent,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _emailContent() {
    final activo = _emailFocus.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _fieldLabel('Correo electrónico'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _emailController,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(
            color: activo ? AppColors.loginInputAccent : Colors.black87,
          ),
          decoration: _sinBorde,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingresa tu correo';
            }
            if (!value.contains('@')) {
              return 'Correo inválido';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _passwordContent() {
    final activo = _passwordFocus.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _fieldLabel('Contraseña'),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: _obscurePassword,
                style: TextStyle(
                  color: activo ? AppColors.loginInputAccent : Colors.black87,
                ),
                decoration: _sinBorde,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa tu contraseña';
                  }
                  return null;
                },
              ),
            ),
            IconButton(
              style: IconButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: HugeIcon(
                icon: _obscurePassword
                    ? HugeIcons.strokeRoundedView
                    : HugeIcons.strokeRoundedViewOffSlash,
                color: Colors.grey.shade500,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ],
        ),
      ],
    );
  }

  Widget _campoContenedor({required bool active, required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        border: Border.all(
          color: active ? AppColors.loginInputAccent : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(AppRadii.input),
      ),
      clipBehavior: Clip.antiAlias,
      child: _fieldRow(active: active, child: child),
    );
  }

  Widget _credentialsGroup() {
    return Column(
      children: [
        _campoContenedor(active: _emailFocus.hasFocus, child: _emailContent()),
        const SizedBox(height: 16),
        _campoContenedor(
          active: _passwordFocus.hasFocus,
          child: _passwordContent(),
        ),
      ],
    );
  }

  Widget _card(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo_bijao.png', height: 52),
            const SizedBox(height: 28),
            Text(
              'Bienvenido',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ingresa tus credenciales para continuar',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 28),
            _credentialsGroup(),
            const SizedBox(height: 28),
            AppButton(
              label: 'Iniciar sesión',
              variant: AppButtonVariant.primary,
              backgroundColor: AppColors.loginButtonDark,
              hoverColor: AppColors.loginDarkPanel,
              radius: 28,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.loginPanelBg,
      body: _buildLayoutAncho(context),
    );
  }

  Widget _buildLayoutAncho(BuildContext context) {
    // Mobile: sin el panel de marca/features a la izquierda, solo el
    // "Bienvenido" y el formulario de credenciales, a pantalla completa.
    if (AppBreakpoints.esMobile(context)) {
      return SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 40,
              ),
              child: Center(child: _card(context)),
            ),
          ),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            color: AppColors.loginDarkPanel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: _FeaturePanel()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(56, 0, 56, 32),
                  child: _CopyrightText(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _card(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _CopyrightText extends StatelessWidget {
  final Color color;

  const _CopyrightText({required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      '© ${DateTime.now().year} Kumo Systems. Todos los derechos reservados',
      textAlign: TextAlign.left,
      style: TextStyle(color: color, fontSize: 12),
    );
  }
}

// Panel de marca/features: columna izquierda del split-screen.
class _FeaturePanel extends StatelessWidget {
  const _FeaturePanel();

  @override
  Widget build(BuildContext context) {
    const tituloStyle = TextStyle(
      color: Colors.white,
      fontSize: 38,
      fontWeight: FontWeight.w800,
      height: 1.1,
    );

    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Sistema POS', style: tituloStyle),
        Text(
          'Control total',
          style: tituloStyle.copyWith(
            color: AppColors.loginAccentGreen,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Control total de tu operación: desde la primera orden hasta la '
          'última mesa. Acceso seguro para equipos que nunca se detienen.',
          style: TextStyle(
            color: AppColors.loginMutedGreen,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        _feature(
          HugeIcons.strokeRoundedZap,
          'Rápido',
          'Toma órdenes en segundos',
        ),
        const SizedBox(height: 16),
        _feature(
          HugeIcons.strokeRoundedChartLineData02,
          'Claro',
          'Reportes en tiempo real',
        ),
        const SizedBox(height: 16),
        _feature(
          HugeIcons.strokeRoundedSecurityValidation,
          'Seguro',
          'Datos protegidos',
        ),
      ],
    );

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(56, 56, 56, 0),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: contenido),
          ),
        ),
      ),
    );
  }

  Widget _feature(
    List<List<dynamic>> icon,
    String titulo,
    String descripcion,
  ) => Row(
    children: [
      HugeIcon(icon: icon, color: AppColors.loginAccentGreen, size: 20),
      const SizedBox(width: 12),
      Expanded(
        child: Text.rich(
          TextSpan(
            style: const TextStyle(color: Colors.white, fontSize: 14),
            children: [
              TextSpan(
                text: '$titulo: ',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: descripcion,
                style: const TextStyle(fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

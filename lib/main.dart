import 'dart:ui';
import 'package:flutter/material.dart';

import 'data/descuentos_guardados_store.dart';

import 'data/configuracion_store.dart';
import 'models/usuario.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Captura global de errores de Flutter (renderizado, widgets, asíncronos)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    final user = AuthService.instance.currentUser?.nombre;
    ApiClient.registrarErrorRemoto(
      mensaje: details.exceptionAsString(),
      stack: details.stack?.toString(),
      nivel: 'FLUTTER_ERROR',
      usuario: user,
    );
  };

  // Captura de excepciones no controladas de la plataforma (ej. DeferredLoadException, Microtasks)
  PlatformDispatcher.instance.onError = (error, stack) {
    final user = AuthService.instance.currentUser?.nombre;
    ApiClient.registrarErrorRemoto(
      mensaje: error.toString(),
      stack: stack.toString(),
      nivel: 'UNCAUGHT_EXCEPTION',
      usuario: user,
    );
    return false; // Permite el flujo de reporte normal
  };

  await ApiClient.instance.initialize();
  await config.cargar();
  await cargarDescuentosGuardados();
  await AuthService.instance.restoreSession();
  runApp(const MyApp());
}

// En celular (APK y web angosta) las listas se deslizan con el dedo y no
// muestran barra de desplazamiento; en pantallas anchas se conserva.
class _DesplazamientoDeLaApp extends MaterialScrollBehavior {
  const _DesplazamientoDeLaApp();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (AppBreakpoints.esMobile(context)) return child;
    return super.buildScrollbar(context, child, details);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'El Bijao',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: const _DesplazamientoDeLaApp(),
      home: ValueListenableBuilder<Usuario?>(
        valueListenable: AuthService.instance.userNotifier,
        builder: (context, user, _) {
          if (user != null) {
            final sede =
                sedes.where((s) => s.id == user.sedeId).firstOrNull ??
                sedes.first;
            return HomeScreen(sede: sede, usuario: user);
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

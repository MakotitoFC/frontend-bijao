import 'package:flutter/material.dart';

import 'data/configuracion_store.dart';
import 'models/usuario.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.instance.initialize();
  await AuthService.instance.restoreSession();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bijao POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: ValueListenableBuilder<Usuario?>(
        valueListenable: AuthService.instance.userNotifier,
        builder: (context, user, _) {
          if (user != null) {
            final sede = sedes.where((s) => s.id == user.sedeId).firstOrNull ?? sedes.first;
            return HomeScreen(sede: sede, usuario: user);
          }
          return const LoginScreen();
        },
      ),
    );
  }
}


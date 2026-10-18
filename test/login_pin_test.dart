import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/main.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/screens/home_screen.dart';
import 'package:frontend_bijao/screens/login_screen.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/widgets/cambiar_pin_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    AuthService.instance.userNotifier.value = null;
  });

  tearDown(() => AuthService.instance.userNotifier.value = null);

  testWidgets(
    'al entrar con el PIN predeterminado el aviso sale una sola vez',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MyApp());
      await tester.pump();
      expect(find.byType(LoginScreen), findsOneWidget);

      // Inicio de sesión: solo cambia el usuario; MyApp cambia de pantalla.
      AuthService.instance.userNotifier.value = const Usuario(
        id: 'a',
        nombre: 'admin',
        email: 'a@a',
        rol: AppRole.administrador,
        debeCambiarPin: true,
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(CambiarPinDialog), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

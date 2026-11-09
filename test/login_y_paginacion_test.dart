import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/screens/login_screen.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/widgets/inventario/inventario_comun.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    AuthService.instance.userNotifier.value = null;
  });

  for (final tam in const [Size(375, 812), Size(768, 1024), Size(1400, 900)]) {
    testWidgets('Ingreso: sin Recordarme, contraseña olvidada ni ayuda; el '
        'servidor es solo un icono (${tam.width.round()} px)', (tester) async {
      tester.view.physicalSize = tam;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Recordarme'), findsNothing);
      expect(find.text('¿Olvidaste tu contraseña?'), findsNothing);
      expect(find.text('¿Tienes problemas para ingresar?'), findsNothing);
      expect(find.text('Contacta al administrador'), findsNothing);
      expect(find.text('INGRESAR'), findsOneWidget);
      // El botón de servidor / red: círculo con icono y su nombre en el tooltip.
      expect(find.text('Servidor / Red'), findsNothing);
      expect(find.byTooltip('Servidor / Red'), findsOneWidget);
      final boton = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(boton.shape, isA<CircleBorder>());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('las listas de inventario se paginan igual que ingresos y '
      'salidas', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SeccionInventario(
              titulo: 'Productos',
              filas: [
                for (var i = 1; i <= 25; i++)
                  SizedBox(height: 40, child: Text('Producto $i')),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Producto 1'), findsOneWidget);
    expect(find.text('Producto 8'), findsOneWidget);
    expect(find.text('Producto 9'), findsNothing);
    expect(find.text('Mostrando 1-8 de 25'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Página siguiente'));
    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pump();
    expect(find.text('Producto 9'), findsOneWidget);
    expect(find.text('Mostrando 9-16 de 25'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con pocas filas el paginador se muestra igual', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SeccionInventario(
              titulo: 'Productos',
              filas: [
                for (var i = 1; i <= 4; i++)
                  SizedBox(height: 40, child: Text('Producto $i')),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Mostrando 1-4 de 4'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
  });
}

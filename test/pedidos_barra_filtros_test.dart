import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/screens/pedidos_screen.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/widgets/app_search_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _admin = Usuario(
  id: 'a1',
  nombre: 'Admin',
  email: 'a@a',
  rol: AppRole.administrador,
  permisos: {'LEER.PEDIDOS', 'LEER.PEDIDO', 'LEER.PAGO', 'LEER.MESA'},
);

// En Pedidos, el buscador comparte la fila con "Medio de pago" y "Nuevo Pedido"
// en escritorio (aunque la ventana esté ampliada y el listado quede angosto) y
// pasa a su propia línea solo en tablet o celular.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    AuthService.instance.userNotifier.value = _admin;
    mediosPago
      ..clear()
      ..add(
        const MedioPago(
          id: 'mp1',
          medioPago: 'Efectivo',
          aplicaComision: false,
        ),
      );
    pedidos.clear();
  });

  tearDown(() {
    AuthService.instance.userNotifier.value = null;
    mediosPago.clear();
  });

  Future<void> abrir(WidgetTester tester, Size tam) async {
    tester.view.physicalSize = tam;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: PedidosScreen(usuario: _admin)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  double centroY(WidgetTester tester, Finder f) => tester.getCenter(f).dy;

  // Escritorio: todo en una fila, también cuando el listado queda por debajo de
  // 760 px de ancho (ventana ampliada).
  for (final ancho in const [1180.0, 1280.0, 1440.0, 1920.0]) {
    testWidgets(
      'escritorio ${ancho.round()} px: buscador y botones en una fila',
      (tester) async {
        await abrir(tester, Size(ancho, 900));
        final buscador = centroY(tester, find.byType(AppSearchField));
        final nuevo = centroY(tester, find.text('Nuevo Pedido'));
        final medio = centroY(tester, find.text('Medio de pago'));
        expect((buscador - nuevo).abs(), lessThan(6));
        expect((medio - nuevo).abs(), lessThan(6));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final ancho in const [768.0, 1024.0]) {
    testWidgets('tablet ${ancho.round()} px: el buscador va en su línea', (
      tester,
    ) async {
      await abrir(tester, Size(ancho, 900));
      final buscador = centroY(tester, find.byType(AppSearchField));
      final nuevo = centroY(tester, find.text('Nuevo Pedido'));
      expect(nuevo - buscador, greaterThan(20));
      expect(tester.takeException(), isNull);
    });
  }
}

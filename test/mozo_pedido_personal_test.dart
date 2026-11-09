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
import 'package:shared_preferences/shared_preferences.dart';

// El mozo también registra pedidos de empleados y de familia: al tocar "Nuevo"
// se le pregunta para quién es el pedido, igual que a caja y administración.
const _mozo = Usuario(
  id: 'm1',
  nombre: 'Mozo Uno',
  email: 'm@a',
  rol: AppRole.mesero,
  permisos: {'LEER.PEDIDOS', 'LEER.PEDIDO', 'LEER.MESA'},
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    AuthService.instance.userNotifier.value = _mozo;
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
    pedidos.clear();
    mediosPago.clear();
    AuthService.instance.userNotifier.value = null;
  });

  testWidgets('el mozo elige si el pedido es de cliente, familia o empleado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: PedidosScreen(usuario: _mozo)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Nuevo'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('¿Para quién es este pedido?'), findsOneWidget);
    expect(find.text('Cliente'), findsOneWidget);
    expect(find.text('Familia'), findsOneWidget);
    expect(find.text('Empleado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

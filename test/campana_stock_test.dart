import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/catalogos_store.dart';
import 'package:frontend_bijao/data/inventario_store.dart';
import 'package:frontend_bijao/data/mesas_por_liberar_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/producto_inventario.dart';
import 'package:frontend_bijao/models/unidad_producto.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/widgets/campana_notificaciones.dart';
import 'package:shared_preferences/shared_preferences.dart';

// La campana también avisa del stock de inventario que se está acabando.
Usuario _usuario({required bool veInventario}) => Usuario(
  id: 'a1',
  nombre: 'Admin',
  email: 'a@a',
  // El administrador entra a todo: sin permiso solo puede ser otro rol.
  rol: veInventario ? AppRole.administrador : AppRole.cajero,
  permisos: {if (veInventario) 'VER.VISTA_INVENTARIO'},
);

ProductoInventario _p(
  String id,
  String nombre,
  double stock,
  double minimo, {
  bool estado = true,
}) => ProductoInventario(
  id: id,
  nombre: nombre,
  tipoProductoId: 't1',
  seguimiento: 'unidad',
  unidadProductoId: 'u1',
  stockActual: stock,
  stockMinimo: minimo,
  estado: estado,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    limpiarMesasPorLiberar();
    unidadesProducto
      ..clear()
      ..add(const UnidadProducto(id: 'u1', unidad: 'Kg'));
    productosInventario.clear();
    stockBajoNotifier.value = [];
  });

  tearDown(() {
    AuthService.instance.userNotifier.value = null;
    productosInventario.clear();
    stockBajoNotifier.value = [];
    unidadesProducto.clear();
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Center(child: CampanaNotificaciones())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  test('solo cuenta los activos con mínimo y stock igual o menor a él', () {
    productosInventario.addAll([
      _p('1', 'Arroz', 2, 5), // bajo
      _p('2', 'Sal', 0, 3), // agotado
      _p('3', 'Aceite', 10, 5), // en orden
      _p('4', 'Vaso', 0, 0), // sin mínimo: no avisa
      _p('5', 'Mantel', 1, 4, estado: false), // inactivo
    ]);
    recalcularStockBajo();
    final nombres = stockBajoNotifier.value.map((p) => p.nombre).toList();
    // Los agotados van primero.
    expect(nombres, ['Sal', 'Arroz']);
  });

  testWidgets('con permiso de inventario: contador y tarjeta de stock bajo', (
    tester,
  ) async {
    AuthService.instance.userNotifier.value = _usuario(veInventario: true);
    productosInventario.add(_p('1', 'Arroz', 2, 5));
    recalcularStockBajo();
    await montar(tester);
    // El contador de la campana.
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byType(CampanaNotificaciones));
    await tester.pumpAndSettle();
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('1 producto con stock bajo'), findsOneWidget);
    expect(find.text('Arroz: stock bajo'), findsWidgets);
    expect(find.textContaining('Quedan 2 Kg (mínimo 5)'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un producto agotado se avisa como sin stock', (tester) async {
    AuthService.instance.userNotifier.value = _usuario(veInventario: true);
    productosInventario.add(_p('2', 'Sal', 0, 3));
    recalcularStockBajo();
    await montar(tester);
    expect(find.text('Sal: sin stock'), findsWidgets);
    expect(find.textContaining('Se agotó'), findsWidgets);
  });

  testWidgets('sin permiso de inventario no se avisa de stock', (tester) async {
    AuthService.instance.userNotifier.value = _usuario(veInventario: false);
    productosInventario.add(_p('1', 'Arroz', 2, 5));
    recalcularStockBajo();
    await montar(tester);
    expect(find.text('1'), findsNothing);
    expect(find.text('Arroz: stock bajo'), findsNothing);
  });
}

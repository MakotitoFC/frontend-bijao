import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:frontend_bijao/data/pagos_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/widgets/pago_dialogs.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Pagar un pedido de empleado: se elige si el pago va a caja (medios normales)
// o no (descuento de planilla). En los demás pedidos no se pregunta.
Pedido _pedido({required bool empleado}) => Pedido(
  id: 'p1',
  numeroPedido: '0009',
  mesaNumero: 0,
  tipoPedido: empleado ? 'empleado' : 'llevar',
  estado: 'servido',
  fechaPedido: DateTime(2026, 11, 10, 13),
  usuarioId: 'u1',
  esEmpleado: empleado,
);

const _linea = PedidoLine(
  id: 'l1',
  cartaId: 'c1',
  nombrePlato: 'Menú',
  cantidad: 1,
  modificadores: [],
  presentacion: null,
  promocion: null,
  comentario: null,
  precioUnitario: 10,
  descuentoAplicado: 0,
  precioTotalLinea: 10,
  tipoEntrega: 'mesa',
);

void main() {
  final previos = [...mediosPago];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    mediosPago
      ..clear()
      ..addAll(const [
        MedioPago(
          id: 'm1',
          medioPago: 'Efectivo',
          aplicaComision: false,
          grupo: 'efectivo',
        ),
        MedioPago(
          id: 'm2',
          medioPago: 'Yape',
          aplicaComision: false,
          grupo: 'digital',
        ),
        MedioPago(
          id: 'm3',
          medioPago: 'Descuento Planilla',
          aplicaComision: false,
          grupo: 'credito',
        ),
      ]);
    pagos.clear();
    detallesPorPedido['p1'] = [_linea];
  });

  tearDown(() {
    mediosPago
      ..clear()
      ..addAll(previos);
    pagos.clear();
    pedidos.clear();
    detallesPorPedido.clear();
  });

  Future<void> abrir(WidgetTester tester, Pedido p) async {
    tester.view.physicalSize = const Size(700, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    pedidos
      ..clear()
      ..add(p);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagarPedidoDialog(pedido: p, titulo: 'Empleado'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('empleado: por defecto va a caja y no ofrece planilla', (
    tester,
  ) async {
    await abrir(tester, _pedido(empleado: true));
    expect(find.text('¿El pago va a caja?'), findsOneWidget);
    expect(find.text('Efectivo'), findsWidgets);
    expect(find.text('Yape'), findsOneWidget);
    expect(find.text('Descuento Planilla'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('empleado: "No figura en caja" ofrece solo la planilla', (
    tester,
  ) async {
    await abrir(tester, _pedido(empleado: true));
    await tester.ensureVisible(find.text('No, no figura en caja'));
    await tester.tap(find.text('No, no figura en caja'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Descuento Planilla'), findsOneWidget);
    expect(find.text('Efectivo'), findsNothing);
    expect(find.text('Yape'), findsNothing);
    expect(find.textContaining('no entra dinero a la caja'), findsOneWidget);
    // Y se puede volver.
    await tester.ensureVisible(find.text('Sí, figura en caja'));
    await tester.tap(find.text('Sí, figura en caja'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Efectivo'), findsWidgets);
    expect(find.text('Descuento Planilla'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('otros pedidos: no se pregunta y se ven todos los medios', (
    tester,
  ) async {
    await abrir(tester, _pedido(empleado: false));
    expect(find.text('¿El pago va a caja?'), findsNothing);
    expect(find.text('Efectivo'), findsWidgets);
    expect(find.text('Descuento Planilla'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

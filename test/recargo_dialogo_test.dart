import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:frontend_bijao/data/pagos_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/widgets/pago_dialogs.dart';

final _pedido = Pedido(
  id: 'p1',
  numeroPedido: '0007',
  mesaNumero: 2,
  tipoPedido: 'mesa',
  estado: 'servido',
  fechaPedido: DateTime(2026, 10, 19, 14, 0),
  usuarioId: 'u1',
);

const _linea = PedidoLine(
  id: 'l1',
  cartaId: 'c1',
  nombrePlato: 'Ceviche',
  cantidad: 1,
  modificadores: [],
  presentacion: null,
  promocion: null,
  comentario: null,
  precioUnitario: 100,
  descuentoAplicado: 0,
  precioTotalLinea: 100,
  tipoEntrega: 'mesa',
);

void main() {
  final previos = [...mediosPago];

  setUp(() {
    mediosPago
      ..clear()
      ..addAll(const [
        MedioPago(id: 'm1', medioPago: 'Efectivo', aplicaComision: false),
        MedioPago(
          id: 'm2',
          medioPago: 'Tarjeta',
          aplicaComision: true,
          porcentajeComision: 4,
        ),
      ]);
    pagos.clear();
    pedidos
      ..clear()
      ..add(_pedido);
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

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(700, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagarPedidoDialog(pedido: _pedido, titulo: 'Mesa 2'),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('en efectivo no hay recargo y se paga la cuenta', (tester) async {
    await abrir(tester);
    expect(find.text('Pagar · S/ 100.00'), findsOneWidget);
    expect(find.textContaining('Recargo'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('al elegir tarjeta se ve el recargo del 4 % y el total', (
    tester,
  ) async {
    await abrir(tester);
    // La tarjeta avisa su recargo en la propia opción.
    expect(find.text('+4.0% recargo'), findsOneWidget);

    await tester.tap(find.text('Tarjeta'));
    await tester.pump();
    expect(find.text('Recargo tarjeta (4.0%)'), findsOneWidget);
    expect(find.text('+S/ 4.00'), findsOneWidget);
    expect(find.text('Total a cobrar'), findsOneWidget);
    expect(find.text('S/ 104.00'), findsOneWidget);
    expect(find.text('Pagar · S/ 104.00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pagar con tarjeta registra la cuenta y el recargo', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.text('Tarjeta'));
    await tester.pump();
    await tester.tap(find.text('Pagar · S/ 104.00'));
    await tester.pump();

    final pago = pagos.single;
    expect(pago.montoAbonado, 100);
    expect(pago.montoComision, 4);
    expect(pago.montoCobrado, 104);
    await tester.pumpWidget(const SizedBox());
  });
}

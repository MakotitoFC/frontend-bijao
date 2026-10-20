import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/widgets/detalle_pedido_panel.dart';

Pedido _pedido({String tipo = 'mesa'}) => Pedido(
  id: 'p1',
  numeroPedido: '1',
  mesaNumero: tipo == 'mesa' ? 2 : 0,
  tipoPedido: tipo,
  estado: 'pendiente',
  fechaPedido: DateTime(2026, 10, 18, 13),
  usuarioId: 'u1',
);

const _linea = PedidoLine(
  id: 'l1',
  cartaId: 'c1',
  nombrePlato: 'Tacacho',
  cantidad: 1,
  modificadores: [],
  presentacion: null,
  promocion: null,
  comentario: null,
  precioUnitario: 12,
  descuentoAplicado: 0,
  precioTotalLinea: 12,
);

void main() {
  tearDown(() {
    pedidos.clear();
    detallesPorPedido.clear();
  });

  Future<void> abrir(WidgetTester tester, Pedido p) async {
    tester.view.physicalSize = const Size(500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    pedidos
      ..clear()
      ..add(p);
    detallesPorPedido[p.id] = [_linea];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DetallePedidoPanel(pedido: p, onCambio: () {}, esAdmin: false),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'hay un solo botón Pagar y el detalle trae Promoción, Propina y Táper',
    (tester) async {
      await abrir(tester, _pedido());
      expect(find.text('Pagar'), findsOneWidget);
      expect(find.text('Pago compartido'), findsNothing);
      // Un cliente puede pedir solo un táper: también se agrega desde el detalle.
      expect(find.text('Táper'), findsOneWidget);
      expect(find.text('Promoción'), findsOneWidget);
      expect(find.text('Propina'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Táper en el detalle abre el diálogo de tápers', (tester) async {
    await abrir(tester, _pedido());
    await tester.tap(find.text('Táper'));
    await tester.pumpAndSettle();
    expect(find.text('Táper grande'), findsOneWidget);
    expect(find.text('Táper mediano'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Pagar deja elegir entre pago único y compartido', (
    tester,
  ) async {
    await abrir(tester, _pedido());
    await tester.tap(find.text('Pagar'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Pago único'), findsOneWidget);
    expect(find.text('Pago compartido'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Servido y Pagar van en la misma fila', (tester) async {
    await abrir(tester, _pedido());
    expect(find.text('Marcar como Servido'), findsNothing);
    expect(find.text('Servido'), findsOneWidget);
    final servido = tester.getCenter(find.text('Servido')).dy;
    final pagar = tester.getCenter(find.text('Pagar')).dy;
    expect((servido - pagar).abs(), lessThan(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('al servir, el botón Servido sigue visible pero desactivado', (
    tester,
  ) async {
    await abrir(tester, _pedido());
    // "Servido" también es el nombre del estado: se busca el del botón.
    final textoBoton = find.descendant(
      of: find.bySubtype<FilledButton>(),
      matching: find.text('Servido'),
    );
    FilledButton servido() => tester.widget<FilledButton>(
      find.ancestor(of: textoBoton, matching: find.bySubtype<FilledButton>()),
    );
    expect(servido().onPressed, isNotNull);

    // El pedido pasa a servido.
    final p = _pedido().copyWith(estado: 'servido');
    pedidos
      ..clear()
      ..add(p);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DetallePedidoPanel(pedido: p, onCambio: () {}, esAdmin: false),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(textoBoton, findsOneWidget); // no desaparece
    expect(servido().onPressed, isNull); // queda inhabilitado
    // Pagar sigue disponible.
    expect(find.text('Pagar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('desde cada forma de pago se puede regresar a la elección', (
    tester,
  ) async {
    await abrir(tester, _pedido());

    Future<void> esperar() async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    // Pago único → Regresar → vuelve a la elección.
    await tester.tap(find.text('Pagar'));
    await esperar();
    await tester.tap(find.text('Pago único'));
    await esperar();
    expect(find.text('Regresar'), findsOneWidget);
    expect(find.textContaining('Pagar · S/'), findsOneWidget);
    await tester.tap(find.text('Regresar'));
    await esperar();
    expect(find.text('Pago compartido'), findsOneWidget);

    // Pago compartido → Regresar → vuelve a la elección.
    await tester.tap(find.text('Pago compartido'));
    await esperar();
    expect(find.text('Regresar'), findsOneWidget);
    expect(find.textContaining('Cobrar · S/'), findsOneWidget);
    // El formulario es largo: se desplaza hasta el botón.
    await tester.ensureVisible(find.text('Regresar'));
    await tester.pump();
    await tester.tap(find.text('Regresar'));
    await esperar();
    expect(find.text('Pago único'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('en delivery Pagar va directo al pago (sin compartido)', (
    tester,
  ) async {
    await abrir(tester, _pedido(tipo: 'delivery'));
    await tester.tap(find.text('Pagar'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Pago único'), findsOneWidget); // es el título del pago
    expect(find.text('Pago compartido'), findsNothing);
    // En delivery no hay elección previa, así que tampoco "Regresar".
    expect(find.text('Regresar'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

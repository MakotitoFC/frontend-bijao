import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:frontend_bijao/data/pagos_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/widgets/pago_compartido_dialog.dart';

final _pedido = Pedido(
  id: 'p1',
  numeroPedido: '0007',
  mesaNumero: 2,
  tipoPedido: 'mesa',
  estado: 'servido',
  fechaPedido: DateTime(2026, 10, 21, 14, 0),
  usuarioId: 'u1',
);

PedidoLine _linea(String id, String plato, int cantidad, double unitario) =>
    PedidoLine(
      id: id,
      cartaId: 'c-$id',
      nombrePlato: plato,
      cantidad: cantidad,
      modificadores: const [],
      presentacion: null,
      promocion: null,
      comentario: null,
      precioUnitario: unitario,
      descuentoAplicado: 0,
      precioTotalLinea: unitario * cantidad,
      tipoEntrega: 'mesa',
    );

void main() {
  final previos = [...mediosPago];

  setUp(() {
    mediosPago
      ..clear()
      ..addAll(const [
        MedioPago(id: 'm1', medioPago: 'Efectivo', aplicaComision: false),
      ]);
    pagos.clear();
    pedidos
      ..clear()
      ..add(_pedido);
    // 2 suri a S/ 20 y 3 chancho a S/ 30.
    detallesPorPedido['p1'] = [
      _linea('l1', 'Suri', 2, 20),
      _linea('l2', 'Chancho', 3, 30),
    ];
  });

  tearDown(() {
    mediosPago
      ..clear()
      ..addAll(previos);
    pagos.clear();
    pedidos.clear();
    detallesPorPedido.remove('p1');
  });

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PagoCompartidoDialog(pedido: _pedido, titulo: 'Mesa 2'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('"Cada uno su plato" ofrece una fila por unidad pedida', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.text('Cada uno su plato'));
    await tester.pump();

    // 2 suri + 3 chancho = 5 filas asignables.
    expect(find.text('Suri'), findsNWidgets(2));
    expect(find.text('Chancho'), findsNWidgets(3));
    expect(find.text('Unidad 1 de 2 · S/ 20.00'), findsOneWidget);
    expect(find.text('Unidad 2 de 3 · S/ 30.00'), findsOneWidget);
  });

  testWidgets('ya no se ofrecen los modos "Por grupo" ni "Por categoría"', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.text('Por grupo'), findsNothing);
    expect(find.text('Por categoría'), findsNothing);
    expect(find.text('Partes iguales'), findsOneWidget);
    expect(find.text('Cada uno su plato'), findsOneWidget);
  });

  testWidgets('con todo en el primer pagador, paga el total de la cuenta', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.text('Cada uno su plato'));
    await tester.pump();
    // 2 x 20 + 3 x 30 = 130, todo asignado a la Persona 1 por defecto.
    expect(find.text('S/ 130.00'), findsWidgets);
  });
}

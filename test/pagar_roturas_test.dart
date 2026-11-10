import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:frontend_bijao/data/pagos_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/widgets/app_switch.dart';
import 'package:frontend_bijao/widgets/pago_dialogs.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Roturas / alquiler en Pagar: se elige quién las causó. Las de un cliente se
// suman a la cuenta; las de un mozo no la cambian (se guardan en Inventario al
// confirmar el cobro).
final _pedido = Pedido(
  id: 'p1',
  numeroPedido: '0007',
  mesaNumero: 2,
  tipoPedido: 'mesa',
  estado: 'servido',
  fechaPedido: DateTime(2026, 11, 9, 14, 0),
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    mediosPago
      ..clear()
      ..addAll(const [
        MedioPago(id: 'm1', medioPago: 'Efectivo', aplicaComision: false),
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
    tester.view.physicalSize = const Size(700, 1600);
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
    // La sección se activa con su interruptor.
    final fila = find
        .ancestor(
          of: find.text('Roturas / alquiler'),
          matching: find.byType(Row),
        )
        .first;
    await tester.tap(
      find.descendant(of: fila, matching: find.byType(AppSwitch)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('al activarla es del cliente y se suma a la cuenta', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.text('Roturas / alquiler'), findsOneWidget);
    expect(find.text('Cliente'), findsOneWidget);
    expect(find.text('Mozo'), findsOneWidget);
    expect(find.textContaining('Se suma a la cuenta'), findsOneWidget);
    expect(find.textContaining('Mozo del pedido'), findsNothing);
    expect(find.text('Pagar · S/ 100.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('con Mozo usa el mozo del pedido y no cambia la cuenta', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.text('Mozo'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Mozo del pedido'), findsOneWidget);
    // Es un checklist: al marcar Mozo se desmarca Cliente.
    final marcadas = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(marcadas.where((c) => c.value == true).length, 1);
    expect(find.textContaining('a cuenta de su sueldo'), findsOneWidget);
    expect(find.textContaining('Se suma a la cuenta'), findsNothing);
    // La cuenta del cliente no cambia.
    expect(find.text('Pagar · S/ 100.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

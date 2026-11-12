import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/widgets/detalle_pedido_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Cuenta de empleado en S/ 0.00: si el servidor no la cierra, se avisa con un
// mensaje y el pedido NO se esconde en silencio.
Pedido _pedido() => Pedido(
  id: '01925b6a-9b1d-7234-a123-abcdef012345',
  numeroPedido: '0010',
  mesaNumero: 0,
  tipoPedido: 'empleado',
  estado: 'servido',
  fechaPedido: DateTime(2026, 11, 11, 13),
  usuarioId: 'u1',
  esEmpleado: true,
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
  precioUnitario: 0,
  descuentoAplicado: 0,
  precioTotalLinea: 0,
  tipoEntrega: 'mesa',
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    mediosPago
      ..clear()
      ..add(
        const MedioPago(
          id: '01925b6a-9b1d-7234-a123-abcdef0123aa',
          medioPago: 'Efectivo',
          aplicaComision: false,
        ),
      );
    cuentasCeroCerradas.clear();
  });

  tearDown(() {
    mediosPago.clear();
    pedidos.clear();
    detallesPorPedido.clear();
    cuentasCeroCerradas.clear();
  });

  testWidgets('si el servidor no cierra la cuenta, avisa y no la esconde', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = _pedido();
    pedidos
      ..clear()
      ..add(p);
    detallesPorPedido[p.id] = [_linea];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DetallePedidoPanel(pedido: p, onCambio: () {}, esAdmin: true),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Pagar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Cuenta cero'), findsOneWidget);
    await tester.tap(find.text('No imprimir'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // Sin servidor, el cobro de 0 falla: se explica y no se esconde el pedido.
    expect(find.text('No se pudo cerrar la cuenta'), findsOneWidget);
    expect(find.text('Entendido'), findsOneWidget);
    expect(cuentasCeroCerradas.contains(p.id), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

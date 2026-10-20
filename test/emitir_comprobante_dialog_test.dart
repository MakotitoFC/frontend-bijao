import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/pagos_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/pago.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/widgets/app_switch.dart';
import 'package:frontend_bijao/widgets/emitir_comprobante_dialog.dart';

const _pedidoId = '01925b6a-9b1d-7234-a123-abcdef012345';

Pedido _pedido() => Pedido(
  id: _pedidoId,
  numeroPedido: '0007',
  mesaNumero: 0,
  tipoPedido: 'llevar',
  estado: 'pagado',
  fechaPedido: DateTime(2026, 10, 20, 14, 0),
  usuarioId: 'u1',
);

PedidoLine _linea(double total) => PedidoLine(
  id: 'l1',
  cartaId: 'c1',
  nombrePlato: 'Ceviche',
  cantidad: 1,
  modificadores: const [],
  presentacion: null,
  promocion: null,
  comentario: null,
  precioUnitario: total,
  descuentoAplicado: 0,
  precioTotalLinea: total,
);

Finder _emitir() => find.ancestor(
  of: find.text('Emitir comprobante'),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

void main() {
  tearDown(() {
    detallesPorPedido.remove(_pedidoId);
    pagos.clear();
  });

  Future<void> abrir(
    WidgetTester tester,
    double total, {
    bool conCobro = true,
  }) async {
    detallesPorPedido[_pedidoId] = [_linea(total)];
    pagos.clear();
    if (conCobro) {
      pagos.add(
        Pago(
          id: 'pg1',
          pedidoId: _pedidoId,
          mesaNumero: 0,
          medioPago: const MedioPago(
            id: 'mp1',
            medioPago: 'Efectivo',
            aplicaComision: false,
          ),
          montoAbonado: total,
          montoComision: 0,
          montoCobrado: total,
          propina: 0,
          fechaPago: DateTime(2026, 10, 20, 14, 5),
        ),
      );
    }
    tester.view.physicalSize = const Size(700, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EmitirComprobanteDialog(pedido: _pedido())),
      ),
    );
    await tester.pump();
  }

  bool puede(WidgetTester tester) =>
      tester.widget<ButtonStyleButton>(_emitir()).onPressed != null;

  testWidgets('arranca en Ticket de venta y deja emitir sin datos', (
    tester,
  ) async {
    await abrir(tester, 52);
    expect(find.text('Ticket de venta'), findsOneWidget);
    expect(find.text('Boleta'), findsOneWidget);
    expect(find.text('Factura'), findsOneWidget);
    expect(puede(tester), isTrue);
  });

  testWidgets('boleta sin DNI va a CLIENTES VARIOS; con DNI pide datos', (
    tester,
  ) async {
    await abrir(tester, 52);
    await tester.tap(find.text('Boleta'));
    await tester.pump();
    expect(find.textContaining('CLIENTES VARIOS'), findsOneWidget);
    expect(puede(tester), isTrue);

    // Activa "con DNI" (el primer interruptor de la boleta).
    await tester.tap(find.byType(AppSwitch).first);
    await tester.pump();
    expect(puede(tester), isFalse); // falta DNI y nombre
    await tester.enterText(find.byType(EditableText).at(0), '72458912');
    await tester.enterText(find.byType(EditableText).at(1), 'Juan Perez');
    await tester.pump();
    expect(puede(tester), isTrue);
    await tester.enterText(find.byType(EditableText).at(0), '7245');
    await tester.pump();
    expect(puede(tester), isFalse); // el DNI tiene 8 digitos
  });

  testWidgets('desde S/ 700 la boleta exige el DNI del cliente', (
    tester,
  ) async {
    await abrir(tester, 850);
    await tester.tap(find.text('Boleta'));
    await tester.pump();
    expect(find.textContaining('SUNAT exige el DNI'), findsOneWidget);
    expect(puede(tester), isFalse);
  });

  testWidgets('factura pide RUC de 11 digitos y razon social', (tester) async {
    await abrir(tester, 52);
    await tester.tap(find.text('Factura'));
    await tester.pump();
    expect(puede(tester), isFalse);
    await tester.enterText(find.byType(EditableText).at(0), '20100070970');
    await tester.pump();
    expect(puede(tester), isFalse); // falta la razon social
    await tester.enterText(
      find.byType(EditableText).at(1),
      'SUPERMERCADOS S.A.',
    );
    await tester.pump();
    expect(puede(tester), isTrue);
    expect(find.byTooltip('Buscar en SUNAT'), findsOneWidget);
  });

  testWidgets('boleta y factura exigen un cobro; el ticket interno no', (
    tester,
  ) async {
    await abrir(tester, 52, conCobro: false);
    expect(puede(tester), isTrue); // ticket de venta
    await tester.tap(find.text('Boleta'));
    await tester.pump();
    expect(find.textContaining('debe tener un cobro'), findsOneWidget);
    expect(puede(tester), isFalse);
    await tester.tap(find.text('Factura'));
    await tester.pump();
    expect(puede(tester), isFalse);
    await tester.tap(find.text('Ticket de venta'));
    await tester.pump();
    expect(puede(tester), isTrue);
  });
}

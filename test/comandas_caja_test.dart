import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/pagos_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/screens/cocina_screen.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _pedido = Pedido(
  id: 'p1',
  numeroPedido: 'A7',
  mesaNumero: 0,
  tipoPedido: 'llevar',
  estado: 'servido',
  fechaPedido: DateTime.now().subtract(const Duration(minutes: 5)),
  usuarioId: 'u1',
  clienteNombre: 'Ana',
);

const _plato = PedidoLine(
  id: 'l1',
  cartaId: 'c1',
  nombrePlato: 'Arroz con pollo',
  cantidad: 2,
  modificadores: [],
  presentacion: null,
  promocion: null,
  comentario: 'sin ají',
  precioUnitario: 15,
  descuentoAplicado: 0,
  precioTotalLinea: 30,
  tipoEntrega: 'llevar',
  aplicaTaper: true,
  cantidadTaper: 3,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    pedidos
      ..clear()
      ..add(_pedido);
    detallesPorPedido['p1'] = [_plato];
    pagos.clear();
  });

  tearDown(() {
    pedidos.clear();
    detallesPorPedido.remove('p1');
    pagos.clear();
  });

  Future<void> abrir(WidgetTester tester, {required bool modoCaja}) async {
    tester.view.physicalSize = const Size(1100, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CocinaScreen(modoCaja: modoCaja)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('el cajero ve el detalle, el total, Pagar e Imprimir', (
    tester,
  ) async {
    await abrir(tester, modoCaja: true);
    expect(find.text('#A7'), findsOneWidget);
    expect(find.text('Arroz con pollo'), findsOneWidget);
    // Nota, táper (con su cantidad) y precio de la línea.
    expect(find.textContaining('sin ají'), findsOneWidget);
    expect(find.text('Táper: sí (3)'), findsOneWidget);
    expect(find.text('S/ 30.00'), findsWidgets);
    expect(find.text('TOTAL'), findsOneWidget);
    // Pagar (el comprobante se elige dentro del pago) e Imprimir; sin casillas.
    expect(find.text('Pagar'), findsOneWidget);
    expect(find.byTooltip('Emitir comprobante'), findsNothing);
    expect(find.byTooltip('Imprimir'), findsOneWidget);
    expect(find.byTooltip('Enviar la cuenta por WhatsApp'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('la cocina no muestra precios ni botones de cobro', (
    tester,
  ) async {
    await abrir(tester, modoCaja: false);
    expect(find.text('Arroz con pollo'), findsOneWidget);
    expect(find.text('Pagar'), findsNothing);
    expect(find.text('TOTAL'), findsNothing);
    expect(find.text('Táper: sí (3)'), findsNothing);
  });
}

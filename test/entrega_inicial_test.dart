import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/utils/blur_dialog.dart';
import 'package:frontend_bijao/widgets/producto_opciones_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _plato = CartaItem(
  id: 'c1',
  nombrePlato: 'Chicharón de pollo',
  descripcion: 'Pollo frito',
  categoriaId: 'k',
  precioCliente: 22,
  stock: 10,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
  });

  // Abre el modal del producto con el tipo de pedido indicado, agrega y
  // devuelve la entrega con la que quedó el producto.
  Future<String?> entregaAlAgregar(
    WidgetTester tester,
    String tipoPedido, {
    String? cambiarA,
  }) async {
    ProductoConfigurado? resultado;
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                resultado = await showBlurDialog<ProductoConfigurado>(
                  context: context,
                  builder: (_) => ProductoOpcionesDialog(
                    item: _plato,
                    esAdmin: false,
                    tipoEntregaInicial: tipoPedido,
                  ),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    if (cambiarA != null) {
      await tester.tap(find.text(cambiarA));
      await tester.pump();
    }
    await tester.tap(find.textContaining('Agregar S/'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final r = resultado?.tipoEntrega;
    await tester.pumpWidget(const SizedBox());
    return r;
  }

  testWidgets('en un pedido de mesa el producto arranca "En mesa"', (
    tester,
  ) async {
    expect(await entregaAlAgregar(tester, 'mesa'), 'mesa');
  });

  testWidgets('en un pedido para llevar el producto arranca "Para llevar"', (
    tester,
  ) async {
    expect(await entregaAlAgregar(tester, 'llevar'), 'llevar');
  });

  testWidgets('en un pedido de delivery el producto arranca "Delivery"', (
    tester,
  ) async {
    expect(await entregaAlAgregar(tester, 'delivery'), 'delivery');
  });

  testWidgets('se puede cambiar la entrega de un producto', (tester) async {
    expect(
      await entregaAlAgregar(tester, 'llevar', cambiarA: 'En mesa'),
      'mesa',
    );
  });
}

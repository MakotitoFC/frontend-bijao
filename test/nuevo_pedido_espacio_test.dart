import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/borrador_pedido_store.dart';
import 'package:frontend_bijao/data/cartas_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/widgets/nuevo_pedido_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

CartaItem _plato(String id, String nombre, double precio) => CartaItem(
  id: id,
  nombrePlato: nombre,
  descripcion: '',
  categoriaId: 'k',
  precioCliente: precio,
  stock: 10,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    limpiarBorradorPedido();
    cartasNotifier.value = [
      _plato('c1', 'Tacacho', 12),
      _plato('c2', 'Ceviche', 25),
      _plato('c3', 'Chicharon', 22),
    ];
  });

  tearDown(() {
    cartasNotifier.value = [];
    limpiarBorradorPedido();
  });

  Future<void> esperar(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> abrir(WidgetTester tester, Size tam) async {
    tester.view.physicalSize = tam;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NuevoPedidoDialog(
            usuario: const Usuario(
              id: 'u1',
              nombre: 'ana',
              email: 'a@a',
              rol: AppRole.mesero,
            ),
            tipo: 'llevar',
            onTerminar: (_) {},
            onVolver: () {},
          ),
        ),
      ),
    );
    await esperar(tester);
  }

  // Agrega el producto de la tarjeta número [i] de la galería.
  Future<void> agregar(WidgetTester tester, int i) async {
    // En celular la tarjeta es horizontal y el botón dice solo "Agregar".
    final botones = find.text(
      tester.view.physicalSize.width < 600 ? 'Agregar' : 'Agregar al pedido',
    );
    await tester.ensureVisible(botones.at(i));
    await tester.pump();
    await tester.tap(botones.at(i), warnIfMissed: false);
    await esperar(tester);
    await tester.tap(find.textContaining('Agregar S/'));
    await esperar(tester);
  }

  testWidgets('celular: con varios productos la hoja deja la mitad de la '
      'pantalla a la galería', (tester) async {
    await abrir(tester, const Size(375, 812));
    for (var i = 0; i < 3; i++) {
      await agregar(tester, i);
    }
    expect(find.textContaining('Pedido · 3 productos'), findsOneWidget);

    // La lista del pedido empieza oculta: la hoja es solo la cabecera.
    final arribaOculta = tester
        .getTopLeft(find.textContaining('Pedido · 3 productos'))
        .dy;
    expect(arribaOculta, greaterThan(812 * 0.7));

    // Se puede mostrar; aun así la hoja deja la mitad de arriba a la galería.
    await tester.tap(find.byTooltip('Mostrar productos'));
    await esperar(tester);
    final arribaVisible = tester
        .getTopLeft(find.textContaining('Pedido · 3 productos'))
        .dy;
    expect(arribaVisible, lessThan(arribaOculta));
    expect(arribaVisible, greaterThan(812 * 0.5));
    await tester.tap(find.byTooltip('Ocultar productos'));
    await esperar(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pantalla baja: los productos del pedido tienen lugar sobre el '
      'pie fijo', (tester) async {
    await abrir(tester, const Size(1400, 640));
    for (var i = 0; i < 3; i++) {
      await agregar(tester, i);
    }
    // Las acciones ya no están en el pie fijo: van dentro del scroll.
    expect(find.text('Agregar al pedido'), findsWidgets);
    expect(find.text('Promoción'), findsOneWidget);

    // El pie fijo es solo totales y "Confirmar pedido".
    final confirmar = tester.getTopLeft(find.text('Confirmar pedido')).dy;
    final total = tester.getTopLeft(find.text('Total')).dy;
    expect(total, lessThan(confirmar));
    // Primer producto del pedido: se ve y queda por encima de los totales.
    final fila = tester.getTopLeft(find.text('Tacacho').last).dy;
    expect(fila, lessThan(total));
    // El pie fijo ocupa poco (totales + botón): el resto es para el pedido.
    expect(total, lessThan(640 * 0.8));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

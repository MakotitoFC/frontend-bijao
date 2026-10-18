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

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    limpiarBorradorPedido();
    cartasNotifier.value = [
      const CartaItem(
        id: 'c1',
        nombrePlato: 'Tacacho',
        descripcion: '',
        categoriaId: 'k',
        precioCliente: 12,
        stock: 10,
      ),
    ];
  });

  tearDown(() {
    cartasNotifier.value = [];
    limpiarBorradorPedido();
  });

  Widget app(Size tam) => MaterialApp(
    home: Scaffold(
      body: NuevoPedidoDialog(
        usuario: Usuario(
          id: 'u1',
          nombre: 'ana',
          email: 'a@a',
          rol: AppRole.administrador,
          permisos: const {},
        ),
        tipo: 'llevar',
        onTerminar: (_) {},
        onVolver: () {},
      ),
    ),
  );

  testWidgets('en pantalla angosta el detalle va en una hoja que se expande', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const Size(600, 900)));
    await tester.pump(const Duration(milliseconds: 300));

    // La hoja se ve de entrada, sin tener que bajar.
    expect(find.text('Aún no agregas productos'), findsOneWidget);
    expect(find.text('Confirmar pedido'), findsOneWidget);

    await tester.tap(find.text('Agregar al pedido').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar S/ 12.00'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Pedido · 1 producto'), findsOneWidget);

    // Se expande con el ícono y vuelve con "Seguir agregando".
    await tester.tap(find.byTooltip('Ver detalle completo'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Detalle del pedido'), findsOneWidget);
    expect(find.text('Nota del pedido (opcional)'), findsOneWidget);
    await tester.tap(find.text('Seguir agregando'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Detalle del pedido'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('en pantalla ancha el detalle va al lado', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const Size(1400, 900)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Ver detalle completo'), findsNothing);
    expect(find.text('Nota del pedido (opcional)'), findsOneWidget);
    expect(find.text('Plato rápido'), findsOneWidget); // solo el del detalle
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

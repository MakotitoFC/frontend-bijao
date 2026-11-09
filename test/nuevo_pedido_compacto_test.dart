import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/borrador_pedido_store.dart';
import 'package:frontend_bijao/data/cartas_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
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

  // Con el tema real de la app: limita el alto de todos los botones a 36 px y
  // así saca a la luz los botones que piden más alto sin subir el máximo.
  Widget app(Size tam) => MaterialApp(
    theme: AppTheme.light,
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
    // La barra no confirma: solo deja revisar (apagado mientras no hay nada).
    expect(find.text('Revisar'), findsOneWidget);
    expect(find.text('Confirmar pedido'), findsNothing);

    await tester.tap(find.text('Agregar').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar S/ 12.00'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1 producto'), findsOneWidget);

    // "Revisar" abre la revisión (ahí se confirma) y se vuelve con
    // "Seguir agregando".
    await tester.tap(find.text('Revisar'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Revisa el pedido'), findsOneWidget);
    expect(find.text('Aún no se envía a cocina'), findsOneWidget);
    expect(find.text('Confirmar pedido'), findsOneWidget);
    expect(find.text('Nota'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Agregar'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Revisa el pedido'), findsNothing);
    expect(find.text('Confirmar pedido'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('en pantalla ancha el detalle va al lado', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const Size(1400, 900)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Revisar'), findsNothing);
    expect(find.text('Nota'), findsOneWidget);
    expect(find.text('Plato rápido'), findsOneWidget); // junto al buscador
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

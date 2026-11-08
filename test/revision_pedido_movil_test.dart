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

// La barra del pedido y la revisión en celular, con el tema real de la app (que
// limita el alto de los botones) y en varios tamaños de pantalla y de letra:
// no debe haber errores de layout, y el total y los botones deben verse.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    limpiarBorradorPedido();
    cartasNotifier.value = [for (var i = 0; i < 4; i++) PlatoDePrueba.plato(i)];
  });

  tearDown(() {
    cartasNotifier.value = [];
    limpiarBorradorPedido();
  });

  const tamanos = {
    'celular chico': Size(320, 568),
    'celular': Size(375, 667),
    'celular alto': Size(375, 812),
    'tablet vertical': Size(600, 900),
  };

  for (final e in tamanos.entries) {
    for (final letra in [1.0, 1.4]) {
      testWidgets(
        'revisión en ${e.key} con letra al ${(letra * 100).round()} %',
        (tester) async {
          tester.view.physicalSize = e.value;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(letra)),
                child: child!,
              ),
              home: Scaffold(
                body: NuevoPedidoDialog(
                  usuario: const Usuario(
                    id: 'u1',
                    nombre: 'ana',
                    email: 'a@a',
                    rol: AppRole.administrador,
                    permisos: {},
                  ),
                  tipo: 'llevar',
                  onTerminar: (_) {},
                  onVolver: () {},
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));

          // Sin productos: la barra deja el botón apagado y no confirma.
          expect(find.text('Revisar'), findsOneWidget);
          expect(find.text('Confirmar pedido'), findsNothing);

          for (var i = 0; i < 3; i++) {
            await tester.tap(find.text('Agregar').first);
            for (var k = 0; k < 3; k++) {
              await tester.pump(const Duration(milliseconds: 500));
            }
            await tester.tap(
              find.widgetWithText(FilledButton, 'Agregar S/ 12.00'),
            );
            await tester.pump(const Duration(milliseconds: 100));
            await tester.pump(const Duration(milliseconds: 500));
          }
          expect(tester.takeException(), isNull);
          expect(find.text('3 productos'), findsOneWidget);

          await tester.tap(find.text('Revisar'));
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);

          // Abajo, siempre a la vista: el total y los dos botones.
          final alto = e.value.height;
          for (final f in [
            find.text('Confirmar pedido'),
            find.widgetWithText(OutlinedButton, 'Agregar'),
          ]) {
            final rect = tester.getRect(f);
            expect(rect.bottom, lessThanOrEqualTo(alto));
          }
          expect(find.textContaining('Total · 3 productos'), findsOneWidget);
          expect(find.text('Aún no se envía a cocina'), findsOneWidget);

          // Volver a seguir agregando deja otra vez la barra.
          await tester.tap(find.widgetWithText(OutlinedButton, 'Agregar'));
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Revisar'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}

class PlatoDePrueba {
  static CartaItem plato(int i) => CartaItem(
    id: 'c$i',
    nombrePlato: 'Plato $i',
    descripcion: '',
    categoriaId: 'k',
    precioCliente: 12,
    stock: 10,
  );
}

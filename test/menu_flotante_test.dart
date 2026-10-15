import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/widgets/detalle_pedido_panel.dart';

void main() {
  testWidgets(
    'el estado del pedido se elige en un menú flotante, no sobre la píldora',
    (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final elegidos = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: BadgeEstadoPedido(
                  'pendiente',
                  onCambiarEstado: elegidos.add,
                ),
              ),
            ),
          ),
        ),
      );

      final pastilla = tester.getRect(find.text('Pendiente'));
      await tester.tap(find.text('Pendiente'));
      await tester.pumpAndSettle();

      // Las tres opciones, debajo de la píldora y dentro de la pantalla.
      final servido = tester.getRect(find.text('Servido'));
      final anular = tester.getRect(find.text('Anular pedido'));
      expect(servido.top, greaterThan(pastilla.bottom));
      expect(anular.bottom, lessThanOrEqualTo(700));
      expect(anular.right, lessThanOrEqualTo(900));

      await tester.tap(find.text('Servido'));
      await tester.pumpAndSettle();
      expect(elegidos, ['servido']);
      expect(find.text('Anular pedido'), findsNothing); // se cerró
    },
  );

  testWidgets('sin acción, el estado es solo una píldora', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BadgeEstadoPedido('servido'))),
    );
    expect(find.text('Servido'), findsOneWidget);
    await tester.tap(find.text('Servido'));
    await tester.pumpAndSettle();
    expect(find.text('Anular pedido'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/widgets/detalle_pedido_panel.dart';
import 'package:frontend_bijao/widgets/menu_flotante.dart';

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

  // El panel mide al menos 190 px: con un disparador angosto pegado a un borde
  // se saldría de la pantalla, así que se corre solo para quedar dentro.
  for (final e in {
    'pegado a la izquierda': Alignment.centerLeft,
    'en el centro': Alignment.center,
    'pegado a la derecha': Alignment.centerRight,
  }.entries) {
    testWidgets('el menú se reubica solo para no salirse (${e.key})', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: e.value,
              child: SizedBox(
                width: 100,
                child: MenuFlotante<String>(
                  opciones: const [
                    OpcionMenu(valor: 'a', etiqueta: 'Clientes (5)'),
                    OpcionMenu(valor: 'b', etiqueta: 'Empleados (0)'),
                  ],
                  onSeleccionar: (_) {},
                  disparador: (context, abierto) => Container(
                    height: 40,
                    color: Colors.grey,
                    alignment: Alignment.center,
                    child: const Text('abrir'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      final opcion = tester.getRect(find.text('Empleados (0)'));
      expect(opcion.left, greaterThanOrEqualTo(8));
      expect(opcion.right, lessThanOrEqualTo(320 - 8));
      expect(tester.takeException(), isNull);
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/widgets/app_select.dart';

void main() {
  testWidgets('el campo del select se escribe y filtra las opciones', (
    tester,
  ) async {
    String? elegido;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: StatefulBuilder(
                builder: (context, setState) => AppSelect<String>(
                  label: 'Categoría',
                  buscable: true,
                  value: elegido,
                  hint: 'Elige para qué fue',
                  items: const [
                    AppSelectItem(value: 'a', label: 'Compra de insumos'),
                    AppSelectItem(value: 'b', label: 'Pago de servicios'),
                    AppSelectItem(value: 'c', label: 'Propinas'),
                  ],
                  onChanged: (v) => setState(() => elegido = v),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Elige para qué fue'));
    await tester.pumpAndSettle();
    // El propio campo es la caja de texto: una sola, sin buscador aparte.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Compra de insumos'), findsOneWidget);
    expect(find.text('Propinas'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'prop');
    await tester.pumpAndSettle();
    expect(find.text('Propinas'), findsOneWidget);
    expect(find.text('Compra de insumos'), findsNothing);

    await tester.tap(find.text('Propinas'));
    await tester.pumpAndSettle();
    expect(elegido, 'c');
  });
}

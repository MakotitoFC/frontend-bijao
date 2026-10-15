import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/widgets/campo_texto.dart';

void main() {
  testWidgets('la etiqueta va encima del campo y el placeholder es pequeño', (
    tester,
  ) async {
    final c = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: CampoTexto(
              controller: c,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Nombre de usuario',
              ),
            ),
          ),
        ),
      ),
    );

    final etiqueta = tester.getRect(find.text('Nombre'));
    final campo = tester.getRect(find.byType(TextField));
    expect(etiqueta.bottom, lessThanOrEqualTo(campo.top)); // encima, no flotando
    expect(find.text('Nombre'), findsOneWidget);

    final decoracion = tester.widget<TextField>(find.byType(TextField)).decoration!;
    expect(decoracion.hintStyle?.fontSize, CampoTexto.tamanoPlaceholder);
    expect(decoracion.labelText, isNull);

    await tester.enterText(find.byType(TextField), 'mozo2');
    expect(c.text, 'mozo2');
  });
}

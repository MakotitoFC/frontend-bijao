import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/widgets/app_select.dart';

void main() {
  const platos = [
    AppSelectItem(value: 'a', label: 'Ceviche de pescado'),
    AppSelectItem(value: 'b', label: 'Arroz con mariscos'),
    AppSelectItem(value: 'c', label: 'Café pasado'),
    AppSelectItem(value: 'd', label: 'Chicharrón de pescado'),
  ];

  Future<void> abrir(
    WidgetTester tester,
    ValueChanged<String?> alElegir,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: AppSelect<String>(
                label: 'Plato *',
                value: null,
                items: platos,
                buscable: true,
                onChanged: alElegir,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Selecciona una opción'));
    await tester.pumpAndSettle();
  }

  testWidgets('al escribir se filtran las opciones, sin importar tildes', (
    tester,
  ) async {
    await abrir(tester, (_) {});
    expect(find.text('Arroz con mariscos'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'pescado');
    await tester.pump();
    expect(find.text('Ceviche de pescado'), findsOneWidget);
    expect(find.text('Chicharrón de pescado'), findsOneWidget);
    expect(find.text('Arroz con mariscos'), findsNothing);

    await tester.enterText(find.byType(TextField), 'cafe');
    await tester.pump();
    expect(find.text('Café pasado'), findsOneWidget);
    expect(find.text('Ceviche de pescado'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('Sin resultados'), findsOneWidget);
  });

  testWidgets('tocar una coincidencia la elige y Enter elige la primera', (
    tester,
  ) async {
    String? elegido;
    await abrir(tester, (v) => elegido = v);
    await tester.enterText(find.byType(TextField), 'arroz');
    await tester.pump();
    await tester.tap(find.text('Arroz con mariscos'));
    await tester.pumpAndSettle();
    expect(elegido, 'b');

    // Enter con el panel abierto elige la primera coincidencia.
    await tester.tap(find.text('Selecciona una opción'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'chicha');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(elegido, 'd');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/widgets/selector_fecha.dart';

Future<void> _elegir(WidgetTester tester, String hint, String opcion) async {
  await tester.tap(find.text(hint));
  await tester.pumpAndSettle();
  await tester.tap(find.text(opcion).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('elige día, mes y año y avisa solo con la fecha completa', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final avisos = <DateTime?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: SelectorFecha(
              etiqueta: 'Desde',
              valor: null,
              permiteVacio: true,
              anioMin: 2026,
              anioMax: 2030,
              onChanged: avisos.add,
            ),
          ),
        ),
      ),
    );

    await _elegir(tester, 'Día', '5');
    expect(avisos, isEmpty); // faltan mes y año
    await _elegir(tester, 'Mes', 'Marzo');
    expect(avisos, isEmpty);
    await _elegir(tester, 'Año', '2027');
    expect(avisos.last, DateTime(2027, 3, 5));

    // Quitar la fecha.
    await tester.tap(find.byTooltip('Quitar fecha'));
    await tester.pumpAndSettle();
    expect(avisos.last, isNull);
    expect(find.text('Día'), findsOneWidget);
  });

  testWidgets('el día se ajusta si el mes elegido tiene menos días', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    DateTime? ultima;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: SelectorFecha(
              etiqueta: 'Fecha',
              valor: DateTime(2027, 1, 31),
              anioMin: 2026,
              anioMax: 2030,
              onChanged: (d) => ultima = d,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Enero'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Febrero').last);
    await tester.pumpAndSettle();
    expect(ultima, DateTime(2027, 2, 28));
  });
}

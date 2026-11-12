import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/widgets/selector_dia.dart';

void main() {
  testWidgets('las flechas cambian de día y no pasan de hoy', (tester) async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    var dia = hoy;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SelectorDia(
              dia: dia,
              onChanged: (d) => setState(() => dia = d),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Hoy'), findsOneWidget);
    // Hoy no tiene "siguiente".
    await tester.tap(find.byTooltip('Día siguiente'));
    await tester.pump();
    expect(dia, hoy);
    await tester.tap(find.byTooltip('Día anterior'));
    await tester.pump();
    expect(dia, hoy.subtract(const Duration(days: 1)));
    expect(find.text('Ayer'), findsOneWidget);
    await tester.tap(find.byTooltip('Día siguiente'));
    await tester.pump();
    expect(dia, hoy);
  });

  testWidgets('el calendario es el de la app y un toque elige el día', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final hoy = DateUtils.dateOnly(DateTime.now());
    var dia = hoy;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => SelectorDia(
                dia: dia,
                onChanged: (d) => setState(() => dia = d),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Hoy'));
    await tester.pumpAndSettle();
    // Nada del calendario estándar de Flutter.
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.text('Aplicar'), findsNothing);
    // Se toca el día 1 del mes (si hoy no es 1) y queda elegido.
    if (hoy.day != 1) {
      await tester.tap(find.text('1').last);
      await tester.pumpAndSettle();
      expect(dia, DateTime(hoy.year, hoy.month, 1));
    }
  });
}

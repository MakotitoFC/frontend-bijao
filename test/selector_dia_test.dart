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
}

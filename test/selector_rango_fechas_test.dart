import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/widgets/selector_rango_fechas.dart';

void main() {
  DateTime hoy() => DateUtils.dateOnly(DateTime.now());

  Future<List<DateTimeRange?>> abrir(
    WidgetTester tester, {
    DateTimeRange? valor,
  }) async {
    final cambios = <DateTimeRange?>[];
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectorRangoFechas(
                valor: valor,
                permiteTodas: true,
                onChanged: cambios.add,
              ),
            ),
          ),
        ),
      ),
    );
    return cambios;
  }

  test('la etiqueta resume el rango', () {
    final h = hoy();
    expect(etiquetaRangoFechas(null), 'Todas las fechas');
    expect(etiquetaRangoFechas(DateTimeRange(start: h, end: h)), 'Hoy');
    expect(
      etiquetaRangoFechas(
        DateTimeRange(
          start: h.subtract(const Duration(days: 1)),
          end: h.subtract(const Duration(days: 1)),
        ),
      ),
      'Ayer',
    );
    expect(
      etiquetaRangoFechas(
        DateTimeRange(start: DateTime(2026, 10, 3), end: DateTime(2026, 10, 9)),
      ),
      '3 oct – 9 oct 2026',
    );
  });

  testWidgets('la tarjeta es solo el calendario y "Hoy" es un botón aparte', (
    tester,
  ) async {
    final cambios = await abrir(tester);
    expect(find.text('Todas las fechas'), findsOneWidget);

    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pump();
    // Es una tarjeta flotante: no hay diálogo ni accesos rápidos dentro.
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Aplicar'), findsOneWidget);
    expect(find.text('Últimos 7 días'), findsNothing);
    expect(find.text('Ayer'), findsNothing);

    // Se cierra tocando fuera; "Hoy" está al lado del selector y aplica el día
    // de hoy.
    await tester.tapAt(const Offset(40, 700));
    await tester.pump();
    expect(find.text('Aplicar'), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Hoy'));
    await tester.pump();
    expect(cambios, hasLength(1));
    expect(cambios.single!.start, hoy());
    expect(cambios.single!.end, hoy());
  });

  testWidgets('en el calendario se marca inicio y fin y se aplica', (
    tester,
  ) async {
    final cambios = await abrir(tester);
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pump();

    // "Aplicar" está desactivado hasta elegir el día de inicio.
    FilledButton aplicar() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Aplicar'),
    );
    expect(aplicar().onPressed, isNull);

    // Días 1 y 2 del mes actual (siempre ya ocurridos o hoy).
    await tester.tap(find.text('1').first);
    await tester.pump();
    expect(aplicar().onPressed, isNotNull);
    await tester.tap(find.text('1').first);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
    await tester.pump();
    expect(cambios, hasLength(1));
    expect(cambios.single!.start.day, 1);
  });

  testWidgets('tocar fuera de la tarjeta la cierra sin cambiar nada', (
    tester,
  ) async {
    final cambios = await abrir(tester);
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pump();
    expect(find.text('Aplicar'), findsOneWidget);
    await tester.tapAt(const Offset(40, 700));
    await tester.pump();
    expect(find.text('Aplicar'), findsNothing);
    expect(cambios, isEmpty);
  });
}

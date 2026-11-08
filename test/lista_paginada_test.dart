import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/widgets/lista_paginada.dart';

Widget _app(List<int> items, {Object? reiniciar, double ancho = 320}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: SizedBox(
        width: ancho,
        child: ListaPaginada<int>(
          items: items,
          porPagina: 5,
          reiniciarCon: reiniciar,
          itemBuilder: (i) => SizedBox(height: 30, child: Text('fila $i')),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('muestra 5 por página y pasa de página', (tester) async {
    await tester.pumpWidget(_app(List.generate(12, (i) => i + 1)));
    expect(find.text('fila 1'), findsOneWidget);
    expect(find.text('fila 5'), findsOneWidget);
    expect(find.text('fila 6'), findsNothing);
    expect(find.text('Mostrando 1-5 de 12'), findsOneWidget);

    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pump();
    expect(find.text('fila 6'), findsOneWidget);
    expect(find.text('fila 1'), findsNothing);
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pump();
    expect(find.text('Mostrando 11-12 de 12'), findsOneWidget);
    await tester.tap(find.byTooltip('Página anterior'));
    await tester.pump();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con pocas filas el paginador se muestra igual', (tester) async {
    await tester.pumpWidget(_app([1, 2, 3]));
    expect(find.text('Mostrando 1-3 de 3'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.byTooltip('Página siguiente'), findsOneWidget);
  });

  testWidgets('vuelve a la primera al cambiar el filtro y se ajusta al '
      'achicarse la lista', (tester) async {
    await tester.pumpWidget(
      _app(List.generate(12, (i) => i + 1), reiniciar: 'a'),
    );
    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pump();
    expect(find.text('fila 6'), findsOneWidget);
    await tester.pumpWidget(
      _app(List.generate(12, (i) => i + 1), reiniciar: 'b'),
    );
    expect(find.text('fila 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pump();
    await tester.pumpWidget(_app([1, 2, 3, 4, 5, 6], reiniciar: 'b'));
    expect(find.text('fila 6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

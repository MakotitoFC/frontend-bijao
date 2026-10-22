import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/widgets/tabla_app.dart';

void main() {
  Future<void> abrir(
    WidgetTester tester,
    double ancho, {
    double? anchoTabla,
  }) async {
    tester.view.physicalSize = Size(ancho, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: anchoTabla,
            child: TablaApp<({String nombre, int monto})>(
              filas: const [
                (nombre: 'Beto', monto: 30),
                (nombre: 'Ana', monto: 10),
                (nombre: 'Carla', monto: 20),
              ],
              columnas: [
                ColumnaTabla(
                  titulo: 'Nombre',
                  ordenarPor: (f) => f.nombre,
                  celda: (f) => TablaApp.texto(f.nombre),
                ),
                ColumnaTabla(
                  titulo: 'Monto',
                  ordenarPor: (f) => f.monto,
                  celda: (f) => TablaApp.texto('S/ ${f.monto}'),
                ),
                ColumnaTabla(
                  titulo: 'Sin orden',
                  celda: (f) => TablaApp.texto('x'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> nombres(WidgetTester tester) => [
    for (final t in tester.widgetList<Text>(find.byType(Text)))
      if (['Ana', 'Beto', 'Carla'].contains(t.data)) t.data!,
  ];

  testWidgets('muestra encabezados y filas con los datos', (tester) async {
    await abrir(tester, 900);
    expect(find.text('Nombre'), findsOneWidget);
    expect(find.text('Monto'), findsOneWidget);
    expect(find.text('S/ 30'), findsOneWidget);
    // Solo las columnas ordenables llevan el indicador de orden.
    expect(find.byIcon(Icons.unfold_more), findsNWidgets(2));
    expect(nombres(tester), ['Beto', 'Ana', 'Carla']);
  });

  testWidgets('tocar el encabezado ordena y al repetir invierte', (
    tester,
  ) async {
    await abrir(tester, 900);
    await tester.tap(find.text('Nombre'));
    await tester.pump();
    expect(nombres(tester), ['Ana', 'Beto', 'Carla']);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    await tester.tap(find.text('Nombre'));
    await tester.pump();
    expect(nombres(tester), ['Carla', 'Beto', 'Ana']);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

    await tester.tap(find.text('Monto'));
    await tester.pump();
    expect(nombres(tester), ['Ana', 'Carla', 'Beto']);
  });

  testWidgets('en menos de una tablet se ve como tarjetas, sin desbordar', (
    tester,
  ) async {
    await abrir(tester, 200);
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('si no cabe en una tablet, se desplaza hacia el lado', (
    tester,
  ) async {
    await abrir(tester, 800, anchoTabla: 200);
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}

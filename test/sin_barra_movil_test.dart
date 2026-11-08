import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/widgets/barra_desplazamiento.dart';

// En celular la barra de desplazamiento no se ve; en pantallas anchas sí.
void main() {
  Future<void> pintar(WidgetTester tester, Size tam) async {
    tester.view.physicalSize = tam;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ctl = ScrollController();
    addTearDown(ctl.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BarraDesplazamiento(
            controller: ctl,
            thumbVisibility: true,
            child: ListView(
              controller: ctl,
              children: [for (var i = 0; i < 60; i++) Text('fila $i')],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('celular: sin barra de desplazamiento', (tester) async {
    await pintar(tester, const Size(375, 700));
    expect(find.byType(Scrollbar), findsNothing);
    expect(find.text('fila 0'), findsOneWidget);
  });

  testWidgets('pantalla ancha: con barra de desplazamiento', (tester) async {
    await pintar(tester, const Size(1200, 700));
    expect(find.byType(Scrollbar), findsOneWidget);
  });
}

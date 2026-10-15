import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/widgets/reportar_problema_dialog.dart';

void main() {
  testWidgets('al elegir Foto como evidencia aparece el cuadro para subirla', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReportarProblemaDialog(nombrePlato: 'Tacacho'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Subir foto'), findsNothing);

    await tester.tap(find.text('Sin evidencia').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Foto').last);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Subir foto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/widgets/utensilio_roto_form_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Registrar utensilio roto: cantidad, costo unitario y costo total quedan
// alineados y se adaptan al ancho (una fila en escritorio y tablet; en celular,
// el total pasa debajo).
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
  });

  Future<void> abrir(WidgetTester tester, Size tam) async {
    tester.view.physicalSize = tam;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Align(child: UtensilioRotoFormDialog())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('escritorio: los tres campos están alineados arriba', (
    tester,
  ) async {
    await abrir(tester, const Size(1200, 900));
    final cant = tester.getTopLeft(find.text('Cantidad *')).dy;
    final unit = tester.getTopLeft(find.text('Costo unit. (S/) *')).dy;
    final total = tester.getTopLeft(find.text('Costo Total (S/)')).dy;
    expect(unit, cant);
    expect(total, cant);
    // El aviso del costo ya no va recortado dentro del campo.
    expect(
      find.text('El costo unitario se actualizará en inventario.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('celular: el costo total pasa debajo', (tester) async {
    await abrir(tester, const Size(375, 812));
    final cant = tester.getTopLeft(find.text('Cantidad *')).dy;
    final unit = tester.getTopLeft(find.text('Costo unit. (S/) *')).dy;
    final total = tester.getTopLeft(find.text('Costo Total (S/)')).dy;
    expect(unit, cant);
    expect(total, greaterThan(cant));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final t in {
    'tablet 768': const Size(768, 1024),
    'celular chico 320': const Size(320, 640),
  }.entries) {
    testWidgets('sin desbordes en ${t.key}', (tester) async {
      await abrir(tester, t.value);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

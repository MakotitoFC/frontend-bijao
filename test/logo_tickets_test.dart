import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/logo_ticket_store.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/widgets/logo_tickets_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    logoTicketLocal.value = null;
  });

  test('el logo subido queda como copia local para la vista previa', () async {
    await guardarLogoTicketLocal([1, 2, 3, 4]);
    expect(logoTicketLocal.value, isNotNull);
    logoTicketLocal.value = null;
    await cargarLogoTicketLocal();
    expect(logoTicketLocal.value, [1, 2, 3, 4]);
  });

  testWidgets('el editor ofrece elegir una imagen para el logo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LogoTicketsEditor())),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Logo de los tickets de caja'), findsOneWidget);
    expect(find.text('Elegir imagen'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

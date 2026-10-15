import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/utils/blur_dialog.dart';
import 'package:frontend_bijao/widgets/app_select.dart';
import 'package:frontend_bijao/widgets/dialogo_app.dart';

const _items = [
  AppSelectItem(value: 'a', label: 'Administrador'),
  AppSelectItem(value: 'b', label: 'Trabajador'),
  AppSelectItem(value: 'c', label: 'Mozo / Mesero'),
  AppSelectItem(value: 'd', label: 'Cajero'),
];

Future<void> _abrirModal(
  WidgetTester tester, {
  required List<Widget> antes,
  required List<Widget> despues,
}) async {
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showBlurDialog<void>(
                context: context,
                builder: (_) => DialogoApp(
                  titulo: 'Prueba',
                  children: [
                    ...antes,
                    AppSelect<String>(
                      label: 'Rol',
                      value: 'c',
                      items: _items,
                      onChanged: (_) {},
                    ),
                    ...despues,
                  ],
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('con sitio debajo: las opciones salen debajo, dentro del modal', (
    tester,
  ) async {
    await _abrirModal(
      tester,
      antes: const [],
      despues: const [SizedBox(height: 320)],
    );
    final modal = tester.getRect(find.byType(DialogoApp));
    final campo = tester.getRect(find.text('Mozo / Mesero').first);

    await tester.tap(find.text('Mozo / Mesero').first);
    await tester.pumpAndSettle();

    final opcion = tester.getRect(find.text('Cajero'));
    expect(opcion.top, greaterThan(campo.bottom)); // debajo, sin tapar el campo
    expect(opcion.bottom, lessThanOrEqualTo(modal.bottom));
    expect(opcion.left, greaterThanOrEqualTo(modal.left));
    expect(opcion.right, lessThanOrEqualTo(modal.right));
  });

  testWidgets('sin sitio debajo: las opciones salen encima, sin tapar el campo', (
    tester,
  ) async {
    await _abrirModal(
      tester,
      antes: const [SizedBox(height: 330)],
      despues: const [],
    );
    final modal = tester.getRect(find.byType(DialogoApp));
    final campo = tester.getRect(find.text('Mozo / Mesero').first);

    await tester.tap(find.text('Mozo / Mesero').first);
    await tester.pumpAndSettle();

    final primera = tester.getRect(find.text('Administrador'));
    final ultima = tester.getRect(find.text('Cajero'));
    expect(ultima.bottom, lessThanOrEqualTo(campo.top)); // encima del campo
    expect(primera.top, greaterThanOrEqualTo(modal.top)); // dentro del modal
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/widgets/aviso_caja_cerrada.dart';

void main() {
  Future<void> abrir(WidgetTester tester, {VoidCallback? irAAbrir}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  mostrarAvisoCajaCerrada(context, irAAbrir: irAAbrir),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('cajero y administrador ven "Ir a abrir" y los lleva a Caja', (
    tester,
  ) async {
    var fue = false;
    await abrir(tester, irAAbrir: () => fue = true);
    expect(find.text('Caja cerrada'), findsOneWidget);
    expect(find.text('Más tarde'), findsOneWidget);
    await tester.tap(find.text('Ir a abrir'));
    await tester.pumpAndSettle();
    expect(fue, isTrue);
    expect(find.text('Caja cerrada'), findsNothing);
  });

  testWidgets('el mozo solo ve el aviso, sin botón para abrir', (tester) async {
    await abrir(tester);
    expect(find.textContaining('Avisa a caja'), findsOneWidget);
    expect(find.text('Ir a abrir'), findsNothing);
    expect(find.text('Entendido'), findsOneWidget);
  });

  test('sin servidor la caja no se da por cerrada', () async {
    expect(await cajaCerrada(), isFalse);
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/widgets/elevacion_teclado.dart';

// Modo de enfoque: en celular y tablet, al tocar un campo se abre un editor con
// solo ese campo (así el teclado no lo tapa); en computadora no pasa nada.
void main() {
  // Simula la plataforma y la deja como estaba antes de terminar la prueba.
  Future<void> con(TargetPlatform p, Future<void> Function() cuerpo) async {
    debugDefaultTargetPlatformOverride = p;
    try {
      await cuerpo();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  final nombre = TextEditingController();
  final cambios = <String>[];

  Future<void> montar(WidgetTester tester, {bool soloLectura = false}) async {
    nombre.clear();
    cambios.clear();
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ElevacionTeclado(child: child!),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                key: const ValueKey('nombre'),
                controller: nombre,
                readOnly: soloLectura,
                decoration: const InputDecoration(labelText: 'Nombre'),
                onChanged: cambios.add,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('cantidad'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Cantidad'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Campo del editor de enfoque: el que está en la tarjeta de arriba.
  Finder campoDelEditor() => find.descendant(
    of: find.ancestor(of: find.text('Listo'), matching: find.byType(Column)),
    matching: find.byType(TextField),
  );

  testWidgets('en celular, tocar un campo abre el editor con solo ese campo', (
    tester,
  ) async {
    await con(TargetPlatform.android, () async {
      await montar(tester);
      expect(find.text('Listo'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('nombre')));
      await tester.pumpAndSettle();
      expect(find.text('Listo'), findsOneWidget);
      // El título del editor es la etiqueta del campo.
      expect(find.text('Nombre'), findsWidgets);
      expect(campoDelEditor(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('lo escrito en el editor llega al campo original y a su aviso', (
    tester,
  ) async {
    await con(TargetPlatform.iOS, () async {
      await montar(tester);
      await tester.tap(find.byKey(const ValueKey('nombre')));
      await tester.pumpAndSettle();
      await tester.enterText(campoDelEditor(), 'Carlos');
      await tester.pump();
      // El mismo texto y el aviso de cambio del campo original.
      expect(nombre.text, 'Carlos');
      expect(cambios.last, 'Carlos');
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(find.text('Listo'), findsNothing);
      // Cerrar el editor no lo vuelve a abrir solo.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Listo'), findsNothing);
      expect(nombre.text, 'Carlos');
    });
  });

  testWidgets('el editor respeta el teclado y los filtros del campo', (
    tester,
  ) async {
    await con(TargetPlatform.android, () async {
      await montar(tester);
      await tester.tap(find.byKey(const ValueKey('cantidad')));
      await tester.pumpAndSettle();
      final editor = tester.widget<TextField>(campoDelEditor());
      expect(editor.keyboardType, TextInputType.number);
      // Solo dígitos, igual que el campo original.
      await tester.enterText(campoDelEditor(), '12ab3');
      await tester.pump();
      expect(
        tester.widget<TextField>(campoDelEditor()).controller!.text,
        '123',
      );
    });
  });

  testWidgets('tocar fuera de la tarjeta cierra el editor', (tester) async {
    await con(TargetPlatform.android, () async {
      await montar(tester);
      await tester.tap(find.byKey(const ValueKey('nombre')));
      await tester.pumpAndSettle();
      expect(find.text('Listo'), findsOneWidget);
      await tester.tapAt(const Offset(200, 800));
      await tester.pumpAndSettle();
      expect(find.text('Listo'), findsNothing);
    });
  });

  testWidgets('un campo de solo lectura no abre el editor', (tester) async {
    await con(TargetPlatform.android, () async {
      await montar(tester, soloLectura: true);
      await tester.tap(find.byKey(const ValueKey('nombre')));
      await tester.pumpAndSettle();
      expect(find.text('Listo'), findsNothing);
    });
  });

  testWidgets('en computadora no abre nada', (tester) async {
    await con(TargetPlatform.windows, () async {
      await montar(tester);
      await tester.tap(find.byKey(const ValueKey('nombre')));
      await tester.pumpAndSettle();
      expect(find.text('Listo'), findsNothing);
    });
  });

  testWidgets('el editor entra y sale con una transición suave', (
    tester,
  ) async {
    await con(TargetPlatform.android, () async {
      await montar(tester);
      await tester.tap(find.byKey(const ValueKey('nombre')));
      // El editor se inserta en el cuadro siguiente al cambio de foco.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      // A mitad de la entrada la tarjeta está a medio aparecer, no de golpe.
      double opacidad() => tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.text('Listo'),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;
      expect(opacidad(), greaterThan(0));
      expect(opacidad(), lessThan(1));
      await tester.pumpAndSettle();
      expect(opacidad(), 1);
      // Al cerrar, sigue en pantalla mientras se desvanece.
      await tester.tap(find.text('Listo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Listo'), findsOneWidget);
      expect(opacidad(), lessThan(1));
      await tester.pumpAndSettle();
      expect(find.text('Listo'), findsNothing);
    });
  });
}

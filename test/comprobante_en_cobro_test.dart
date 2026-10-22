import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/widgets/app_switch.dart';
import 'package:frontend_bijao/widgets/comprobante_en_cobro.dart';

void main() {
  Future<ComprobanteEnCobro> abrir(WidgetTester tester, double total) async {
    final control = ComprobanteEnCobro(total);
    addTearDown(control.dispose);
    tester.view.physicalSize = const Size(700, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SelectorComprobante(control: control),
          ),
        ),
      ),
    );
    await tester.pump();
    return control;
  }

  testWidgets('arranca en Ninguno: no emite nada y deja cobrar', (
    tester,
  ) async {
    final control = await abrir(tester, 52);
    expect(find.text('Ninguno'), findsOneWidget);
    expect(find.text('Ticket de venta'), findsOneWidget);
    expect(find.text('Boleta'), findsOneWidget);
    expect(find.text('Factura'), findsOneWidget);
    expect(control.emite, isFalse);
    expect(control.completo, isTrue);
    expect(find.text('Imprimir en la ticketera de caja'), findsNothing);
  });

  testWidgets('ticket de venta emite sin pedir datos', (tester) async {
    final control = await abrir(tester, 52);
    await tester.tap(find.text('Ticket de venta'));
    await tester.pump();
    expect(control.tipo, 'ticket_venta');
    expect(control.emite, isTrue);
    expect(control.completo, isTrue);
    expect(find.text('Imprimir en la ticketera de caja'), findsOneWidget);
  });

  testWidgets('boleta sin DNI va a CLIENTES VARIOS; con DNI pide datos', (
    tester,
  ) async {
    final control = await abrir(tester, 52);
    await tester.tap(find.text('Boleta'));
    await tester.pump();
    expect(find.textContaining('CLIENTES VARIOS'), findsOneWidget);
    expect(control.completo, isTrue);

    await tester.tap(find.byType(AppSwitch).first);
    await tester.pump();
    expect(control.completo, isFalse); // falta DNI y nombre
    await tester.enterText(find.byType(EditableText).at(0), '72458912');
    await tester.enterText(find.byType(EditableText).at(1), 'Juan Perez');
    await tester.pump();
    expect(control.completo, isTrue);
    await tester.enterText(find.byType(EditableText).at(0), '7245');
    await tester.pump();
    expect(control.completo, isFalse); // el DNI tiene 8 dígitos
  });

  testWidgets('con más de S/ 700 la boleta exige el DNI del cliente', (
    tester,
  ) async {
    final control = await abrir(tester, 850);
    await tester.tap(find.text('Boleta'));
    await tester.pump();
    expect(find.textContaining('SUNAT exige el DNI'), findsOneWidget);
    expect(control.completo, isFalse);
  });

  testWidgets('con S/ 700 exactos el DNI de la boleta es opcional', (
    tester,
  ) async {
    final control = await abrir(tester, 700);
    await tester.tap(find.text('Boleta'));
    await tester.pump();
    expect(find.textContaining('SUNAT exige el DNI'), findsNothing);
    expect(control.completo, isTrue);
  });

  testWidgets('factura pide RUC de 11 dígitos y razón social', (tester) async {
    final control = await abrir(tester, 52);
    await tester.tap(find.text('Factura'));
    await tester.pump();
    expect(control.completo, isFalse);
    await tester.enterText(find.byType(EditableText).at(0), '20100070970');
    await tester.pump();
    expect(control.completo, isFalse); // falta la razón social
    await tester.enterText(
      find.byType(EditableText).at(1),
      'SUPERMERCADOS S.A.',
    );
    await tester.pump();
    expect(control.completo, isTrue);
    expect(find.byTooltip('Buscar en SUNAT'), findsOneWidget);
  });

  testWidgets('volver a Ninguno vuelve a dejar cobrar aunque falten datos', (
    tester,
  ) async {
    final control = await abrir(tester, 52);
    await tester.tap(find.text('Factura'));
    await tester.pump();
    expect(control.completo, isFalse);
    await tester.tap(find.text('Ninguno'));
    await tester.pump();
    expect(control.emite, isFalse);
    expect(control.completo, isTrue);
  });
}

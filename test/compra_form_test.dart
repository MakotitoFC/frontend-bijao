import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/compras_store.dart';
import 'package:frontend_bijao/models/compra.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/widgets/compra_form_dialog.dart';
import 'package:frontend_bijao/widgets/inventario/pagina_compras.dart';
import 'package:frontend_bijao/widgets/selector_rango_fechas.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Nueva compra: un solo modal con fecha (calendario flotante), notas y
// productos. Las compras guardadas se listan paginadas.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    compras.clear();
    detallesPorCompra.clear();
  });

  tearDown(() {
    compras.clear();
    detallesPorCompra.clear();
  });

  testWidgets('un solo modal: fecha, notas y productos juntos', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: CompraFormDialog())),
      ),
    );
    await tester.pump();
    expect(find.text('Nueva compra'), findsOneWidget);
    expect(find.text('Fecha de compra'), findsOneWidget);
    expect(find.byType(SelectorRangoFechas), findsOneWidget);
    // Los productos van en el mismo modal, no en un segundo paso, y hay un
    // solo botón de guardado (sin "Agregar detalle").
    expect(find.text('Productos comprados'), findsOneWidget);
    // Una sola tarjeta de producto; otra solo si el usuario la pide.
    expect(find.text('Cantidad'), findsOneWidget);
    expect(find.text('Agregar otro producto'), findsOneWidget);
    expect(find.text('Agregar detalle'), findsNothing);
    expect(find.text('Crear compra'), findsNothing);
    expect(find.text('Guardar compra'), findsOneWidget);

    await tester.ensureVisible(find.text('Agregar otro producto'));
    await tester.tap(find.text('Agregar otro producto'));
    await tester.pump();
    expect(find.text('Cantidad'), findsNWidgets(2));
    expect(find.text('Producto 1'), findsOneWidget);
    expect(find.text('Producto 2'), findsOneWidget);
    // El calendario es una tarjeta flotante, no otro diálogo.
    await tester.tap(find.byType(SelectorRangoFechas));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Nueva compra'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Mientras se arma no se crea nada: cerrar sin guardar no deja rastro.
    expect(compras, isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(compras, isEmpty);
  });

  testWidgets('sin productos no se puede guardar la compra', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: CompraFormDialog())),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Guardar compra'));
    await tester.tap(find.text('Guardar compra'));
    await tester.pump();
    expect(
      find.text('Agrega al menos un producto a la compra.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('las compras guardadas se muestran de a 6 por página', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (var i = 0; i < 8; i++) {
      compras.add(
        Compra(id: 'c$i', fechaCompra: DateTime(2026, 11, 1 + i), total: 10),
      );
      detallesPorCompra['c$i'] = [];
    }
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PaginaCompras())),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Compra del'), findsNWidgets(6));
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pump();
    expect(find.textContaining('Compra del'), findsNWidgets(2));
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final t in {
    'celular 375': const Size(375, 812),
    'celular chico 320': const Size(320, 640),
    'tablet 768': const Size(768, 1024),
  }.entries) {
    testWidgets('el modal se dibuja sin desbordes en ${t.key}', (tester) async {
      tester.view.physicalSize = t.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Align(child: CompraFormDialog())),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

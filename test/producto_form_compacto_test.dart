import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/cartas_store.dart';
import 'package:frontend_bijao/data/catalogos_store.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/models/tipo_producto.dart';
import 'package:frontend_bijao/models/unidad_producto.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/widgets/producto_inventario_form_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _carta = CartaItem(
  id: '01925b6a-9b1d-7234-a123-abcdef000001',
  nombrePlato: 'COCA COLA 1.5 LT',
  descripcion: '',
  categoriaId: 'c1',
  precioCliente: 10,
);

// El formulario de un producto nuevo se acorta cuando se vende (carta o táper):
// pide solo nombre, stock y mínimo, y rellena lo demás.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    cartasNotifier.value = [_carta];
    tiposProducto
      ..clear()
      ..addAll(const [
        TipoProducto(id: 't1', tipoProducto: 'Cocina'),
        TipoProducto(id: 't2', tipoProducto: 'Gaseosa'),
      ]);
    unidadesProducto
      ..clear()
      ..addAll(const [
        UnidadProducto(id: 'u1', unidad: 'Kg'),
        UnidadProducto(id: 'u2', unidad: 'Unidad'),
      ]);
  });

  tearDown(() {
    cartasNotifier.value = [];
    tiposProducto.clear();
    unidadesProducto.clear();
  });

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ProductoInventarioFormDialog()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('"No se vende" muestra el formulario completo', (tester) async {
    await abrir(tester);
    expect(find.text('Descripción'), findsOneWidget);
    expect(find.text('Costo repos. (S/)'), findsOneWidget);
    expect(find.text('Notas adicionales (opcional)'), findsOneWidget);
  });

  testWidgets('"Se vende en la carta" acorta el formulario', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Se vende en la carta'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Descripción'), findsNothing);
    expect(find.text('Costo repos. (S/)'), findsNothing);
    expect(find.text('Notas adicionales (opcional)'), findsNothing);
    // Lo necesario sigue ahí.
    expect(find.text('Nombre del producto *'), findsOneWidget);
    expect(find.text('Stock actual *'), findsOneWidget);
    expect(find.text('Stock mínimo'), findsOneWidget);
    // Se preselecciona la unidad "Unidad" y el tipo de bebida.
    expect(find.text('Unidad'), findsWidgets);
    expect(find.text('Gaseosa'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('al elegir el producto de la carta se rellena el nombre', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.text('Se vende en la carta'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Elige un producto').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('COCA COLA 1.5 LT').last);
    await tester.pumpAndSettle();
    final textos = [
      for (final e in tester.widgetList<EditableText>(
        find.byType(EditableText),
      ))
        e.controller.text,
    ];
    // El nombre del producto se rellenó con el de la carta.
    expect(textos, contains('COCA COLA 1.5 LT'));
  });
}

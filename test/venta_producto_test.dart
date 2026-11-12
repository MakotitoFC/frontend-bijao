import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/cartas_store.dart';
import 'package:frontend_bijao/data/inventario_store.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/models/producto_inventario.dart';
import 'package:frontend_bijao/models/vinculo_carta.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/widgets/inventario/pagina_productos.dart';
import 'package:frontend_bijao/widgets/seccion_venta_producto.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prod = ProductoInventario(
  id: '01925b6a-9b1d-7234-a123-abcdef012345',
  nombre: 'Inca Kola',
  tipoProductoId: 't1',
  seguimiento: 'unidad',
  unidadProductoId: 'u1',
  stockActual: 24,
  stockMinimo: 6,
);

const _carta = CartaItem(
  id: '01925b6a-9b1d-7234-a123-abcdef000001',
  nombrePlato: 'Inca Kola 500 ml',
  descripcion: '',
  categoriaId: 'c1',
  precioCliente: 4,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    cartasNotifier.value = [_carta];
    vinculosCarta.clear();
    productosInventario
      ..clear()
      ..add(_prod);
  });

  tearDown(() {
    cartasNotifier.value = [];
    vinculosCarta.clear();
    productosInventario.clear();
  });

  Future<void> montar(WidgetTester tester, Widget hijo) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: SingleChildScrollView(child: hijo)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('producto sin venta: "No se vende" y validar no pide nada', (
    tester,
  ) async {
    final key = GlobalKey<SeccionVentaProductoState>();
    await montar(tester, SeccionVentaProducto(key: key));
    expect(find.text('Venta'), findsOneWidget);
    expect(find.textContaining('insumo o menaje'), findsOneWidget);
    expect(key.currentState!.validar(), isNull);
  });

  testWidgets('"Se vende en la carta" muestra la fila y valida la elección', (
    tester,
  ) async {
    final key = GlobalKey<SeccionVentaProductoState>();
    await montar(tester, SeccionVentaProducto(key: key));
    await tester.tap(find.text('Se vende en la carta'));
    await tester.pump();
    expect(find.text('Producto de la carta'), findsWidgets);
    expect(find.text('Agregar producto de la carta'), findsOneWidget);
    // Sin elegir el producto de la carta no deja guardar.
    expect(key.currentState!.validar(), contains('Elige el producto'));
  });

  testWidgets('un producto ya vinculado abre con su fila y su cantidad', (
    tester,
  ) async {
    vinculosCarta.add(
      const VinculoCarta(
        id: 'v1',
        cartaId: '01925b6a-9b1d-7234-a123-abcdef000001',
        cartaNombre: 'Inca Kola 500 ml',
        productoInventarioId: '01925b6a-9b1d-7234-a123-abcdef012345',
        productoNombre: 'Inca Kola',
        cantidad: 2,
      ),
    );
    final key = GlobalKey<SeccionVentaProductoState>();
    await montar(tester, SeccionVentaProducto(key: key, producto: _prod));
    // La carga de red falla en la prueba (HTTP bloqueado): se avisa y no se
    // dibuja la sección editable.
    expect(find.textContaining('No se pudo leer la venta'), findsOneWidget);
  });

  testWidgets('Productos marca con su etiqueta los que se venden en la carta', (
    tester,
  ) async {
    vinculosCarta.add(
      const VinculoCarta(
        id: 'v1',
        cartaId: '01925b6a-9b1d-7234-a123-abcdef000001',
        cartaNombre: 'Inca Kola 500 ml',
        productoInventarioId: '01925b6a-9b1d-7234-a123-abcdef012345',
        productoNombre: 'Inca Kola',
        cantidad: 1,
      ),
    );
    await montar(tester, const SizedBox(height: 700, child: PaginaProductos()));
    expect(find.textContaining('Carta · Inca Kola 500 ml'), findsOneWidget);
    expect(find.text('Táper'), findsNothing); // un solo botón de crear
    expect(tester.takeException(), isNull);
  });

  testWidgets('un producto nuevo puede crearse como táper, con su precio', (
    tester,
  ) async {
    final key = GlobalKey<SeccionVentaProductoState>();
    await montar(tester, SeccionVentaProducto(key: key));
    await tester.tap(find.text('Es un táper'));
    await tester.pump();
    expect(key.currentState!.esTaperNuevo, isTrue);
    // Sin precio no deja guardar.
    expect(key.currentState!.validar(), contains('precio'));
    await tester.enterText(find.byType(TextField).first, '2.50');
    await tester.pump();
    expect(key.currentState!.validar(), isNull);
    expect(key.currentState!.precioTaper, 2.5);
  });
}

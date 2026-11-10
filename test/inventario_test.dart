import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/catalogos_store.dart';
import 'package:frontend_bijao/data/inventario_store.dart';
import 'package:frontend_bijao/models/producto_inventario.dart';
import 'package:frontend_bijao/models/tipo_producto.dart';
import 'package:frontend_bijao/models/unidad_producto.dart';
import 'package:frontend_bijao/screens/inventario_screen.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tipo = TipoProducto(id: 't1', tipoProducto: 'Insumo');
const _unidad = UnidadProducto(id: 'u1', unidad: 'Kg');

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    tiposProducto
      ..clear()
      ..add(_tipo);
    unidadesProducto
      ..clear()
      ..add(_unidad);
    productosInventario
      ..clear()
      ..addAll(const [
        ProductoInventario(
          id: 'p1',
          nombre: 'Arroz',
          tipoProductoId: 't1',
          unidadProductoId: 'u1',
          stockActual: 2,
          stockMinimo: 5,
        ),
        ProductoInventario(
          id: 'p2',
          nombre: 'Sal',
          tipoProductoId: 't1',
          unidadProductoId: 'u1',
          stockActual: 0,
        ),
        ProductoInventario(
          id: 'p3',
          nombre: 'Aceite',
          tipoProductoId: 't1',
          unidadProductoId: 'u1',
          stockActual: 20,
          stockMinimo: 3,
        ),
      ]);
  });

  tearDown(() {
    tiposProducto.clear();
    unidadesProducto.clear();
    productosInventario.clear();
  });

  Future<void> abrir(WidgetTester tester, Size tam) async {
    tester.view.physicalSize = tam;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: InventarioScreen()));
    await tester.pump(const Duration(milliseconds: 400));
  }

  // Productos, Tipos y unidades y Tápers son pestañas dentro de Almacén.
  const subvistasAlmacen = {'Productos', 'Tipos y unidades', 'Tápers'};

  Future<void> ir(WidgetTester tester, String etiqueta) async {
    // Celular: se abre desde el índice; si hay una subvista abierta, se vuelve
    // primero a él.
    if (tester.view.physicalSize.width < 700 &&
        find.byTooltip('Volver').evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip('Volver'));
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (subvistasAlmacen.contains(etiqueta)) {
      await tester.ensureVisible(find.text('Almacén').first);
      await tester.pump();
      await tester.tap(find.text('Almacén').first);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.ensureVisible(find.text(etiqueta).first);
    await tester.pump();
    await tester.tap(find.text(etiqueta).first);
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('escritorio: submenú con todas las páginas, sin desbordes', (
    tester,
  ) async {
    await abrir(tester, const Size(1400, 900));

    // Resumen: lo que hay que reponer sale primero, con su acción.
    expect(find.text('Por reponer'), findsOneWidget);
    expect(find.text('Sal'), findsOneWidget); // sin stock
    expect(find.text('Arroz'), findsOneWidget); // stock bajo
    expect(find.text('Aceite'), findsNothing); // en orden: no aparece aquí

    for (final p in [
      'Productos',
      'Tipos y unidades',
      'Tápers',
      'Movimientos',
      'Anulaciones',
      'Resumen',
    ]) {
      await ir(tester, p);
      expect(tester.takeException(), isNull, reason: p);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Movimientos: una vista con filtros y Anulaciones aparte', (
    tester,
  ) async {
    await abrir(tester, const Size(1400, 900));
    await ir(tester, 'Movimientos');
    // Los tabs del contenido son los de texto, sin "Utensilios rotos" aparte.
    for (final f in [
      'Todos',
      'Compras',
      'Mermas y ajustes',
      'Roturas',
      'Alquileres',
    ]) {
      expect(find.text(f), findsWidgets, reason: f);
    }
    for (final f in [
      'Compras',
      'Roturas',
      'Alquileres',
      'Mermas y ajustes',
      'Todos',
    ]) {
      await tester.tap(find.text(f).first);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: f);
    }
    expect(find.text('Utensilios rotos'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Productos: un solo botón para crear y acciones en el menú', (
    tester,
  ) async {
    await abrir(tester, const Size(1400, 900));
    await ir(tester, 'Productos');

    // No se repite "Producto" como botón (ni "Táper", "Tipo" o "Unidad").
    expect(find.text('Producto'), findsOneWidget);
    expect(find.text('Táper'), findsNothing);
    expect(find.text('Tipo'), findsNothing);
    expect(find.text('Unidad'), findsNothing);

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Sal'), findsOneWidget);
    expect(find.text('Aceite'), findsOneWidget);

    // El buscador filtra.
    await tester.enterText(find.byType(TextField).first, 'ace');
    await tester.pump();
    expect(find.text('Aceite'), findsOneWidget);
    expect(find.text('Arroz'), findsNothing);

    // Las demás acciones salen del menú de la fila.
    await tester.tap(find.byTooltip('Más acciones'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ver movimientos'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Tipos y unidades lista y permite crear cada uno', (
    tester,
  ) async {
    await abrir(tester, const Size(1400, 900));
    await ir(tester, 'Tipos y unidades');
    expect(find.text('Insumo'), findsOneWidget);
    expect(find.text('Kg'), findsOneWidget);
    expect(find.text('Tipo'), findsOneWidget);
    expect(find.text('Unidad'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final t in {
    'celular': const Size(375, 812),
    'celular chico': const Size(320, 640),
    'tablet': const Size(768, 1024),
  }.entries) {
    testWidgets('${t.key}: cada página se dibuja sin desbordes', (
      tester,
    ) async {
      await abrir(tester, t.value);
      for (final p in [
        'Productos',
        'Tipos y unidades',
        'Tápers',
        'Movimientos',
        'Anulaciones',
        'Resumen',
      ]) {
        await ir(tester, p);
        expect(tester.takeException(), isNull, reason: '$p en ${t.key}');
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}

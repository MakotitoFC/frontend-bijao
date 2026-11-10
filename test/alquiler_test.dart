import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/inventario_store.dart';
import 'package:frontend_bijao/models/movimiento_caja.dart';
import 'package:frontend_bijao/models/producto_inventario.dart';
import 'package:frontend_bijao/services/alquiler_service.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/widgets/alquiler_dialog.dart';
import 'package:frontend_bijao/widgets/inventario/pagina_alquileres.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Alquiler de menaje: su ficha viaja en la nota del ingreso de Caja.
const _prodId = '01925b6a-9b1d-7234-a123-abcdef012345';

ProductoInventario _mantel() => ProductoInventario(
  id: _prodId,
  nombre: 'Mantel',
  tipoProductoId: 't1',
  tipoProductoNombre: 'Alquiler',
  seguimiento: 'unidad',
  unidadProductoId: 'u1',
  stockActual: 10,
  stockMinimo: 2,
  costoPromedio: 12,
  precioCliente: 15,
);

MovimientoCaja _mov(String nota, {bool anulado = false}) => MovimientoCaja(
  id: 'm1',
  tipo: TipoMovimiento.ingreso,
  categoriaId: 'c1',
  categoriaNombre: 'Alquiler',
  monto: 30,
  medioPagoId: 'mp1',
  medioPagoNombre: 'Efectivo',
  fecha: DateTime(2026, 11, 9, 10),
  nota: nota,
  anulado: anulado,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    productosInventario
      ..clear()
      ..add(_mantel());
  });

  tearDown(productosInventario.clear);

  group('ficha en la nota', () {
    test('se arma y se lee igual, con cliente y notas', () {
      final nota = Alquiler.codificar(
        producto: _mantel(),
        cantidad: 2,
        precioUnitario: 15,
        cliente: 'Juan',
        notas: 'Boda',
      );
      final a = Alquiler.deMovimiento(_mov(nota))!;
      expect(a.productoId, _prodId);
      expect(a.cantidad, 2);
      expect(a.precioUnitario, 15);
      expect(a.cliente, 'Juan');
      expect(a.notas, 'Boda');
      expect(a.afuera, isTrue);
      expect(a.devuelto, isFalse);
    });

    test('al devolver queda marcado y deja de estar afuera', () {
      final nota = Alquiler.codificar(
        producto: _mantel(),
        cantidad: 2,
        precioUnitario: 15,
        cliente: '',
        devueltoEl: DateTime(2026, 11, 10, 9),
      );
      final a = Alquiler.deMovimiento(_mov(nota))!;
      expect(a.devuelto, isTrue);
      expect(a.afuera, isFalse);
      expect(a.cliente, '');
    });

    test('un movimiento anulado no cuenta como afuera', () {
      final nota = Alquiler.codificar(
        producto: _mantel(),
        cantidad: 1,
        precioUnitario: 15,
        cliente: 'Ana',
      );
      final a = Alquiler.deMovimiento(_mov(nota, anulado: true))!;
      expect(a.anulado, isTrue);
      expect(a.afuera, isFalse);
    });

    test('un ingreso común de Caja no es un alquiler', () {
      expect(Alquiler.deMovimiento(_mov('Compra de hielo')), isNull);
    });

    test('cuenta las unidades que están afuera', () {
      final nota = Alquiler.codificar(
        producto: _mantel(),
        cantidad: 3,
        precioUnitario: 15,
        cliente: '',
      );
      final a = Alquiler.deMovimiento(_mov(nota))!;
      expect(AlquilerService.afueraDe([a], _prodId), 3);
      expect(AlquilerService.afueraDe([a], 'otro'), 0);
    });
  });

  Future<void> abrir(WidgetTester tester, Widget w, Size tam) async {
    tester.view.physicalSize = tam;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: w)));
    await tester.pump(const Duration(milliseconds: 200));
  }

  for (final t in {
    'escritorio': const Size(1200, 900),
    'tablet 768': const Size(768, 1024),
    'celular 375': const Size(375, 812),
    'celular chico 320': const Size(320, 640),
  }.entries) {
    testWidgets('el modal Alquiler se dibuja sin desbordes en ${t.key}', (
      tester,
    ) async {
      await abrir(tester, const Align(child: AlquilerDialog()), t.value);
      expect(find.text('Cobrar y registrar'), findsOneWidget);
      expect(find.text('Cantidad'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('sin producto no deja cobrar', (tester) async {
    await abrir(
      tester,
      const Align(child: AlquilerDialog()),
      const Size(900, 900),
    );
    await tester.tap(find.text('Cobrar y registrar'));
    await tester.pump();
    expect(find.text('Elige el producto de alquiler.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('la pestaña Alquileres muestra su estado vacío y sus filtros', (
    tester,
  ) async {
    await abrir(tester, const PaginaAlquileres(), const Size(1000, 800));
    for (final f in ['Todos', 'Afuera', 'Devueltos', 'Anulados']) {
      expect(find.text(f), findsOneWidget, reason: f);
    }
    expect(find.text('Alquiler'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/catalogos_store.dart';
import 'package:frontend_bijao/data/inventario_store.dart';
import 'package:frontend_bijao/models/inventario_movimiento.dart';
import 'package:frontend_bijao/models/producto_inventario.dart';
import 'package:frontend_bijao/models/tipo_movimiento.dart';
import 'package:frontend_bijao/models/unidad_producto.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/utils/reporte_inventario.dart';
import 'package:frontend_bijao/utils/reporte_inventario_pdf.dart';
import 'package:frontend_bijao/widgets/inventario/pagina_reportes.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _compra = TipoMovimiento(id: 'e', tipoMovimiento: 'Compra', signo: 1);
const _consumo = TipoMovimiento(id: 's', tipoMovimiento: 'Consumo', signo: -1);

InventarioMovimiento _m(
  TipoMovimiento tipo,
  double cantidad,
  DateTime fecha, {
  String producto = 'p1',
  String? notas,
  double costo = 0,
}) => InventarioMovimiento(
  id: '${fecha.microsecondsSinceEpoch}$producto$cantidad',
  productoInventarioId: producto,
  productoNombre: producto == 'p1' ? 'Arroz' : 'Sal',
  tipoMovimiento: tipo,
  cantidad: cantidad,
  costoTotal: costo,
  notas: notas,
  fecha: fecha,
);

ProductoInventario _p(String id, String nombre, double stock) =>
    ProductoInventario(
      id: id,
      nombre: nombre,
      tipoProductoId: 't1',
      seguimiento: 'unidad',
      unidadProductoId: 'u1',
      stockActual: stock,
      stockMinimo: 0,
    );

void main() {
  final dia10 = DateTime(2026, 11, 10);
  final dia11 = DateTime(2026, 11, 11);
  final dia12 = DateTime(2026, 11, 12);

  group('cálculo del reporte', () {
    // Arroz: stock actual 20. Entró 30 el 10, entró 10 y salió 4 el 11, salió 6
    // el 12.
    final movs = [
      _m(_compra, 30, dia10.add(const Duration(hours: 9)), costo: 90),
      _m(_compra, 10, dia11.add(const Duration(hours: 10)), costo: 35),
      _m(_consumo, 4, dia11.add(const Duration(hours: 12))),
      _m(_consumo, 6, dia12.add(const Duration(hours: 13))),
    ];
    final productos = [_p('p1', 'Arroz', 20)];

    test('entradas, salidas y costo del día', () {
      final r = calcularReporteInventario(
        dia: dia11,
        movimientos: movs,
        productos: productos,
      );
      expect(r.movimientos.length, 2);
      expect(r.cantidadEntradas, 1);
      expect(r.cantidadSalidas, 1);
      expect(r.costoEntradas, 35);
      expect(r.porTipo, {'Compra': 1, 'Consumo': 1});
      expect(r.vacio, isFalse);
    });

    test('el stock inicial y final salen del stock actual', () {
      final r = calcularReporteInventario(
        dia: dia11,
        movimientos: movs,
        productos: productos,
      );
      final f = r.productos.single;
      expect(f.entradas, 10);
      expect(f.salidas, 4);
      // Al cierre del 11: 20 actual + 6 que salieron el 12.
      expect(f.fin, 26);
      expect(f.inicio, 20);
      expect(f.neto, 6);
    });

    test('el día siguiente cierra con el stock actual', () {
      final r = calcularReporteInventario(
        dia: dia12,
        movimientos: movs,
        productos: productos,
      );
      final f = r.productos.single;
      expect(f.fin, 20);
      expect(f.inicio, 26);
    });

    test('un día sin movimientos sale vacío', () {
      final r = calcularReporteInventario(
        dia: DateTime(2026, 11, 8),
        movimientos: movs,
        productos: productos,
      );
      expect(r.vacio, isTrue);
      expect(r.productos, isEmpty);
    });

    test('los movimientos de la noche cuentan en su propio día', () {
      final noche = [
        _m(_consumo, 2, DateTime(2026, 11, 11, 23, 50)),
        _m(_consumo, 1, DateTime(2026, 11, 12, 0, 10)),
      ];
      final r11 = calcularReporteInventario(
        dia: dia11,
        movimientos: noche,
        productos: productos,
      );
      final r12 = calcularReporteInventario(
        dia: dia12,
        movimientos: noche,
        productos: productos,
      );
      expect(r11.movimientos.length, 1);
      expect(r12.movimientos.length, 1);
    });
  });

  group('PDF', () {
    final r = calcularReporteInventario(
      dia: dia11,
      movimientos: [
        _m(
          _compra,
          10,
          dia11.add(const Duration(hours: 10, minutes: 5)),
          costo: 35,
        ),
        _m(
          _consumo,
          4,
          dia11.add(const Duration(hours: 12)),
          notas: 'Pedido; mesa "3" ñandú ✓',
        ),
      ],
      productos: [_p('p1', 'Arroz', 20)],
    );

    test('genera un PDF válido con el día elegido', () async {
      final bytes = await reporteInventarioPdf(
        r,
        unidadDe: (_) => 'Kg',
        generado: DateTime(2026, 11, 12, 9, 30),
      );
      // Cabecera y cierre de un PDF.
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(
        String.fromCharCodes(bytes.skip(bytes.length - 8)),
        contains('%%EOF'),
      );
      expect(bytes.length, greaterThan(1500));
    });

    test('un día sin movimientos también genera su PDF', () async {
      final vacio = calcularReporteInventario(
        dia: DateTime(2026, 11, 8),
        movimientos: const [],
        productos: const [],
      );
      final bytes = await reporteInventarioPdf(vacio, unidadDe: (_) => '');
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('muchos movimientos pasan a más páginas sin fallar', () async {
      final muchos = [
        for (var i = 0; i < 150; i++)
          _m(
            i.isEven ? _compra : _consumo,
            1.0 + i,
            dia11.add(Duration(minutes: i)),
            notas: 'Movimiento número $i',
          ),
      ];
      final grande = calcularReporteInventario(
        dia: dia11,
        movimientos: muchos,
        productos: [_p('p1', 'Arroz', 20)],
      );
      final bytes = await reporteInventarioPdf(grande, unidadDe: (_) => 'Kg');
      final texto = String.fromCharCodes(bytes);
      // Más de una página: el PDF declara cuántas tiene en "/Count".
      final cuentas = [
        for (final m in RegExp(r'/Count\s+(\d+)').allMatches(texto))
          int.parse(m.group(1)!),
      ];
      expect(cuentas, isNotEmpty);
      expect(cuentas.reduce((a, b) => a > b ? a : b), greaterThan(1));
    });

    test('la fecha larga sale en español', () {
      expect(
        fechaLarga(DateTime(2026, 11, 12)),
        'jueves 12 de noviembre de 2026',
      );
    });
  });

  group('página', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ApiClient.instance.initialize();
      unidadesProducto
        ..clear()
        ..add(const UnidadProducto(id: 'u1', unidad: 'Kg'));
      productosInventario
        ..clear()
        ..add(_p('p1', 'Arroz', 20));
      final hoy = soloDia(DateTime.now());
      final ayer = hoy.subtract(const Duration(days: 1));
      movimientosInventario
        ..clear()
        ..['p1'] = [
          _m(_compra, 10, hoy.add(const Duration(hours: 8)), costo: 35),
          _m(_consumo, 4, hoy.add(const Duration(hours: 9))),
          _m(_consumo, 1, ayer.add(const Duration(hours: 11))),
        ];
    });

    tearDown(() {
      productosInventario.clear();
      movimientosInventario.clear();
      unidadesProducto.clear();
    });

    Future<void> abrir(WidgetTester tester, Size tam) async {
      tester.view.physicalSize = tam;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: PaginaReportes()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    for (final tam in const [Size(1200, 900), Size(375, 812)]) {
      testWidgets('muestra el día de hoy y se mueve con las flechas '
          '(${tam.width.round()} px)', (tester) async {
        await abrir(tester, tam);
        expect(find.text('Hoy'), findsOneWidget);
        // Hoy: 2 movimientos (1 entrada, 1 salida) y el costo de la compra.
        expect(find.text('2'), findsOneWidget);
        expect(find.text('S/ 35.00'), findsOneWidget);
        expect(find.text('Arroz'), findsOneWidget);
        expect(find.textContaining('Inicio'), findsOneWidget);

        await tester.tap(find.text('Detalle'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Compra'), findsOneWidget);
        expect(find.text('Consumo'), findsOneWidget);

        // Ayer: un solo movimiento (la salida de 1).
        await tester.tap(find.byTooltip('Día anterior'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Ayer'), findsOneWidget);
        expect(find.text('Compra'), findsNothing);
        expect(find.text('Consumo'), findsOneWidget);
        expect(find.text('-1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('un día sin movimientos lo dice y no deja descargar', (
      tester,
    ) async {
      await abrir(tester, const Size(1200, 900));
      await tester.tap(find.byTooltip('Día anterior'));
      await tester.pump();
      await tester.tap(find.byTooltip('Día anterior'));
      // La lectura del servidor falla en la prueba: se espera a que termine.
      await tester.pump(const Duration(seconds: 10));
      expect(
        find.text('No hubo movimientos de inventario ese día.'),
        findsOneWidget,
      );
      final boton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Descargar PDF'),
      );
      expect(boton.onPressed, isNull);
    });
  });
}

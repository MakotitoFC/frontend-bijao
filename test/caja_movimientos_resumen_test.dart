import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/cierres_store.dart';
import 'package:frontend_bijao/data/movimientos_caja_store.dart';
import 'package:frontend_bijao/data/pagos_store.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/movimiento_caja.dart';
import 'package:frontend_bijao/models/pago.dart';

const _efectivo = MedioPago(
  id: 'mp1',
  medioPago: 'Efectivo',
  aplicaComision: false,
);
const _tarjeta = MedioPago(
  id: 'mp2',
  medioPago: 'Tarjeta',
  aplicaComision: true,
  porcentajeComision: 4,
);

Pago _pago(MedioPago medio, double cobrado, {DateTime? fecha}) => Pago(
  id: 'pg-${pagos.length}',
  pedidoId: 'ped-${pagos.length}',
  mesaNumero: 1,
  medioPago: medio,
  montoAbonado: cobrado,
  montoComision: 0,
  montoCobrado: cobrado,
  propina: 0,
  fechaPago: fecha ?? DateTime.now(),
);

MovimientoCaja _mov(
  TipoMovimiento tipo,
  double monto,
  String medio, {
  bool anulado = false,
  DateTime? fecha,
}) => MovimientoCaja(
  id: 'm-${movimientosCaja.length}',
  tipo: tipo,
  categoriaId: 'c',
  categoriaNombre: 'Categoría',
  monto: monto,
  medioPagoId: 'id-$medio',
  medioPagoNombre: medio,
  fecha: fecha ?? DateTime.now(),
  anulado: anulado,
);

void main() {
  setUp(() {
    pagos.clear();
    movimientosCaja.clear();
    cierresCaja.clear();
  });
  tearDown(() {
    pagos.clear();
    movimientosCaja.clear();
    cierresCaja.clear();
  });

  test('el resumen suma ventas, ingresos y salidas por medio de pago', () {
    pagos
      ..add(_pago(_efectivo, 100))
      ..add(_pago(_tarjeta, 52));
    movimientosCaja
      ..add(_mov(TipoMovimiento.ingreso, 20, 'Efectivo'))
      ..add(_mov(TipoMovimiento.egreso, 35, 'Efectivo'));

    final filas = resumenPorMedio(inicioCajaActual);
    final ef = filas.firstWhere((f) => f.medio == 'Efectivo');
    expect(ef.ventas, 100);
    expect(ef.ingresos, 20);
    expect(ef.egresos, 35);
    expect(ef.neto, 85); // 100 + 20 - 35
    expect(filas.firstWhere((f) => f.medio == 'Tarjeta').neto, 52);
    // El efectivo va primero.
    expect(filas.first.medio, 'Efectivo');
  });

  test('un movimiento anulado no cuenta en los totales', () {
    movimientosCaja
      ..add(_mov(TipoMovimiento.egreso, 40, 'Efectivo'))
      ..add(_mov(TipoMovimiento.egreso, 99, 'Efectivo', anulado: true));
    final t = totalesMovimientos(inicioCajaActual);
    expect(t.egresos, 40);
    expect(
      resumenPorMedio(inicioCajaActual)
          .firstWhere((f) => f.medio == 'Efectivo')
          .egresos,
      40,
    );
  });

  test('lo anterior al último cierre queda fuera de la caja actual', () {
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    movimientosCaja.add(
      _mov(TipoMovimiento.egreso, 70, 'Efectivo', fecha: ayer),
    );
    expect(totalesMovimientos(inicioCajaActual).egresos, 0);
    expect(movimientosDesde(inicioCajaActual), isEmpty);
  });

  test('los medios se agrupan como en el servidor', () {
    expect(grupoDeMedio('Efectivo'), 'efectivo');
    expect(grupoDeMedio('yape'), 'digital');
    expect(grupoDeMedio('Plin'), 'digital');
    expect(grupoDeMedio('Tarjeta'), 'tarjeta');
    expect(grupoDeMedio('Puntos'), 'tarjeta');
  });

  test(
    'el cierre cuenta ingresos y salidas para calcular la diferencia',
    () async {
      pagos.add(_pago(_efectivo, 100));
      movimientosCaja
        ..add(_mov(TipoMovimiento.ingreso, 20, 'Efectivo'))
        ..add(_mov(TipoMovimiento.egreso, 35, 'Efectivo'));
      // Debería haber 50 de inicial + 100 + 20 - 35 = 135 en efectivo.
      final c = registrarCierreCaja(
        usuarioId: 'u1',
        montoInicial: 50,
        declaradoEfectivo: 135,
        declaradoTarjeta: 0,
        declaradoDigital: 0,
      );
      expect(c.totalIngresos, 20);
      expect(c.totalEgresos, 35);
      expect(c.diferenciaEfectivo, closeTo(0, 0.001));

      // Si en la caja hay 5 menos, la diferencia lo muestra.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      pagos.add(_pago(_efectivo, 10));
      final c2 = registrarCierreCaja(
        usuarioId: 'u1',
        montoInicial: 0,
        declaradoEfectivo: 5,
        declaradoTarjeta: 0,
        declaradoDigital: 0,
      );
      expect(c2.diferenciaEfectivo, closeTo(-5, 0.001));
    },
  );

  test('sin cierres, la caja empieza hoy a las 00:00', () {
    final h = DateTime.now();
    expect(inicioCajaActual, DateTime(h.year, h.month, h.day));
  });
}

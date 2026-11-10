import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:frontend_bijao/data/movimientos_caja_store.dart';
import 'package:frontend_bijao/data/pagos_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/movimiento_caja.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/screens/pagos_screen.dart';
import 'package:frontend_bijao/services/movimiento_caja_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Caja: lo cobrado con descuento de planilla no suma a "Tarjetas / POS": se
// muestra aparte, como "Crédito / Planilla".
const _cajero = Usuario(
  id: 'u1',
  nombre: 'Caja',
  email: 'caja@bijao.pe',
  rol: AppRole.cajero,
);

MovimientoCaja _ingreso(
  String id,
  String medioId,
  String medio,
  double monto,
) => MovimientoCaja(
  id: id,
  tipo: TipoMovimiento.ingreso,
  categoriaId: 'c',
  categoriaNombre: 'Otros ingresos',
  monto: monto,
  medioPagoId: medioId,
  medioPagoNombre: medio,
  fecha: DateTime.now(),
);

void main() {
  setUp(() {
    mediosPago
      ..clear()
      ..addAll(const [
        MedioPago(
          id: 'm1',
          medioPago: 'Efectivo',
          aplicaComision: false,
          grupo: 'efectivo',
        ),
        MedioPago(
          id: 'm2',
          medioPago: 'Visa POS',
          aplicaComision: false,
          grupo: 'tarjeta',
        ),
        MedioPago(
          id: 'm3',
          medioPago: 'Descuento Planilla',
          aplicaComision: false,
          grupo: 'credito',
        ),
      ]);
    SharedPreferences.setMockInitialValues({});
    pagos.clear();
    movimientosCaja.clear();
    MovimientoCajaService.edicionDisponible = false;
  });
  tearDown(() {
    pagos.clear();
    movimientosCaja.clear();
  });

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: CajaScreen(usuario: _cajero)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('con planilla cobrada aparece su propia tarjeta', (tester) async {
    movimientosCaja
      ..add(_ingreso('i1', 'm2', 'Visa POS', 20))
      ..add(_ingreso('i2', 'm3', 'Descuento Planilla', 35));
    await abrir(tester);
    expect(find.text('Tarjetas / POS'), findsWidgets);
    expect(find.text('Crédito / Planilla'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sin planilla no hay tarjeta de crédito', (tester) async {
    movimientosCaja.add(_ingreso('i1', 'm2', 'Visa POS', 20));
    await abrir(tester);
    expect(find.text('Crédito / Planilla'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

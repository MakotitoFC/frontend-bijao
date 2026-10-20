import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/movimientos_caja_store.dart';
import 'package:frontend_bijao/data/pagos_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/movimiento_caja.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/screens/pagos_screen.dart';
import 'package:frontend_bijao/services/movimiento_caja_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cajero = Usuario(
  id: 'u1',
  nombre: 'Caja',
  email: 'caja@bijao.pe',
  rol: AppRole.cajero,
);

MovimientoCaja _mov(
  String id,
  TipoMovimiento tipo,
  double monto, {
  bool anulado = false,
  String? motivo,
}) => MovimientoCaja(
  id: id,
  tipo: tipo,
  categoriaId: 'c',
  categoriaNombre: tipo == TipoMovimiento.egreso
      ? 'Compra de insumos'
      : 'Otros ingresos',
  monto: monto,
  medioPagoId: 'mp1',
  medioPagoNombre: 'Efectivo',
  fecha: DateTime.now(),
  anulado: anulado,
  motivoAnulacion: motivo,
);

// Un botón con ícono (TextButton.icon) es una subclase privada de TextButton.
Finder _boton(String etiqueta) => find.ancestor(
  of: find.text(etiqueta),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    pagos.clear();
    movimientosCaja.clear();
    MovimientoCajaService.edicionDisponible = false;
  });
  tearDown(() {
    pagos.clear();
    movimientosCaja.clear();
    MovimientoCajaService.edicionDisponible = false;
  });

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: CajaScreen(usuario: _cajero)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('muestra el resumen y la lista de ingresos y salidas', (
    tester,
  ) async {
    movimientosCaja
      ..add(_mov('m1', TipoMovimiento.egreso, 35))
      ..add(_mov('m2', TipoMovimiento.ingreso, 20))
      ..add(
        _mov(
          'm3',
          TipoMovimiento.egreso,
          99,
          anulado: true,
          motivo: 'Se digitó dos veces',
        ),
      );
    await abrir(tester);

    expect(find.text('Ingresos y salidas'), findsOneWidget);
    expect(find.text('Por medio de pago'), findsOneWidget);
    expect(find.text('Compra de insumos · Efectivo'), findsNWidgets(2));
    expect(find.text('-S/ 35.00'), findsOneWidget);
    expect(find.text('+S/ 20.00'), findsOneWidget);
    // El anulado se queda en la lista, con su motivo.
    expect(find.text('Anulado: Se digitó dos veces'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('en un celular (360 px) no se desborda', (tester) async {
    movimientosCaja
      ..add(_mov('m1', TipoMovimiento.egreso, 35))
      ..add(
        _mov('m2', TipoMovimiento.egreso, 99, anulado: true, motivo: 'Error'),
      );
    tester.view.physicalSize = const Size(360, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: CajaScreen(usuario: _cajero)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.text('Ingresos y salidas'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Editar y Anular están desactivados hasta que el servidor los tenga',
    (tester) async {
      movimientosCaja.add(_mov('m1', TipoMovimiento.egreso, 35));
      await abrir(tester);

      expect(
        tester.widget<ButtonStyleButton>(_boton('Editar')).onPressed,
        isNull,
      );
      expect(
        tester.widget<ButtonStyleButton>(_boton('Anular')).onPressed,
        isNull,
      );

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('con la edición habilitada se puede anular y queda tachado', (
    tester,
  ) async {
    MovimientoCajaService.edicionDisponible = true;
    movimientosCaja.add(_mov('local-1', TipoMovimiento.egreso, 35));
    await abrir(tester);

    await tester.tap(_boton('Anular'));
    await tester.pumpAndSettle();
    expect(find.text('Anular salida'), findsOneWidget);
    // Sin motivo no deja anular.
    expect(
      tester.widget<ButtonStyleButton>(_boton('Anular').last).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(EditableText), 'Error de digitación');
    await tester.pump();
    await tester.tap(_boton('Anular').last);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Anulado: Error de digitación'), findsOneWidget);
    expect(movimientosCaja.single.anulado, isTrue);
    // Ya no suma ni resta.
    expect(totalesMovimientos(DateTime(2000)).egresos, 0);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets(
    'registrar una salida: pide categoría y monto, y queda en la lista',
    (tester) async {
      await abrir(tester);
      expect(
        find.textContaining('Aún no hay ingresos ni salidas'),
        findsOneWidget,
      );

      await tester.tap(find.text('Salida'));
      await tester.pumpAndSettle();
      expect(find.text('Registrar una salida'), findsOneWidget);
      // Hasta llenar categoría y monto no deja registrar.
      expect(
        tester.widget<ButtonStyleButton>(_boton('Registrar')).onPressed,
        isNull,
      );

      await tester.tap(find.text('Elige para qué fue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gasto operativo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, '12.50');
      await tester.pump();
      expect(
        tester.widget<ButtonStyleButton>(_boton('Registrar')).onPressed,
        isNotNull,
      );

      await tester.tap(_boton('Registrar'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(movimientosCaja.single.tipo, TipoMovimiento.egreso);
      expect(movimientosCaja.single.monto, 12.5);
      expect(find.text('Gasto operativo · Efectivo'), findsOneWidget);
      expect(find.text('-S/ 12.50'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    },
  );
}

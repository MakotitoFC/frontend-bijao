import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/widgets/app_switch.dart';
import 'package:frontend_bijao/widgets/detalle_pedido_panel.dart';

// Pagar: los métodos son cards en cuadrícula, la casilla de efectivo solo sale
// con efectivo y, por montos, lo que pasa de la cuenta es vuelto (no se suma
// dos veces).
final _pedido = Pedido(
  id: '018f0000-0000-7000-8000-000000000001',
  numeroPedido: '1',
  mesaNumero: 2,
  tipoPedido: 'mesa',
  estado: 'pendiente',
  fechaPedido: DateTime(2026, 10, 18, 13),
  usuarioId: 'u1',
);

const _linea = PedidoLine(
  id: 'l1',
  cartaId: 'c1',
  nombrePlato: 'Parrilla familiar',
  cantidad: 1,
  modificadores: [],
  presentacion: null,
  promocion: null,
  comentario: null,
  precioUnitario: 130,
  descuentoAplicado: 0,
  precioTotalLinea: 130,
);

void main() {
  setUp(() {
    mediosPago
      ..clear()
      ..addAll(const [
        MedioPago(id: 'e', medioPago: 'Efectivo', aplicaComision: false),
        MedioPago(id: 'y', medioPago: 'Yape', aplicaComision: false),
        MedioPago(
          id: 't',
          medioPago: 'Tarjeta',
          aplicaComision: true,
          porcentajeComision: 4,
          grupo: 'tarjeta',
        ),
        MedioPago(
          id: 'sm',
          medioPago: 'SERVICIOS MÚLTIPLES',
          aplicaComision: false,
          grupo: 'digital',
        ),
      ]);
  });

  tearDown(() {
    mediosPago.clear();
    pedidos.clear();
    detallesPorPedido.clear();
  });

  Future<void> abrir(
    WidgetTester tester,
    double ancho, {
    double propina = 0,
  }) async {
    tester.view.physicalSize = Size(ancho, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    pedidos
      ..clear()
      ..add(_pedido);
    detallesPorPedido[_pedido.id] = [_linea];
    if (propina > 0) establecerPropinaPedido(_pedido.id, propina);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DetallePedidoPanel(
            pedido: _pedido,
            onCambio: () {},
            esAdmin: false,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Pagar'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  for (final ancho in const [360.0, 500.0, 1000.0]) {
    testWidgets(
      'los métodos son cards en fila, sin desbordes (${ancho.round()} '
      'px)',
      (tester) async {
        await abrir(tester, ancho);
        expect(tester.takeException(), isNull);
        final e = tester.getRect(find.text('Efectivo').first);
        final y = tester.getRect(find.text('Tarjeta').first);
        // Efectivo y Tarjeta comparten fila (no van uno debajo del otro).
        expect((e.center.dy - y.center.dy).abs(), lessThan(8));
        // El nombre largo no se corta con "…".
        expect(find.text('SERVICIOS MÚLTIPLES'), findsOneWidget);
        expect(find.text('+4.0% recargo'), findsOneWidget);
      },
    );
  }

  testWidgets('la casilla de efectivo solo sale cuando el método es efectivo', (
    tester,
  ) async {
    await abrir(tester, 500);
    expect(find.text('Efectivo recibido'), findsOneWidget);
    expect(find.text('Vuelto'), findsOneWidget);
    await tester.tap(find.text('Yape').first);
    await tester.pump();
    expect(find.text('Efectivo recibido'), findsNothing);
    expect(find.text('Vuelto'), findsNothing);
    await tester.tap(find.text('Efectivo').first);
    await tester.pump();
    expect(find.text('Efectivo recibido'), findsOneWidget);
  });

  Future<void> repartir(
    WidgetTester tester,
    String efectivo,
    String yape,
  ) async {
    await tester.ensureVisible(find.text('Por montos'));
    await tester.tap(find.byType(AppSwitch).first);
    await tester.pump();
    await tester.ensureVisible(find.text('Agregar'));
    await tester.tap(find.text('Agregar'));
    await tester.pump();
    Finder campo(String t) => find.byWidgetPredicate(
      (w) => w is EditableText && w.controller.text == t,
    );
    await tester.enterText(campo('130.00'), efectivo);
    await tester.pump();
    await tester.enterText(campo('0.00'), yape);
    await tester.pump();
  }

  testWidgets('por montos: Yape 100 + efectivo 50 en una cuenta de 130 deja '
      'vuelto 20 y se cobra 130', (tester) async {
    await abrir(tester, 500);
    await repartir(tester, '50', '100');
    expect(find.text('Vuelto S/ 20.00'), findsOneWidget);
    // Sin casilla de efectivo aparte: no se cuenta dos veces.
    expect(find.text('Efectivo recibido'), findsNothing);
    expect(find.textContaining('Pagar · S/ 130.00'), findsOneWidget);
    final boton = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.textContaining('Pagar · S/ 130.00'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(boton.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('por montos: lo que sobra sin efectivo para devolver no se '
      'puede cobrar (con la propina apagada)', (tester) async {
    config.propinaHabilitada = false;
    addTearDown(() => config.propinaHabilitada = true);
    await abrir(tester, 500);
    await repartir(tester, '0', '140');
    expect(find.textContaining('Sobra S/ 10.00'), findsOneWidget);
    final boton = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.textContaining('Pagar abono'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets('por montos: el sobrante se puede dejar como propina (no se '
      'suma a la cuenta)', (tester) async {
    addTearDown(() => config.propinaHabilitada = true);
    await abrir(tester, 500);
    await repartir(tester, '50', '100');
    expect(find.text('Dejar como propina'), findsOneWidget);
    await tester.ensureVisible(find.text('Dejar como propina'));
    await tester.tap(find.text('Dejar como propina'));
    await tester.pump();
    // Ya no es vuelto: es propina, y el cliente paga 150 en total.
    expect(find.text('Propina S/ 20.00'), findsOneWidget);
    expect(find.text('Vuelto S/ 20.00'), findsNothing);
    expect(find.textContaining('Pagar · S/ 150.00'), findsOneWidget);
    // En el resumen la cuenta sigue en 130 y la propina aparte.
    expect(find.text('Propina (sin recargo)'), findsOneWidget);
    await tester.tap(find.text('Dar vuelto'));
    await tester.pump();
    expect(find.text('Vuelto S/ 20.00'), findsOneWidget);
    expect(find.textContaining('Pagar · S/ 130.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un medio en efectivo: el sobrante como propina deja el vuelto '
      'en cero', (tester) async {
    addTearDown(() => config.propinaHabilitada = true);
    await abrir(tester, 500);
    await tester.enterText(
      find
          .byWidgetPredicate(
            (w) => w is EditableText && w.controller.text.isEmpty,
          )
          .first,
      '150',
    );
    await tester.pump();
    expect(find.text('El cliente entrega S/ 20.00 de más'), findsOneWidget);
    await tester.tap(find.text('Dejar como propina'));
    await tester.pump();
    expect(find.textContaining('Pagar · S/ 150.00'), findsOneWidget);
    expect(find.text('S/ 0.00'), findsWidgets);
  });

  testWidgets('con la propina apagada no se ofrece dejar el vuelto como '
      'propina', (tester) async {
    config.propinaHabilitada = false;
    addTearDown(() => config.propinaHabilitada = true);
    await abrir(tester, 500);
    await repartir(tester, '50', '100');
    expect(find.text('Dejar como propina'), findsNothing);
    expect(find.text('Vuelto S/ 20.00'), findsOneWidget);
  });

  testWidgets('por montos: lo que sobra sin efectivo para devolver no se '
      'puede cobrar (con la propina apagada)', (tester) async {
    config.propinaHabilitada = false;
    addTearDown(() => config.propinaHabilitada = true);
    await abrir(tester, 500);
    await repartir(tester, '0', '140');
    expect(find.textContaining('Sobra S/ 10.00'), findsOneWidget);
    final boton = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.textContaining('Pagar abono'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets('por montos: lo que sobra sin efectivo es propina, no un pago '
      'adicional', (tester) async {
    addTearDown(() => config.propinaHabilitada = true);
    await abrir(tester, 500);
    await repartir(tester, '0', '140');
    // Cuenta 130, filas 140: los 10 de más se toman como propina.
    expect(find.text('Propina S/ 10.00'), findsOneWidget);
    expect(find.textContaining('Pagar · S/ 140.00'), findsOneWidget);
    expect(find.text('Propina (sin recargo)'), findsOneWidget);
    final boton = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.textContaining('Pagar · S/ 140.00'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(boton.onPressed, isNotNull);
  });

  testWidgets('por montos: la propina escrita que ya viene en las filas no se '
      'suma otra vez', (tester) async {
    addTearDown(() => config.propinaHabilitada = true);
    await abrir(tester, 500);
    await repartir(tester, '0', '140');
    await tester.ensureVisible(find.byType(AppSwitch).at(1));
    await tester.tap(find.byType(AppSwitch).at(1));
    await tester.pump();
    // El campo de la propina es el primero vacío debajo del título "Propina".
    final titulo = tester.getRect(find.text('Propina').first).top;
    final campos =
        find
            .byWidgetPredicate(
              (w) => w is EditableText && w.controller.text.isEmpty,
            )
            .evaluate()
            .map((e) => e.widget as EditableText)
            .where((w) => tester.getRect(find.byWidget(w)).top > titulo)
            .toList()
          ..sort(
            (a, b) => tester
                .getRect(find.byWidget(a))
                .top
                .compareTo(tester.getRect(find.byWidget(b)).top),
          );
    await tester.enterText(find.byWidget(campos.first), '10');
    await tester.pump();
    // El total sigue en 140 (130 de cuenta + 10 de propina), no 150.
    expect(find.textContaining('Pagar · S/ 140.00'), findsOneWidget);
    expect(find.textContaining('S/ 150.00'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pagar: la propina anotada al registrar aparece sola, sin '
      'interruptor', (tester) async {
    addTearDown(() => config.propinaHabilitada = true);
    await abrir(tester, 500, propina: 4);
    expect(find.text('4.00'), findsWidgets);
    expect(find.text('Propina'), findsOneWidget);
    // Cuenta 130 + propina 4.
    expect(find.textContaining('Pagar · S/ 134.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

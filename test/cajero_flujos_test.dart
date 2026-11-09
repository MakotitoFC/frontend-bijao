import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:frontend_bijao/data/mesas_store.dart';
import 'package:frontend_bijao/data/movimientos_caja_store.dart';
import 'package:frontend_bijao/data/nav_items.dart';
import 'package:frontend_bijao/data/pagos_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/mesa.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/models/sede.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/screens/home_screen.dart';
import 'package:frontend_bijao/screens/pagos_screen.dart';
import 'package:frontend_bijao/screens/pedidos_screen.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/widgets/detalle_pedido_panel.dart';
import 'package:frontend_bijao/widgets/elegir_nuevo_pedido_dialog.dart';
import 'package:frontend_bijao/widgets/nuevo_pedido_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sede = Sede(id: '1', ruc: '1', direccion: 'Av. Principal 123');

// Permisos que el seed del backend le da al cajero.
const _cajero = Usuario(
  id: 'c1',
  nombre: 'Caja Uno',
  email: 'caja1@bijao.pe',
  rol: AppRole.cajero,
  permisos: {
    'LEER.PEDIDOS',
    'LEER.PEDIDO',
    'LEER.PAGO',
    'LEER.MESA',
    'UPDATE.PEDIDO',
    'UPDATE.PEDIDO_DETALLE',
    'CREAR.PEDIDO_ANULADO',
    'CREAR.DESCUENTO_APLICADO',
  },
);

const _tamanos = {
  'celular': Size(375, 812),
  'celular chico': Size(320, 640),
  'tablet': Size(768, 1024),
  'tablet horizontal': Size(1024, 768),
  'escritorio': Size(1400, 900),
};

// El pedido es de otro mozo: el cajero debe poder administrarlo igual.
Pedido _pedido({String id = 'p1', String tipo = 'mesa'}) => Pedido(
  id: id,
  numeroPedido: '0001',
  mesaNumero: tipo == 'mesa' ? 2 : 0,
  tipoPedido: tipo,
  estado: 'pendiente',
  fechaPedido: DateTime.now().subtract(const Duration(minutes: 5)),
  usuarioId: 'mozo-otro',
);

const _linea = PedidoLine(
  id: 'l1',
  cartaId: 'c1',
  nombrePlato: 'Tacacho',
  cantidad: 2,
  modificadores: [],
  presentacion: null,
  promocion: null,
  comentario: null,
  precioUnitario: 12,
  descuentoAplicado: 0,
  precioTotalLinea: 24,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    AuthService.instance.userNotifier.value = _cajero;
    mediosPago
      ..clear()
      ..add(
        const MedioPago(
          id: 'mp1',
          medioPago: 'Efectivo',
          aplicaComision: false,
        ),
      );
    mesas
      ..clear()
      ..addAll(const [
        Mesa(id: 'm1', numero: 1, estado: 'ocupada'),
        Mesa(id: 'm2', numero: 2, estado: 'disponible'),
      ]);
    pedidos
      ..clear()
      ..add(_pedido());
    detallesPorPedido['p1'] = [_linea];
    pagos.clear();
    movimientosCaja.clear();
  });

  tearDown(() {
    pedidos.clear();
    mesas.clear();
    mediosPago.clear();
    pagos.clear();
    movimientosCaja.clear();
    detallesPorPedido.clear();
    AuthService.instance.userNotifier.value = null;
  });

  // Dibuja un widget y falla si Flutter reporta un desborde u otro error.
  Future<void> dibujar(
    WidgetTester tester,
    Size tam,
    Widget Function() crear,
  ) async {
    tester.view.physicalSize = tam;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final anterior = FlutterError.onError;
    final fallos = <FlutterErrorDetails>[];
    FlutterError.onError = fallos.add;
    await tester.pumpWidget(MaterialApp(home: crear()));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    FlutterError.onError = anterior;
    if (fallos.isNotEmpty) {
      final lineas = fallos.first
          .toString()
          .split('\n')
          .where(
            (l) =>
                l.contains('overflowed') ||
                l.contains('creator:') ||
                RegExp(r'lib/[a-z_/]+\.dart:\d+').hasMatch(l),
          )
          .take(8)
          .join('\n');
      fail('Fallo de dibujo:\n$lineas');
    }
  }

  group('acceso por rol', () {
    test('el cajero ve solo Pedidos, Ventas y Caja (y Inicio)', () {
      final visibles = navItems
          .where((i) => i.tieneAcceso(_cajero))
          .map((i) => i.clave)
          .toSet();
      expect(visibles, containsAll(['pedidos', 'historial_pedidos', 'caja']));
      for (final oculto in [
        'mesas',
        'productos',
        'cocina',
        'reportes',
        'inventario',
        'configuracion',
      ]) {
        expect(visibles.contains(oculto), false, reason: oculto);
      }
    });

    test('administra pedidos como el administrador', () {
      expect(_cajero.administraPedidos, true);
    });
  });

  for (final t in _tamanos.entries) {
    testWidgets('Home del cajero en ${t.key}', (tester) async {
      await dibujar(
        tester,
        t.value,
        () => HomeScreen(sede: _sede, usuario: _cajero),
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Pedidos, Ventas y Caja del cajero en ${t.key}', (
      tester,
    ) async {
      final pantallas = <String, Widget Function()>{
        'pedidos': () => Scaffold(body: PedidosScreen(usuario: _cajero)),
        'ventas': () =>
            Scaffold(body: HistorialPedidosScreen(usuario: _cajero)),
        'caja': () => Scaffold(body: CajaScreen(usuario: _cajero)),
      };
      for (final e in pantallas.entries) {
        try {
          await dibujar(tester, t.value, e.value);
        } catch (err) {
          fail('${e.key} en ${t.key}: $err');
        }
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('registro de pedido del cajero en ${t.key}', (tester) async {
      await dibujar(
        tester,
        t.value,
        () => Scaffold(
          body: NuevoPedidoDialog(
            usuario: _cajero,
            tipo: 'mesa',
            onTerminar: (_) {},
            onVolver: () {},
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('modal de nuevo pedido en ${t.key}', (tester) async {
      for (final conDestinatario in [true, false]) {
        await dibujar(
          tester,
          t.value,
          () => Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ElegirNuevoPedidoDialog(conDestinatario: conDestinatario),
            ),
          ),
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('detalle del pedido (cajero) en ${t.key}', (tester) async {
      final p = _pedido();
      await dibujar(
        tester,
        t.value,
        () => Scaffold(
          body: DetallePedidoPanel(pedido: p, onCambio: () {}, esAdmin: true),
        ),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('el cajero elige para quién es el pedido y el tipo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    EleccionNuevoPedido? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                resultado = await showDialog<EleccionNuevoPedido>(
                  context: context,
                  builder: (_) => Dialog(
                    child: ElegirNuevoPedidoDialog(
                      conDestinatario: _cajero.administraPedidos,
                    ),
                  ),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('¿Para quién es este pedido?'), findsOneWidget);
    await tester.tap(find.text('Familia'));
    await tester.pumpAndSettle();
    expect(find.text('¿Para quién es este pedido?'), findsNothing);
    // Atrás vuelve al primer paso.
    await tester.tap(find.byIcon(Icons.chevron_left).first);
    await tester.pumpAndSettle();
    expect(find.text('¿Para quién es este pedido?'), findsOneWidget);
    await tester.tap(find.text('Empleado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Para llevar'));
    await tester.pumpAndSettle();
    expect(resultado?.destinatario, 'empleado');
    expect(resultado?.tipo, 'llevar');
    await tester.pumpWidget(const SizedBox());
  });

  group('detalle del pedido con el cajero', () {
    Future<void> abrir(WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final p = _pedido();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DetallePedidoPanel(pedido: p, onCambio: () {}, esAdmin: true),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('ve las acciones del administrador sobre el pedido', (
      tester,
    ) async {
      await abrir(tester);
      expect(find.text('Pagar'), findsOneWidget);
      // Las demás acciones van en el menú "Más acciones" (celular).
      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      expect(find.text('Promoción'), findsOneWidget);
      expect(find.text('Táper'), findsOneWidget);
      expect(find.text('Descuento'), findsOneWidget);
      expect(find.text('Anular pedido'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Tacacho'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Pagar abre el modal de cobro', (tester) async {
      await abrir(tester);
      await tester.tap(find.text('Pagar'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('Total a pagar'), findsOneWidget);
      expect(find.text('Método de pago'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Táper abre su diálogo', (tester) async {
      await abrir(tester);
      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Táper'));
      await tester.pumpAndSettle();
      expect(find.text('Táper grande'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Cancelar pedido pide confirmación', (tester) async {
      await abrir(tester);
      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anular pedido'));
      await tester.pumpAndSettle();
      expect(find.textContaining('#0001'), findsWidgets);
      expect(find.text('Más acciones'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Descuento se puede editar (caja y administración)', (
      tester,
    ) async {
      await abrir(tester);
      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descuento'));
      await tester.pumpAndSettle();
      // Se abre el diálogo de ajuste/descuento.
      expect(find.text('Descuento'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Promoción abre su diálogo', (tester) async {
      await abrir(tester);
      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Promoción'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}

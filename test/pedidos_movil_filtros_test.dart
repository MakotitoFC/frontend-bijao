import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/screens/pedidos_screen.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// La cola de Pedidos en celular, con el tema real de la app y varios tamaños de
// pantalla y de letra: sin errores de layout, con las pestañas de tipo, los dos
// selectores que abren su lista, las tarjetas compactas y "Nuevo" flotante.
const _admin = Usuario(
  id: 'a1',
  nombre: 'Admin',
  email: 'a@a',
  rol: AppRole.administrador,
  permisos: {'LEER.PEDIDOS', 'LEER.PEDIDO', 'LEER.PAGO', 'LEER.MESA'},
);

PedidoLine _linea(int i) => PedidoLine(
  id: 'l$i',
  cartaId: 'c$i',
  nombrePlato: 'Plato $i',
  cantidad: 1,
  modificadores: const [],
  presentacion: null,
  promocion: null,
  comentario: null,
  precioUnitario: 10,
  descuentoAplicado: 0,
  precioTotalLinea: 10,
);

Pedido _pedido(String id, String num, String tipo, int mesa) => Pedido(
  id: id,
  numeroPedido: num,
  mesaNumero: mesa,
  tipoPedido: tipo,
  estado: 'pendiente',
  fechaPedido: DateTime.now().subtract(const Duration(minutes: 5)),
  usuarioId: 'u1',
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    AuthService.instance.userNotifier.value = _admin;
    mediosPago
      ..clear()
      ..add(
        const MedioPago(
          id: 'mp1',
          medioPago: 'Efectivo',
          aplicaComision: false,
        ),
      );
    pedidos
      ..clear()
      ..addAll([
        _pedido('p1', '0007', 'mesa', 16),
        _pedido('p2', '0008', 'mesa', 3),
        _pedido('p3', '0009', 'delivery', 0),
      ]);
    for (final p in pedidos) {
      detallesPorPedido[p.id] = [for (var i = 0; i < 3; i++) _linea(i)];
    }
  });

  tearDown(() {
    pedidos.clear();
    mediosPago.clear();
    detallesPorPedido.clear();
    AuthService.instance.userNotifier.value = null;
  });

  const tamanos = {
    'celular chico': Size(320, 568),
    'celular': Size(375, 667),
    'celular alto': Size(375, 812),
  };

  for (final e in tamanos.entries) {
    for (final letra in [1.0, 1.4]) {
      testWidgets('Pedidos en ${e.key} con letra al ${(letra * 100).round()} %', (
        tester,
      ) async {
        tester.view.physicalSize = e.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(letra)),
              child: child!,
            ),
            home: Scaffold(body: PedidosScreen(usuario: _admin)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);

        // Pestañas de tipo con cantidad, "Nuevo" flotante y las tarjetas.
        expect(find.text('Todos'), findsOneWidget);
        expect(find.text('Mesa'), findsOneWidget);
        expect(find.text('Nuevo'), findsOneWidget);
        // "Nuevo" es el botón estándar del sistema (36 px) y no flota sobre la
        // lista.
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(
          tester.getSize(find.widgetWithText(FilledButton, 'Nuevo')).height,
          36,
        );
        // El texto del selector de pagos se adapta (versión corta o más chico):
        // nunca queda cortado con "…".
        expect(
          find.text('Todos los pagos').evaluate().length +
              find.text('Pagos').evaluate().length,
          1,
        );
        expect(find.textContaining('#0007'), findsOneWidget);

        // Alineación: el buscador, las pestañas, los selectores y las tarjetas
        // empiezan y terminan en los mismos bordes.
        final izqSelector = tester
            .getTopLeft(
              find.byTooltip('Pedidos de clientes, empleados o familia'),
            )
            .dx;
        final izqBuscador = tester.getTopLeft(find.byType(TextField).first).dx;
        final izqTarjeta = tester.getTopLeft(find.textContaining('#0007')).dx;
        expect((izqSelector - izqBuscador).abs(), lessThan(2));
        expect(izqTarjeta - izqBuscador, lessThan(32));

        // El número de pedido se busca con o sin "#".
        await tester.enterText(find.byType(TextField).first, '#0008');
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('#0008'), findsWidgets);
        expect(find.textContaining('#0007'), findsNothing);
        await tester.enterText(find.byType(TextField).first, '9');
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('#0009'), findsWidgets);
        expect(find.textContaining('#0008'), findsNothing);
        await tester.enterText(find.byType(TextField).first, '');
        await tester.pump(const Duration(milliseconds: 300));

        // El selector de "para quién" abre una lista (no botones sueltos).
        await tester.tap(
          find.byTooltip('Pedidos de clientes, empleados o familia'),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.textContaining('Empleados ('), findsOneWidget);
        await tester.tap(find.textContaining('Empleados ('));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        // Con algo elegido el selector se pinta de verde y muestra su "x".
        expect(find.text('Empleados'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsWidgets);
        expect(find.textContaining('#0007'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

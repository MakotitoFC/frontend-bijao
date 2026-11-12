import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/screens/pagos_screen.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// El historial de ventas muestra un día a la vez: con las flechas se va al día
// anterior y se ven sus pedidos; un fallo de red no vacía la tabla.
const _admin = Usuario(
  id: 'a1',
  nombre: 'Admin',
  email: 'a@a',
  rol: AppRole.administrador,
  permisos: {'LEER.PEDIDOS', 'LEER.PEDIDO', 'LEER.PAGO', 'LEER.MESA'},
);

Pedido _pedido(String id, String num, DateTime fecha) => Pedido(
  id: id,
  numeroPedido: num,
  mesaNumero: 0,
  tipoPedido: 'llevar',
  estado: 'pendiente',
  fechaPedido: fecha,
  usuarioId: 'u1',
  mozoNombre: 'Mozo$num',
);

const _linea = PedidoLine(
  id: 'l1',
  cartaId: 'c1',
  nombrePlato: 'Plato',
  cantidad: 1,
  modificadores: [],
  presentacion: null,
  promocion: null,
  comentario: null,
  precioUnitario: 10,
  descuentoAplicado: 0,
  precioTotalLinea: 10,
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
    final ahora = DateTime.now();
    final ayer = DateTime(ahora.year, ahora.month, ahora.day - 1, 13);
    pedidos
      ..clear()
      ..addAll([
        _pedido(
          'p-hoy',
          '0007',
          DateTime(ahora.year, ahora.month, ahora.day, 12),
        ),
        _pedido('p-ayer', '0008', ayer),
      ]);
    for (final p in pedidos) {
      detallesPorPedido[p.id] = [_linea];
    }
  });

  tearDown(() {
    pedidos.clear();
    mediosPago.clear();
    detallesPorPedido.clear();
    AuthService.instance.userNotifier.value = null;
  });

  testWidgets('con las flechas se ven los pedidos del día anterior', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: HistorialPedidosScreen(usuario: _admin)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Mozo0007'), findsWidgets);
    expect(find.textContaining('Mozo0008'), findsNothing);

    await tester.tap(find.byTooltip('Día anterior'));
    await tester.pump(const Duration(milliseconds: 400));
    // Aunque el servidor no responda en la prueba, la tabla no se vacía y
    // sale el aviso del fallo.
    expect(find.textContaining('Mozo0008'), findsWidgets);
    expect(find.textContaining('Mozo0007'), findsNothing);

    await tester.tap(find.byTooltip('Día siguiente'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Mozo0007'), findsWidgets);
    expect(find.textContaining('Mozo0008'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

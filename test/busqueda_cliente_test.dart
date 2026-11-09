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
import 'package:frontend_bijao/screens/pedidos_screen.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/utils/whatsapp_cuenta.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Los buscadores de Pedidos y Ventas encuentran por nombre del cliente y por
// celular, y todos dicen solo "Buscar..." (en celular, tablet y escritorio).
const _admin = Usuario(
  id: 'a1',
  nombre: 'Admin',
  email: 'a@a',
  rol: AppRole.administrador,
  permisos: {'LEER.PEDIDOS', 'LEER.PEDIDO', 'LEER.PAGO', 'LEER.MESA'},
);

Pedido _pedido(String id, String num, String nombre, String celular) => Pedido(
  id: id,
  numeroPedido: num,
  mesaNumero: 0,
  tipoPedido: 'llevar',
  estado: 'pendiente',
  fechaPedido: DateTime.now().subtract(const Duration(minutes: 5)),
  usuarioId: 'u1',
  clienteNombre: nombre,
  clienteCelular: celular,
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
    pedidos
      ..clear()
      ..addAll([
        _pedido('p1', '0007', 'Carlos Ruiz', '987 654 321'),
        _pedido('p2', '0008', 'Ana Torres', '912345678'),
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

  Future<void> buscar(WidgetTester tester, String texto) async {
    await tester.enterText(find.byType(TextField).first, texto);
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final tam in const [Size(375, 812), Size(768, 1024), Size(1400, 900)]) {
    testWidgets('Pedidos: busca por nombre y celular, placeholder "Buscar..." '
        '(${tam.width.round()} px)', (tester) async {
      tester.view.physicalSize = tam;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: PedidosScreen(usuario: _admin)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Buscar...'), findsWidgets);
      expect(find.textContaining('Buscar mesa'), findsNothing);
      expect(find.textContaining('0007'), findsWidgets);
      expect(find.textContaining('0008'), findsWidgets);

      await buscar(tester, 'carlos');
      expect(find.textContaining('0007'), findsWidgets);
      expect(find.textContaining('0008'), findsNothing);

      // El celular se encuentra aunque esté escrito con espacios.
      await buscar(tester, '654321');
      expect(find.textContaining('0007'), findsWidgets);
      expect(find.textContaining('0008'), findsNothing);

      await buscar(tester, '912345');
      expect(find.textContaining('0008'), findsWidgets);
      expect(find.textContaining('0007'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Ventas: busca por nombre y celular', (tester) async {
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
    expect(find.text('Buscar...'), findsWidgets);
    expect(find.text('Sin pedidos'), findsNothing);
    await buscar(tester, 'carlos');
    expect(find.text('Sin pedidos'), findsNothing);
    await buscar(tester, '654 321');
    expect(find.text('Sin pedidos'), findsNothing);
    await buscar(tester, '999888');
    expect(find.text('Sin pedidos'), findsOneWidget);
    await buscar(tester, 'nadie');
    expect(find.text('Sin pedidos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('el WhatsApp saluda con el nombre del cliente', () {
    expect(nombreClienteWhatsapp('Carlos Ruiz', 'OTRO'), 'Carlos Ruiz');
    expect(nombreClienteWhatsapp('', 'LUCIA PEREZ'), 'LUCIA PEREZ');
    expect(nombreClienteWhatsapp(null, 'CLIENTES VARIOS'), '');
    expect(nombreClienteWhatsapp(null, null), '');
  });
}

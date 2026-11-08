import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/widgets/detalle_pedido_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

// El detalle del pedido en celular, con el tema real de la app (que limita el
// alto de los botones) y en varios tamaños de pantalla y de letra: sin errores
// de layout, con el total y los botones siempre a la vista y con la lista de
// productos con casi todo el alto.
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

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    AuthService.instance.userNotifier.value = const Usuario(
      id: 'a1',
      nombre: 'Admin',
      email: 'a@a',
      rol: AppRole.administrador,
      permisos: {},
    );
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
      ..add(
        Pedido(
          id: 'p1',
          numeroPedido: '0007',
          mesaNumero: 1,
          tipoPedido: 'mesa',
          estado: 'pendiente',
          fechaPedido: DateTime.now().subtract(const Duration(minutes: 5)),
          usuarioId: 'u1',
        ),
      );
    detallesPorPedido['p1'] = [for (var i = 0; i < 6; i++) _linea(i)];
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
      testWidgets(
        'detalle en ${e.key} con letra al ${(letra * 100).round()} %',
        (tester) async {
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
              home: Scaffold(
                body: DetallePedidoPanel(
                  pedido: pedidos.first,
                  onCambio: () {},
                  onVolver: () {},
                  esAdmin: true,
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);

          // Abajo y a la vista: Servido y Pagar, con el total en una línea.
          for (final texto in ['Servido', 'Pagar']) {
            final b = tester.getRect(find.text(texto).last).bottom;
            expect(b, lessThanOrEqualTo(e.value.height), reason: texto);
          }
          expect(find.textContaining('Total · 6 productos'), findsOneWidget);
          expect(find.text('S/ 60.00'), findsWidgets);

          // El detalle de totales solo aparece al tocar el total.
          expect(find.text('Subtotal'), findsNothing);
          await tester.tap(find.textContaining('Total · 6 productos'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Subtotal'), findsOneWidget);
          await tester.tap(find.textContaining('Total · 6 productos'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Subtotal'), findsNothing);

          // El menú "Más acciones" trae el resto, con Anular al final (mozo y
          // mesa o entrega solo salen con un pedido del servidor).
          await tester.tap(find.byTooltip('Más acciones'));
          await tester.pumpAndSettle();
          for (final t in [
            'Imprimir cuenta',
            'Promoción',
            'Táper',
            'Descuento',
            'Anular pedido',
          ]) {
            expect(find.text(t), findsOneWidget, reason: t);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}

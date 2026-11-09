import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/cartas_store.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:frontend_bijao/data/mesas_store.dart';
import 'package:frontend_bijao/data/mesas_por_liberar_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/mesa.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/widgets/agregar_producto_dialog.dart';
import 'package:frontend_bijao/widgets/anulacion_dialog.dart';
import 'package:frontend_bijao/widgets/apertura_diaria_dialog.dart';
import 'package:frontend_bijao/widgets/cambiar_entrega_dialog.dart';
import 'package:frontend_bijao/widgets/cambiar_pin_dialog.dart';
import 'package:frontend_bijao/widgets/campana_notificaciones.dart';
import 'package:frontend_bijao/widgets/cumpleanos_dialog.dart';
import 'package:frontend_bijao/widgets/descuento_dialog.dart';
import 'package:frontend_bijao/widgets/elegir_nuevo_pedido_dialog.dart';
import 'package:frontend_bijao/widgets/movimiento_caja_dialog.dart';
import 'package:frontend_bijao/widgets/nuevo_pedido_dialog.dart';
import 'package:frontend_bijao/models/movimiento_caja.dart';
import 'package:frontend_bijao/widgets/pago_compartido_dialog.dart';
import 'package:frontend_bijao/widgets/pago_dialogs.dart';
import 'package:frontend_bijao/widgets/plato_libre_dialog.dart';
import 'package:frontend_bijao/widgets/promocion_nueva_dialog.dart';
import 'package:frontend_bijao/widgets/promocion_pedido_dialogs.dart';
import 'package:frontend_bijao/widgets/propina_dialog.dart';
import 'package:frontend_bijao/widgets/server_connection_dialog.dart';
import 'package:frontend_bijao/widgets/stock_base_dialog.dart';
import 'package:frontend_bijao/widgets/traspaso_dialogs.dart';
import 'package:frontend_bijao/widgets/tupper_dialog.dart';
import 'package:frontend_bijao/widgets/whatsapp_cuenta_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Modales en celular: se dibujan en los tamaños de teléfono más comunes y
// fallan si algo se desborda (texto o botones que no caben).

const _tamanos = {
  'celular (375)': Size(375, 812),
  'celular (360)': Size(360, 740),
  'celular chico (320)': Size(320, 640),
};

Pedido _pedido() => Pedido(
  id: 'p1',
  numeroPedido: '0012',
  mesaNumero: 6,
  tipoPedido: 'mesa',
  estado: 'servido',
  fechaPedido: DateTime.now().subtract(const Duration(minutes: 20)),
  usuarioId: 'u1',
  clienteNombre: 'María del Carmen Fernández',
);

const _linea = PedidoLine(
  id: 'l1',
  cartaId: 'c1',
  nombrePlato: 'Tacacho con cecina y chorizo regional',
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
    AuthService.instance.userNotifier.value = const Usuario(
      id: 'u1',
      nombre: 'Administrador General',
      email: 'a@a',
      rol: AppRole.administrador,
    );
    mediosPago
      ..clear()
      ..addAll(const [
        MedioPago(id: 'mp1', medioPago: 'Efectivo', aplicaComision: false),
        MedioPago(
          id: 'mp2',
          medioPago: 'Tarjeta Visa / Mastercard',
          aplicaComision: true,
          porcentajeComision: 4.5,
        ),
        MedioPago(id: 'mp3', medioPago: 'Yape Joel', aplicaComision: false),
      ]);
    mesas
      ..clear()
      ..addAll(const [
        Mesa(id: 'm1', numero: 1, estado: 'ocupada'),
        Mesa(id: 'm6', numero: 6, estado: 'ocupada'),
      ]);
    pedidos
      ..clear()
      ..add(_pedido());
    detallesPorPedido['p1'] = [_linea];
    cartasNotifier.value = [
      for (var i = 1; i <= 6; i++)
        CartaItem(
          id: 'c$i',
          nombrePlato: i.isEven
              ? 'Tacacho con cecina y chorizo regional $i'
              : 'Agua $i',
          descripcion: '',
          categoriaId: 'k',
          precioCliente: 10.0 * i,
          stock: 10,
        ),
    ];
    fijarMesasPorLiberar('u1', [mesas.first, mesas.last]);
  });

  tearDown(() {
    pedidos.clear();
    mesas.clear();
    mediosPago.clear();
    detallesPorPedido.clear();
    limpiarMesasPorLiberar();
    AuthService.instance.userNotifier.value = null;
  });

  // Los modales que se pueden armar con datos simples.
  final modales = <String, Widget Function()>{
    'Pagar': () => PagarPedidoDialog(
      pedido: _pedido(),
      titulo: 'Mesa 6',
      permiteVolver: true,
    ),
    'Pago compartido': () =>
        PagoCompartidoDialog(pedido: _pedido(), titulo: 'Mesa 6'),
    'Notificaciones': () => const PanelNotificaciones(),
    'Nuevo pedido (admin)': () =>
        const ElegirNuevoPedidoDialog(conDestinatario: true),
    'Nuevo pedido (mozo)': () =>
        const ElegirNuevoPedidoDialog(conDestinatario: false),
    'Promociones disponibles': () =>
        const PromocionesDisponiblesDialog(conCumpleanos: true),
    'Cumpleaños': () => const CumpleanosDialog(),
    'Agregar producto': () =>
        AgregarProductoDialog(pedido: _pedido(), esAdmin: true),
    'Plato rápido': () => const PlatoLibreDialog(),
    'Apertura del día': () => const AperturaDiariaDialog(),
    'Cantidades base': () => const StockBaseDialog(),
    'Descuento': () => const DescuentoDialog(base: 120),
    'Propina': () => const PropinaDialog(),
    'Táper': () => const TupperDialog(),
    'Cambiar entrega': () => CambiarEntregaDialog(pedido: _pedido()),
    'Traspasar pedido': () => TraspasarPedidoDialog(pedido: _pedido()),
    'WhatsApp': () => const WhatsappCuentaDialog(),
    'Anular pedido': () => const AnulacionDialog(
      titulo: 'Anular pedido #0012',
      detalle: 'Tacacho con cecina y chorizo regional',
    ),
    'Cambiar PIN': () => const CambiarPinDialog(),
    'Servidor': () => const ServerConnectionDialog(),
    'Registrar salida': () =>
        const MovimientoCajaDialog(tipo: TipoMovimiento.egreso),
    'Registrar ingreso': () =>
        const MovimientoCajaDialog(tipo: TipoMovimiento.ingreso),
    'Nueva promoción': () => const PromocionNuevaDialog(),
  };

  for (final t in _tamanos.entries) {
    testWidgets('modales sin desbordes en ${t.key}', (tester) async {
      tester.view.physicalSize = t.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final problemas = <String>[];
      for (final e in modales.entries) {
        final anterior = FlutterError.onError;
        final fallos = <FlutterErrorDetails>[];
        FlutterError.onError = fallos.add;
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: e.value(),
                ),
              ),
            ),
          );
          for (var i = 0; i < 3; i++) {
            await tester.pump(const Duration(milliseconds: 250));
          }
        } catch (err) {
          problemas.add('${e.key}: no se pudo dibujar ($err)');
        }
        FlutterError.onError = anterior;
        for (final f in fallos) {
          final texto = f.toString();
          if (!texto.contains('overflowed')) continue;
          final lineas = texto
              .split('\n')
              .where(
                (l) =>
                    l.contains('overflowed') ||
                    RegExp(r'lib/[a-z_/]+\.dart:\d+').hasMatch(l),
              )
              .take(2)
              .join(' | ');
          problemas.add('${e.key}: $lineas');
        }
        await tester.pumpWidget(const SizedBox());
      }
      if (problemas.isNotEmpty) {
        fail('Desbordes en ${t.key}:\n${problemas.toSet().join('\n')}');
      }
    });
  }

  for (final t in _tamanos.entries) {
    testWidgets('armar pedido sin desbordes en ${t.key}', (tester) async {
      tester.view.physicalSize = t.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final anterior = FlutterError.onError;
      final fallos = <FlutterErrorDetails>[];
      FlutterError.onError = fallos.add;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NuevoPedidoDialog(
              usuario: const Usuario(
                id: 'u1',
                nombre: 'ana',
                email: 'a@a',
                rol: AppRole.administrador,
              ),
              tipo: 'llevar',
              onTerminar: (_) {},
              onVolver: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      FlutterError.onError = anterior;
      final desbordes = fallos
          .map((f) => f.toString())
          .where((x) => x.contains('overflowed'))
          .toList();
      expect(desbordes, isEmpty, reason: desbordes.join(' | '));
      // El buscador se ve completo y "Plato rápido" es solo un ícono.
      expect(find.byTooltip('Plato rápido'), findsOneWidget);
      expect(find.text('Plato rápido'), findsNothing);
      final ancho = tester.getSize(find.byType(TextField).first).width;
      expect(ancho, greaterThan(120), reason: 'el buscador no puede colapsar');
      await tester.pumpWidget(const SizedBox());
    });
  }
}

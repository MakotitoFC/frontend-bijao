import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/mesas_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/mesa.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/services/pedido_mozo_service.dart';
import 'package:frontend_bijao/widgets/etiqueta_tipo_pedido.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Simula, con un servidor falso que responde como el backend, el cambio de un
// pedido de mesa a "para llevar" y mira qué se ve en pantalla en cada paso.
const _id = '44444444-4444-4444-8444-444444444444';
const _carta = '11111111-1111-4111-8111-111111111111';
const _mesa = '33333333-3333-4333-8333-333333333333';

Map<String, dynamic> _fila(String id, String entrega) => {
  'id': id,
  'version': 1,
  'tipo_item': 'carta',
  'carta_id': _carta,
  'nombre': 'Plato $id',
  'estado': 'pendiente',
  'cantidad': 1,
  'precio_unitario': 20.0,
  'descuento_fila': 0,
  'total_fila': 20.0,
  'tipo_entrega': entrega,
};

// Detalle como lo arma el backend (GetPedidoMozoDetalle): la entrega del
// pedido sale de si tiene mesa activa o delivery.
Map<String, dynamic> _detalle({
  required bool conMesa,
  required List<String> entregas,
  bool omitirTipoEntrega = false,
}) => {
  'id': _id,
  'version': 2,
  'estado': 'pendiente',
  'tipo': conMesa ? 'normal' : 'llevar',
  if (!omitirTipoEntrega) 'tipo_entrega': conMesa ? 'mesa' : 'llevar',
  'mesa_id': ?(conMesa ? _mesa : null),
  'mesa_numero': ?(conMesa ? 4 : null),
  'usuario_id': 'u-1',
  'mozo_nombre': 'Ana',
  'instante_inicio': '2026-11-03T12:00:00-05:00',
  'costo_delivery': 0,
  'total_descuento': 0,
  'total': 20.0 * entregas.length,
  'descuentos': [],
  'items': [
    for (var i = 0; i < entregas.length; i++) _fila('d-$i', entregas[i]),
  ],
};

void main() {
  HttpServer? servidor;
  late Object Function() respuesta;

  // Los testWidgets bloquean la red (todo da 400): se usa la real, con
  // `runAsync`, contra un servidor falso local.
  Future<void> arrancar(WidgetTester tester) async {
    HttpOverrides.global = null;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      await ApiClient.instance.initialize();
      pedidos.clear();
      detallesPorPedido.clear();
      AuthService.instance.userNotifier.value = const Usuario(
        id: 'u-1',
        nombre: 'Ana',
        email: 'a@a',
        rol: AppRole.administrador,
      );
      mesas
        ..clear()
        ..add(const Mesa(id: _mesa, numero: 4, estado: 'ocupada'));
      servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      ApiClient.instance.setBaseUrl('http://127.0.0.1:${servidor!.port}');
      servidor!.listen((req) async {
        await utf8.decoder.bind(req).join();
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(
              req.method == 'PATCH'
                  ? respuesta()
                  : _detalle(conMesa: true, entregas: ['mesa', 'mesa']),
            ),
          );
        await req.response.close();
      });
      respuesta = () => _detalle(conMesa: true, entregas: ['mesa', 'mesa']);
      // El pedido ya está abierto en una mesa.
      await PedidoMozoService.instance.obtener(_id);
    });
    addTearDown(() async => servidor?.close(force: true));
  }

  Future<String> verEnPantalla(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: EtiquetaTipoPedido(pedido: pedidos.single)),
        ),
      ),
    );
    final t = tester.widget<Text>(
      find.descendant(
        of: find.byType(EtiquetaTipoPedido),
        matching: find.byType(Text),
      ),
    );
    return t.data!;
  }

  testWidgets('antes del cambio se ve la mesa', (tester) async {
    await arrancar(tester);
    expect(await verEnPantalla(tester), 'Mesa 4');
  });

  testWidgets(
    'cambiar TODO el pedido a llevar: se ve "Para llevar" al instante',
    (tester) async {
      await arrancar(tester);
      respuesta = () =>
          _detalle(conMesa: false, entregas: ['llevar', 'llevar']);
      await tester.runAsync(
        () => PedidoMozoService.instance.tipoEntregaPedido(_id, 'llevar'),
      );
      expect(await verEnPantalla(tester), 'Para llevar');
    },
  );

  testWidgets('cambiar solo ALGUNOS platos a llevar: el pedido sigue en mesa', (
    tester,
  ) async {
    await arrancar(tester);
    respuesta = () => _detalle(conMesa: true, entregas: ['llevar', 'mesa']);
    final fila = detallesPorPedido[_id]!.first;
    await tester.runAsync(
      () => PedidoMozoService.instance.tipoEntregaFila(_id, fila, 'llevar'),
    );
    expect(await verEnPantalla(tester), 'Mesa 4');
    final lineas = detallesPorPedido[_id]!;
    expect(lineas.first.tipoEntrega, 'llevar');
    expect(lineas.last.tipoEntrega, 'mesa');
  });

  testWidgets(
    'si la respuesta llega sin tipo_entrega y sin mesa, se ve "Sin mesa"',
    (tester) async {
      await arrancar(tester);
      // Mesa ya liberada, pero el servidor todavía no dice que es para llevar.
      respuesta = () => _detalle(
        conMesa: false,
        entregas: ['llevar', 'llevar'],
        omitirTipoEntrega: true,
      );
      await tester.runAsync(
        () => PedidoMozoService.instance.tipoEntregaPedido(_id, 'llevar'),
      );
      expect(await verEnPantalla(tester), 'Sin mesa');
    },
  );
}

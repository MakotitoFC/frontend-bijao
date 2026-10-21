import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/pagos_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/pago_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pedidoId = '01925b6a-9b1d-7234-a123-abcdef012345';
const _lineaId = '01925b6a-9b1d-7234-a123-abcdef0123aa';
const _medioId = '01925b6a-9b1d-7234-a123-abcdef0123bb';
const _pagoId = '01925b6a-9b1d-7234-a123-abcdef0123cc';

const _tarjeta = MedioPago(
  id: _medioId,
  medioPago: 'Tarjeta',
  aplicaComision: true,
  porcentajeComision: 4,
);

Pedido _pedido() => Pedido(
  id: _pedidoId,
  numeroPedido: '0007',
  mesaNumero: 0,
  tipoPedido: 'llevar',
  estado: 'servido',
  fechaPedido: DateTime(2026, 10, 19, 14, 0),
  usuarioId: 'u1',
);

const _linea = PedidoLine(
  id: _lineaId,
  cartaId: 'c1',
  nombrePlato: 'Ceviche',
  cantidad: 1,
  modificadores: [],
  presentacion: null,
  promocion: null,
  comentario: null,
  precioUnitario: 100,
  descuentoAplicado: 0,
  precioTotalLinea: 100,
  tipoEntrega: 'llevar',
);

Map<String, dynamic> _pagoJson({double abonado = 100, double propina = 0}) => {
  'id': _pagoId,
  'pedido_id': _pedidoId,
  'mesa_numero': 0,
  'medio_pago_id': _medioId,
  'medio_pago_nombre': 'Tarjeta',
  'monto_abonado': abonado,
  'porcentaje_comision': 4,
  'monto_comision': abonado * 0.04,
  'monto_cobrado': abonado * 1.04,
  'propina': propina,
  'fecha_pago': '2026-10-19T19:00:00Z',
  'es_reembolso': false,
  'detalles': [
    {
      'pago_id': _pagoId,
      'pedido_detalle_id': _lineaId,
      'monto_aplicado': abonado,
      'cantidad_pagada': 1,
    },
  ],
};

void main() {
  late HttpServer servidor;
  final peticiones = <String>[];
  final cuerpos = <Map<String, dynamic>>[];
  var fallar = false;
  Object resumen = {};
  Object listaDelDia = [];

  // Iniciar el cliente busca el servidor en la red (tarda): se hace una vez.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    pagos.clear();
    pagoDetalles.clear();
    pedidos
      ..clear()
      ..add(_pedido());
    detallesPorPedido[_pedidoId] = [_linea];
    peticiones.clear();
    cuerpos.clear();
    fallar = false;
    resumen = {};
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    ApiClient.instance.setBaseUrl('http://127.0.0.1:${servidor.port}');
    servidor.listen((req) async {
      final texto = await utf8.decoder.bind(req).join();
      peticiones.add('${req.method} ${req.uri.path}');
      if (texto.isNotEmpty) cuerpos.add(jsonDecode(texto));
      req.response.headers.contentType = ContentType.json;
      if (req.method == 'POST' && fallar) {
        req.response
          ..statusCode = 400
          ..write(
            jsonEncode({'error': 'no se puede cobrar un pedido anulado'}),
          );
      } else if (req.method == 'POST') {
        final cuerpo = cuerpos.isEmpty ? <String, dynamic>{} : cuerpos.last;
        req.response
          ..statusCode = 201
          ..write(
            jsonEncode(
              _pagoJson(
                abonado: (cuerpo['monto_abonado'] as num?)?.toDouble() ?? 100,
                propina: (cuerpo['propina'] as num?)?.toDouble() ?? 0,
              ),
            ),
          );
      } else {
        req.response.write(
          jsonEncode(req.uri.path == '/api/pagos' ? listaDelDia : resumen),
        );
      }
      await req.response.close();
    });
  });

  tearDown(() async {
    await servidor.close(force: true);
    pagos.clear();
    pagoDetalles.clear();
    pedidos.clear();
    detallesPorPedido.clear();
  });

  test(
    'cobrar manda el pago al servidor y guarda lo que él responde',
    () async {
      final pago = await PagoService.instance.registrar(
        pedido: _pedido(),
        medio: _tarjeta,
        montoAbonado: 100,
      );

      expect(peticiones, ['POST /api/pagos']);
      expect(cuerpos.single['pedido_id'], _pedidoId);
      expect(cuerpos.single['medio_pago_id'], _medioId);
      expect(cuerpos.single['monto_abonado'], 100);
      // El recargo no lo manda la app: lo calcula el servidor.
      expect(cuerpos.single.containsKey('monto_recargo'), isFalse);
      expect(cuerpos.single.containsKey('monto_comision'), isFalse);

      // Se guarda con el id y el recargo del servidor.
      expect(pago.id, _pagoId);
      expect(pago.montoComision, 4);
      expect(pago.montoCobrado, 104);
      expect(pagos.single.id, _pagoId);
      // La cuenta queda saldada y el pedido pasa a pagado sin pedirlo otra vez.
      expect(saldoPendienteDePedido(_pedidoId), closeTo(0, 0.001));
      expect(pedidos.single.estado, 'pagado');
      expect(peticiones.where((p) => p.startsWith('PUT')), isEmpty);
    },
  );

  test('si el servidor rechaza el pago, no queda nada cobrado', () async {
    fallar = true;
    await expectLater(
      PagoService.instance.registrar(
        pedido: _pedido(),
        medio: _tarjeta,
        montoAbonado: 100,
      ),
      throwsA(
        predicate(
          (e) => e.toString().contains('no se puede cobrar un pedido anulado'),
        ),
      ),
    );
    expect(pagos, isEmpty);
    expect(pagoDetalles, isEmpty);
    expect(saldoPendienteDePedido(_pedidoId), 100);
    expect(pedidos.single.estado, 'servido');
  });

  test('un pago repetido (mismo id) no se cuenta dos veces', () async {
    await PagoService.instance.registrar(
      pedido: _pedido(),
      medio: _tarjeta,
      montoAbonado: 100,
    );
    aplicarPagoDelServidor(
      pedido: _pedido(),
      medio: _tarjeta,
      json: _pagoJson(),
    );
    expect(pagos, hasLength(1));
    expect(pagoDetalles, hasLength(1));
  });

  test('cargarDePedido reconstruye los pagos desde el servidor', () async {
    // En memoria no hay nada (por ejemplo, tras recargar la página).
    resumen = {
      'pedido_id': _pedidoId,
      'estado_pedido': 'pagado',
      'total_pedido': 100,
      'total_pagado': 100,
      'saldo_pendiente': 0,
      'pagos': [_pagoJson()],
    };
    await PagoService.instance.cargarDePedido(_pedido());

    expect(peticiones, ['GET /api/pedidos/$_pedidoId/pagos']);
    expect(pagos.single.montoCobrado, 104);
    expect(pagos.single.medioPago.medioPago, 'Tarjeta');
    expect(saldoPendienteDePedido(_pedidoId), closeTo(0, 0.001));
    expect(pedidos.single.estado, 'pagado');
  });

  const local = MedioPago(
    id: 'mp1',
    medioPago: 'Efectivo',
    aplicaComision: false,
  );

  test('sin ids del servidor (datos locales) se cobra en memoria', () async {
    final pedidoLocal = Pedido(
      id: 'p1',
      numeroPedido: '0007',
      mesaNumero: 0,
      tipoPedido: 'llevar',
      estado: 'servido',
      fechaPedido: DateTime(2026, 10, 19, 14, 0),
      usuarioId: 'u1',
    );
    detallesPorPedido['p1'] = [_linea];
    addTearDown(() => detallesPorPedido.remove('p1'));
    await PagoService.instance.registrar(
      pedido: pedidoLocal,
      medio: local,
      montoAbonado: 100,
    );
    expect(peticiones, isEmpty); // no hubo llamada
    expect(pagos, hasLength(1));
  });

  test('un pedido del servidor no se cobra con un método que no lo es', () async {
    await expectLater(
      PagoService.instance.registrar(
        pedido: _pedido(),
        medio: local,
        montoAbonado: 100,
      ),
      throwsA(
        predicate(
          (e) => e.toString().contains('no existe en el servidor'),
        ),
      ),
    );
    expect(peticiones, isEmpty);
    expect(pagos, isEmpty); // no queda nada cobrado
  });

  test('la propina y el táper de la app no se abonan a la cuenta', () async {
    // Cuenta de 100 más propina (10) y táper (2) que solo viven en la app.
    detallesPorPedido[_pedidoId] = [
      _linea,
      PedidoLine(
        id: 'propina-1',
        cartaId: cartaIdAjuste,
        nombrePlato: '${ajustePropina}mesero',
        cantidad: 1,
        modificadores: const [],
        presentacion: null,
        promocion: null,
        comentario: null,
        precioUnitario: 10,
        descuentoAplicado: 0,
        precioTotalLinea: 10,
      ),
      PedidoLine(
        id: 'taper-1',
        cartaId: cartaIdAjuste,
        nombrePlato: '${ajusteTupper}Grande',
        cantidad: 1,
        modificadores: const [],
        presentacion: null,
        promocion: null,
        comentario: null,
        precioUnitario: 2,
        descuentoAplicado: 0,
        precioTotalLinea: 2,
      ),
    ];
    expect(saldoCuentaDePedido(_pedidoId), 100);
    expect(propinaPendienteDePedido(_pedidoId), 10);
    expect(taperPendienteDePedido(_pedidoId), 2);
    expect(saldoPendienteDePedido(_pedidoId), 112);

    // El cajero cobra todo lo que muestra el diálogo, pero al servidor solo va
    // la cuenta; la propina viaja en su propio campo.
    await PagoService.instance.registrar(
      pedido: _pedido(),
      medio: _tarjeta,
      montoAbonado: 112,
    );
    expect(cuerpos.single['monto_abonado'], 100);
    expect(cuerpos.single['propina'], 10);

    // Con la cuenta saldada, la propina y el táper quedan cobrados y el pedido
    // se cierra.
    expect(propinaPendienteDePedido(_pedidoId), 0);
    expect(taperPendienteDePedido(_pedidoId), 0);
    expect(saldoPendienteDePedido(_pedidoId), closeTo(0, 0.001));
    expect(pedidos.single.estado, 'pagado');
  });

  test('la propina solo viaja en el primer pago', () async {
    detallesPorPedido[_pedidoId] = [
      _linea,
      PedidoLine(
        id: 'propina-1',
        cartaId: cartaIdAjuste,
        nombrePlato: '${ajustePropina}mesero',
        cantidad: 1,
        modificadores: const [],
        presentacion: null,
        promocion: null,
        comentario: null,
        precioUnitario: 10,
        descuentoAplicado: 0,
        precioTotalLinea: 10,
      ),
    ];
    await PagoService.instance.registrar(
      pedido: _pedido(),
      medio: _tarjeta,
      montoAbonado: 40,
    );
    await PagoService.instance.registrar(
      pedido: _pedido(),
      medio: _tarjeta,
      montoAbonado: 60,
    );
    expect(cuerpos[0]['propina'], 10);
    expect(cuerpos[1]['propina'], 0);
    expect(propinaPendienteDePedido(_pedidoId), 0);
  });

  test(
    'cargarDelDia trae los pagos del día y no duplica los que ya hay',
    () async {
      listaDelDia = [_pagoJson(), _pagoJson(abonado: 50)..['id'] = 'otro-pago'];
      await PagoService.instance.cargarDelDia();

      expect(peticiones.single, startsWith('GET /api/pagos'));
      expect(pagos, hasLength(2));
      final cobrado = pagos.map((p) => p.montoCobrado).toList()..sort();
      expect(cobrado, [52, 104]); // el recargo del 4 % ya viene del servidor
      // Una segunda lectura no repite los que ya estaban.
      await PagoService.instance.cargarDelDia();
      expect(pagos, hasLength(2));
    },
  );
}

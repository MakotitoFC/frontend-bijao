import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/promociones_store.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/models/promocion.dart';
import 'package:frontend_bijao/models/promocion_componente.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/pedido_mozo_mapper.dart';
import 'package:frontend_bijao/services/promocion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _promo = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _comp = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _op1 = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _op2 = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const _carta = '11111111-1111-4111-8111-111111111111';
const _carta2 = '22222222-2222-4222-8222-222222222222';
const _sub = '33333333-3333-4333-8333-333333333333';

void main() {
  test('lee las promociones del backend: componentes, opciones y la incluida', () {
    final r = parsearPromociones([
      {
        'promocion': {
          'id': _promo,
          'nombre': 'Combo del día',
          'porcentaje_descuento': '10.00',
          'se_mantiene_porcentaje': false,
          'fecha_fin': '2026-12-31T23:59:59Z',
          'estado': true,
        },
        'promocion_componentes': [
          {
            'id': _comp,
            'promocion_id': _promo,
            'subcategoria_id': _sub,
            'cantidad': 1,
            'componente_opcion': [
              {'id': _op2, 'componente_id': _comp, 'carta_id': _carta2, 'precio': null, 'estado': true, 'es_fijo': false},
              {'id': _op1, 'componente_id': _comp, 'carta_id': _carta, 'precio': '12.50', 'estado': true, 'es_fijo': true},
            ],
          },
        ],
      },
    ]);
    final p = r.promociones.single;
    expect(p.nombre, 'Combo del día');
    expect(p.porcentajeDescuento, 10);
    expect(p.seMantiene, false);
    expect(p.fechaFin?.year, 2026);
    expect(r.componentes.single.orden, 1);
    // La opción fija queda primera aunque el servidor la devuelva después.
    expect(r.opciones.map((o) => o.id), [_op1, _op2]);
    expect(r.opciones.first.precio, 12.5);
    expect(r.opciones.last.precio, 0);

    reemplazarPromociones(
      nuevas: r.promociones,
      componentes: r.componentes,
      opciones: r.opciones,
    );
    expect(opcionIncluida(_comp)?.id, _op1);
  });

  group('con el servidor', () {
    late HttpServer servidor;
    final pedidos = <({String metodo, String ruta, Map<String, dynamic>? cuerpo})>[];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ApiClient.instance.initialize();
      pedidos.clear();
      reemplazarPromociones(nuevas: [], componentes: [], opciones: []);
      servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      ApiClient.instance.setBaseUrl('http://127.0.0.1:${servidor.port}');
      servidor.listen((req) async {
        final texto = await utf8.decoder.bind(req).join();
        final cuerpo = texto.isEmpty ? null : jsonDecode(texto) as Map<String, dynamic>;
        pedidos.add((metodo: req.method, ruta: req.uri.path, cuerpo: cuerpo));
        // El servidor devuelve lo recibido (con estado por defecto).
        final respuesta = {'estado': true, ...?cuerpo};
        req.response
          ..statusCode = req.method == 'POST' ? 201 : 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(respuesta));
        await req.response.close();
      });
    });

    tearDown(() async => servidor.close(force: true));

    test('crear promoción envía los nombres del backend y fechas en UTC', () async {
      final fin = DateTime(2026, 12, 31, 23, 59, 59);
      await PromocionService.instance.crearPromocion(
        Promocion(
          id: _promo,
          nombre: 'Combo',
          porcentajeDescuento: 15,
          seMantiene: false,
          fechaFin: fin,
        ),
      );
      final enviado = pedidos.single;
      expect(enviado.metodo, 'POST');
      expect(enviado.ruta, '/api/promociones');
      expect(enviado.cuerpo!['se_mantiene_porcentaje'], false);
      expect(enviado.cuerpo!['porcentaje_descuento'], 15);
      expect(enviado.cuerpo!['fecha_fin'], fin.toUtc().toIso8601String());
      expect(enviado.cuerpo!.containsKey('fecha_inicio'), false);
      expect(promociones.single.id, _promo);
    });

    test('la primera opción es la incluida y se puede cambiar', () async {
      await PromocionService.instance.crearComponente(
        const PromocionComponente(id: _comp, promocionId: _promo, subcategoriaId: _sub),
      );
      pedidos.clear();
      await PromocionService.instance.crearOpcion(
        const PromocionOpcion(id: _op1, componenteId: _comp, cartaId: _carta),
      );
      await PromocionService.instance.crearOpcion(
        const PromocionOpcion(id: _op2, componenteId: _comp, cartaId: _carta2, precio: 9),
      );
      expect(pedidos[0].ruta, '/api/promocion-componentes/$_comp/opciones');
      expect(pedidos[0].cuerpo!['es_fijo'], true);
      expect(pedidos[0].cuerpo!.containsKey('precio'), false); // sin precio propio
      expect(pedidos[1].cuerpo!['es_fijo'], false);
      expect(pedidos[1].cuerpo!['precio'], 9);
      expect(opcionIncluida(_comp)?.id, _op1);

      pedidos.clear();
      await PromocionService.instance.hacerIncluidaEnServidor(
        promocionOpciones.firstWhere((o) => o.id == _op2),
      );
      expect(pedidos.map((p) => '${p.metodo} ${p.ruta}').toSet(), {
        'PUT /api/promocion-opciones/$_op1',
        'PUT /api/promocion-opciones/$_op2',
      });
      expect(opcionIncluida(_comp)?.id, _op2);
    });
  });

  test('una promoción en el pedido envía sus componentes elegidos', () {
    const linea = PedidoLine(
      id: 'l',
      cartaId: 'promocion',
      nombrePlato: 'Combo',
      cantidad: 2,
      modificadores: [],
      presentacion: null,
      promocion: Promocion(id: _promo, nombre: 'Combo'),
      comentario: null,
      precioUnitario: 20,
      descuentoAplicado: 0,
      precioTotalLinea: 40,
      componentes: [
        ComponenteElegido(
          componenteId: _comp,
          opcionId: _op1,
          cartaId: _carta,
          cartaVarianteId: _carta2,
          nombre: 'Tacacho',
          precio: 20,
        ),
      ],
    );
    final body = armarPedidoMozo(lineas: [linea]);
    final item = (body['items'] as List).single as Map;
    expect(item['promocion_id'], _promo);
    expect(item['cantidad'], 2);
    final c = (item['componentes'] as List).single as Map;
    expect(c['componente_id'], _comp);
    expect(c['opcion_id'], _op1);
    expect(c['carta_id'], _carta);
    expect(c['carta_variante_id'], _carta2);
    expect(item.containsKey('precio_unitario_libre'), false);
  });
}

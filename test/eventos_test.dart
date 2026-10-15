import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/eventos/evento_sse.dart';
import 'package:frontend_bijao/services/eventos/flujo_io.dart';
import 'package:frontend_bijao/services/eventos_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Stream<List<int>> _trozos(List<String> partes) =>
    Stream.fromIterable(partes.map(utf8.encode));

void main() {
  group('lector de eventos', () {
    test('une los trozos, ignora latidos y separa los eventos', () async {
      final eventos = await leerEventosSse(
        _trozos([
          'event: conexion_estab',
          'lecida\ndata: {"mensaje":"hola"}\n\n',
          ': keepalive 123\n\n',
          'event: PEDIDO_NUEVO\r\n',
          'data: {"id":"p1"}\r\n\r\n',
          'data: sin nombre\n\n',
        ]),
      ).toList();

      expect(eventos.map((e) => e.nombre), [
        'conexion_establecida',
        'PEDIDO_NUEVO',
        'message',
      ]);
      expect(eventos[0].json, {'mensaje': 'hola'});
      expect(eventos[1].json, {'id': 'p1'});
      expect(eventos[2].json, isNull);
      expect(eventos[2].datos, 'sin nombre');
    });

    test('un evento sin terminar no se entrega', () async {
      final eventos = await leerEventosSse(
        _trozos(['event: PEDIDO_NUEVO\ndata: {"id":"p1"}\n']),
      ).toList();
      expect(eventos, isEmpty);
    });
  });

  group('qué se actualiza con cada evento', () {
    test('pedidos, mesas y stock según el evento', () {
      final nuevo = traducirEvento('PEDIDO_NUEVO');
      expect([nuevo.pedidos, nuevo.mesas, nuevo.stock], [true, true, true]);

      final servido = traducirEvento('ITEM_SERVIDO');
      expect([servido.pedidos, servido.mesas, servido.stock], [true, false, false]);

      final liberada = traducirEvento('MESA_LIBERADA');
      expect([liberada.pedidos, liberada.mesas, liberada.stock], [false, true, false]);

      final agotado = traducirEvento('PLATO_AGOTADO');
      expect([agotado.pedidos, agotado.mesas, agotado.stock], [false, false, true]);

      expect(traducirEvento('conexion_establecida').ninguna, true);
      expect(traducirEvento('EVENTO_DESCONOCIDO').ninguna, true);
    });

    test('varios eventos se unen en una sola lectura', () {
      final u = traducirEvento('ITEM_SERVIDO').unir(traducirEvento('PLATO_AGOTADO'));
      expect([u.pedidos, u.mesas, u.stock], [true, false, true]);
    });
  });

  group('con el servidor', () {
    late HttpServer servidor;
    final cabeceras = <String>[];
    final rutas = <String>[];
    late Future<void> Function(HttpResponse) alAbrirFlujo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ApiClient.instance.initialize();
      await ApiClient.instance.setToken('token-de-prueba');
      cabeceras.clear();
      rutas.clear();
      alAbrirFlujo = (r) async {};
      servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      ApiClient.instance.setBaseUrl('http://127.0.0.1:${servidor.port}');
      servidor.listen((req) async {
        rutas.add(req.uri.path);
        if (req.uri.path == '/api/v1/eventos') {
          cabeceras.add(req.headers.value('authorization') ?? '');
          // Como el servidor real: los eventos salen al momento, sin esperar.
          req.response.bufferOutput = false;
          req.response.headers.contentType = ContentType('text', 'event-stream');
          await alAbrirFlujo(req.response);
          return;
        }
        req.response
          ..headers.contentType = ContentType.json
          ..write('[]');
        await req.response.close();
      });
    });

    tearDown(() async {
      EventosService.instance.detener();
      await servidor.close(force: true);
    });

    test('abre el flujo con el token y entrega los eventos', () async {
      alAbrirFlujo = (r) async {
        r.write('event: conexion_establecida\ndata: {"mensaje":"ok"}\n\n');
        await r.flush();
        r.write('event: PEDIDO_NUEVO\ndata: {"id":"p1"}\n\n');
        await r.flush();
        await r.close();
      };
      final url = Uri.parse('${ApiClient.instance.baseUrl}/api/v1/eventos');
      final eventos = await abrirFlujoDeEventos(url: url, token: 'abc').toList();
      expect(eventos.map((e) => e.nombre), ['conexion_establecida', 'PEDIDO_NUEVO']);
      expect(cabeceras.single, 'Bearer abc');
    });

    test('un 401 se informa con su código', () async {
      alAbrirFlujo = (r) async {
        r.statusCode = 401;
        await r.close();
      };
      final url = Uri.parse('${ApiClient.instance.baseUrl}/api/v1/eventos');
      await expectLater(
        abrirFlujoDeEventos(url: url, token: 'vencido').toList(),
        throwsA(isA<ErrorFlujoEventos>().having((e) => e.codigo, 'codigo', 401)),
      );
    });

    test('el servicio se conecta y, ante un evento, vuelve a leer los datos', () async {
      alAbrirFlujo = (r) async {
        r.write('event: conexion_establecida\ndata: {}\n\n');
        await r.flush();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        r.write('event: PEDIDO_NUEVO\ndata: {"id":"p1"}\n\n');
        await r.flush();
        // La conexión queda abierta, como en el servidor real.
        await Future<void>.delayed(const Duration(seconds: 5));
        await r.close();
      };
      final servicio = EventosService.instance;
      final revisiones = servicio.revision.value;

      servicio.iniciar();
      final fin = DateTime.now().add(const Duration(seconds: 12));
      // Espera la conexión, el evento y que las lecturas lleguen al servidor
      // (con la máquina cargada tardan más).
      while ((servicio.revision.value < revisiones + 2 ||
              !rutas.contains('/api/pedidos') ||
              !rutas.contains('/api/mesas')) &&
          DateTime.now().isBefore(fin)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      expect(servicio.conectado.value, true);
      expect(servicio.revision.value, greaterThan(revisiones));
      // Leyó pedidos y mesas por el evento.
      expect(rutas, contains('/api/pedidos'));
      expect(rutas, contains('/api/mesas'));

      servicio.detener();
      expect(servicio.conectado.value, false);
    });
  });
}

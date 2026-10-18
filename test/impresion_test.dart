import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/models/config_impresora.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/impresion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _config = {
  'sede_id': 's',
  'cocina_ip': '192.168.0.40:9100',
  'cocina_habilitada': true,
  'caja_ip': '192.168.0.52:9100',
  'caja_habilitada': false,
  'logo_path': 'assets/logo.png',
  'caja_imprimir_logo': true,
  'pausar_cola': false,
  'descartar_antiguos_dias': true,
  'cocina_mostrar_mozo': true,
  'cocina_mostrar_fecha': false,
  'cocina_mostrar_notas': true,
  'cocina_mostrar_taper': true,
  'cocina_tamano_letra': 'normal',
};

void main() {
  test('los modelos leen lo que responde el backend', () {
    final c = ConfigImpresora.fromJson(_config);
    expect(c.cocinaIp, '192.168.0.40:9100');
    expect(c.cajaHabilitada, false);
    expect(c.cocinaMostrarFecha, false);
    expect(c.cocinaTamanoLetra, 'normal');
    expect(c.toJson()['cocina_mostrar_fecha'], false);

    final e = EstadoImpresoras.fromJson({
      'cocina_ip': '192.168.0.40:9100',
      'cocina_conectada': true,
      'cocina_habilitada': true,
      'caja_conectada': false,
      'cola_pendientes': 2,
      'cola_pausada': true,
    });
    expect(e.cocinaConectada, true);
    expect(e.cajaConectada, false);
    expect([e.colaPendientes, e.colaPausada], [2, true]);

    final cola = ColaImpresion.fromJson({
      'pendientes': 1,
      'completados': 24,
      'con_error': 1,
      'jobs': [
        {
          'id': 'j1',
          'pedido_id': 'p1',
          'tipo': 'comanda_cocina',
          'codigo_orden': '#0001',
          'estado': 'completado',
          'intentos': 0,
          'created_at': '2026-10-17T16:20:00Z',
        },
        {
          'id': 'j2',
          'pedido_id': 'p2',
          'tipo': 'comanda_adicional',
          'codigo_orden': '#0002',
          'estado': 'expirado',
          'intentos': 3,
          'error_msg': 'Omitido por cambio de día',
        },
      ],
    });
    expect(cola.trabajos.length, 2);
    expect(cola.trabajos[0].sePuedeReintentar, false);
    expect(cola.trabajos[1].sePuedeReintentar, true);
    expect(cola.trabajos[1].etiquetaTipo, 'Adicional de cocina');
    expect(cola.trabajos[1].error, 'Omitido por cambio de día');
  });

  group('servicio contra el backend', () {
    late HttpServer servidor;
    final peticiones = <String>[];
    final cuerpos = <String>[];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ApiClient.instance.initialize();
      peticiones.clear();
      cuerpos.clear();
      servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      ApiClient.instance.setBaseUrl('http://127.0.0.1:${servidor.port}');
      servidor.listen((req) async {
        final texto = await utf8.decoder.bind(req).join();
        peticiones.add('${req.method} ${req.uri.path}');
        cuerpos.add(texto);
        Object cuerpo = {'mensaje': 'ok'};
        final ruta = req.uri.path;
        if (ruta.endsWith('/config') && req.method == 'GET') cuerpo = _config;
        if (ruta.endsWith('/estado')) {
          cuerpo = {'cocina_conectada': true, 'cocina_habilitada': true};
        }
        if (ruta.endsWith('/cola') && req.method == 'GET') {
          cuerpo = {'pendientes': 0, 'completados': 1, 'con_error': 0};
        }
        if (ruta.endsWith('/cancelar-pendientes')) cuerpo = {'cancelados': 8};
        if (ruta.endsWith('/config/logo')) {
          cuerpo = {'ruta': 'assets/logo_1.png'};
        }
        req.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(cuerpo));
        await req.response.close();
      });
    });

    tearDown(() async => servidor.close(force: true));

    test('lee, guarda solo lo que cambió, prueba y reimprime', () async {
      final s = ImpresionService.instance;
      expect((await s.obtenerConfig()).cocinaIp, '192.168.0.40:9100');
      expect((await s.obtenerEstado()).cocinaConectada, true);
      expect((await s.obtenerCola()).completados, 1);

      await s.actualizarConfig({'cocina_mostrar_notas': false});
      expect(peticiones.last, 'PUT /api/v1/impresion/config');
      expect(jsonDecode(cuerpos.last), {'cocina_mostrar_notas': false});

      await s.imprimirPrueba('cocina');
      expect(peticiones.last, 'POST /api/v1/impresion/test');
      expect(jsonDecode(cuerpos.last), {'destino': 'cocina'});

      await s.reimprimirPedido('abc');
      expect(peticiones.last, 'POST /api/v1/impresion/pedidos/abc/reimprimir');

      await s.pausarCola(true);
      expect(peticiones.last, 'POST /api/v1/impresion/cola/pausar');
      expect(jsonDecode(cuerpos.last), {'pausar': true});

      expect(await s.cancelarPendientes(), 8);
      await s.reintentarTrabajo('j1');
      expect(peticiones.last, 'POST /api/v1/impresion/jobs/j1/reintentar');
      await s.abrirCajon();
      expect(peticiones.last, 'POST /api/v1/caja/abrir-cajon');
    });

    test('sube el logo en el campo "logo"', () async {
      final ruta = await ImpresionService.instance.subirLogo([
        1,
        2,
        3,
      ], 'logo.png');
      expect(ruta, 'assets/logo_1.png');
      expect(peticiones.last, 'POST /api/v1/impresion/config/logo');
      expect(cuerpos.last, contains('name="logo"'));
    });
  });
}

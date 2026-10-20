import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/cierres_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/services/caja_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sedeId = '11111111-1111-1111-1111-111111111111';

Map<String, dynamic> _totales() => {
  'fecha_inicio': '2026-10-20T13:00:00Z',
  'fecha_corte': '2026-10-20T18:45:00Z',
  'monto_inicial': '150.00',
  'efectivo': '820.00',
  'tarjeta': '410.00',
  'yape': '180.00',
  'plin': '60.00',
  'delivery': '120.00',
  'general': '1470.00',
  'ingresos_efectivo': '50.00',
  'salidas_efectivo': '70.00',
  'efectivo_esperado_en_caja': '950.00',
  'tarjeta_esperada': '405.00',
  'digital_esperado': '240.00',
  'total_recargos': '20.50',
  'num_pedidos': 28,
  'apertura_id': 'ap-1',
  'por_medio_pago': [
    {
      'medio_pago_id': 'm1',
      'medio_pago_nombre': 'Efectivo',
      'ventas': '820.00',
      'ingresos': '50.00',
      'salidas': '70.00',
      'neto': '800.00',
    },
    {
      'medio_pago_id': 'm2',
      'medio_pago_nombre': 'Tarjeta Visa',
      'ventas': '410.00',
      'ingresos': '0.00',
      'salidas': '0.00',
      'neto': '410.00',
    },
  ],
};

void main() {
  late HttpServer servidor;
  final peticiones = <String>[];
  final cuerpos = <Map<String, dynamic>>[];
  var estado = 'cerrada';

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService.instance.userNotifier.value = const Usuario(
      id: 'u1',
      nombre: 'Caja',
      email: 'c@x',
      rol: AppRole.cajero,
      sedeId: _sedeId,
    );
    estadoCajaServidor = null;
    cierresCaja.clear();
    peticiones.clear();
    cuerpos.clear();
    estado = 'cerrada';
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    ApiClient.instance.setBaseUrl('http://127.0.0.1:${servidor.port}');
    servidor.listen((req) async {
      final texto = await utf8.decoder.bind(req).join();
      peticiones.add('${req.method} ${req.uri.path}');
      if (texto.isNotEmpty) cuerpos.add(jsonDecode(texto));
      req.response.headers.contentType = ContentType.json;
      final ruta = req.uri.path;
      if (ruta.endsWith('/estado-actual')) {
        req.response.write(
          jsonEncode({
            'estado': estado,
            if (estado == 'abierta')
              'apertura': {
                'id': 'ap-1',
                'monto_inicial': '150.00',
                'fecha_apertura': '2026-10-20T13:00:00Z',
                'estado': 'abierta',
              },
            if (estado == 'abierta') 'totales': _totales(),
          }),
        );
      } else if (ruta.endsWith('/totales-actual')) {
        req.response.write(jsonEncode(_totales()));
      } else if (ruta.endsWith('/apertura')) {
        estado = 'abierta';
        req.response
          ..statusCode = 201
          ..write(jsonEncode({'id': 'ap-1', 'estado': 'abierta'}));
      } else if (ruta.endsWith('/cierre')) {
        estado = 'cerrada';
        req.response
          ..statusCode = 201
          ..write(
            jsonEncode({
              'id': 'ci-1',
              'usuario_nombre': 'Ana',
              'fecha_inicio': '2026-10-20T13:00:00Z',
              'fecha_cierre': '2026-10-20T18:50:00Z',
              'monto_inicial': '150.00',
              'total_efectivo': '820.00',
              'total_general': '1470.00',
              'num_pedidos': 28,
              'declarado_efectivo': '950.00',
              'diferencia_efectivo': '0.00',
            }),
          );
      } else {
        // /cierres
        req.response.write(jsonEncode([]));
      }
      await req.response.close();
    });
  });

  tearDown(() async {
    await servidor.close(force: true);
    estadoCajaServidor = null;
    cierresCaja.clear();
  });

  test('con sede del servidor la caja se lleva en el servidor', () {
    expect(CajaService.instance.enServidor, isTrue);
  });

  test('cerrada: lee el estado y pide los totales aparte', () async {
    final e = await CajaService.instance.cargarEstado();
    expect(e.abierta, isFalse);
    expect(peticiones, [
      'GET /api/v1/caja/estado-actual',
      'GET /api/v1/caja/totales-actual',
    ]);
    expect(estadoCajaServidor, isNotNull);
  });

  test(
    'abrir manda la sede y el monto inicial, y deja la caja abierta',
    () async {
      await CajaService.instance.abrir(montoInicial: 150, notas: ' sencillo ');
      expect(peticiones.first, 'POST /api/v1/caja/apertura');
      expect(cuerpos.first['sede_id'], _sedeId);
      expect(cuerpos.first['monto_inicial'], 150);
      expect(cuerpos.first['notas'], 'sencillo');
      expect(estadoCajaServidor!.abierta, isTrue);
      expect(estadoCajaServidor!.apertura!.montoInicial, 150);
    },
  );

  test('abierta: los totales por medio de pago vienen del servidor', () async {
    estado = 'abierta';
    await CajaService.instance.cargarEstado();
    final t = estadoCajaServidor!.totales!;
    expect(t.ventas, 1470);
    expect(t.efectivoEsperado, 950); // ya incluye el monto inicial
    // Tarjeta y digital esperados ya cuentan ingresos y salidas de cada medio.
    expect(t.tarjeta, 405);
    expect(t.digital, 240);
    expect(t.ingresos, 50);
    expect(t.salidas, 70);
    expect(t.numPedidos, 28);
    expect(t.porMedio.map((f) => f.medio), ['Efectivo', 'Tarjeta Visa']);
    expect(t.porMedio.first.neto, 800);
    // El servidor marca el inicio de la caja actual.
    expect(inicioCajaActual, t.fechaInicio);
  });

  test(
    'cerrar manda lo declarado, sin monto inicial, y relee el estado',
    () async {
      estado = 'abierta';
      await CajaService.instance.cargarEstado();
      peticiones.clear();
      cuerpos.clear();
      final c = await CajaService.instance.cerrar(
        declaradoEfectivo: 950,
        declaradoTarjeta: 410,
        declaradoDigital: 240,
        notas: 'ok',
      );
      expect(peticiones.first, 'POST /api/v1/caja/cierre');
      expect(cuerpos.first.containsKey('monto_inicial'), isFalse);
      expect(cuerpos.first['declarado_efectivo'], 950);
      expect(cuerpos.first['declarado_tarjeta'], 410);
      expect(cuerpos.first['declarado_digital'], 240);
      expect(c.usuarioNombre, 'Ana');
      expect(c.totalGeneral, 1470);
      // Después del cierre la caja queda cerrada.
      expect(estadoCajaServidor!.abierta, isFalse);
    },
  );
}

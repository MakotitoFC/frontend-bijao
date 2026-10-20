import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/movimientos_caja_store.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/movimiento_caja.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/movimiento_caja_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _catId = '01925b6a-9b1d-7234-a123-abcdef0123c1';
const _medioId = '01925b6a-9b1d-7234-a123-abcdef0123c2';
const _movId = '01925b6a-9b1d-7234-a123-abcdef0123c3';

const _categoriaSalida = CategoriaMovimiento(
  id: _catId,
  nombre: 'Compra de insumos',
  tipo: TipoMovimiento.egreso,
);
const _efectivo = MedioPago(
  id: _medioId,
  medioPago: 'Efectivo',
  aplicaComision: false,
);

Map<String, dynamic> _json({
  String id = _movId,
  String tipo = 'E',
  Object precio = '25.50',
  String? nota,
  String? estado,
  String? motivo,
}) => {
  'id': id,
  'categoria_movimiento_id': _catId,
  'categoria_nombre': 'Compra de insumos',
  'tipo': tipo,
  'precio': precio,
  'fecha_movimiento': '2026-10-20T15:00:00Z',
  'medio_pago_id': _medioId,
  'medio_pago_nombre': 'Efectivo',
  'created_at': '2026-10-20T15:00:00Z',
  'nota': ?nota,
  'estado': ?estado,
  'motivo_anulacion': ?motivo,
};

void main() {
  late HttpServer servidor;
  final peticiones = <String>[];
  final cuerpos = <Map<String, dynamic>>[];
  final consultas = <Map<String, String>>[];
  var rechazar = false;
  Object lista = [];

  // Iniciar el cliente busca el servidor en la red (tarda): se hace una vez.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    movimientosCaja.clear();
    categoriasMovimiento.clear();
    notasMovimientoLocales.clear();
    peticiones.clear();
    cuerpos.clear();
    consultas.clear();
    rechazar = false;
    lista = [];
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    ApiClient.instance.setBaseUrl('http://127.0.0.1:${servidor.port}');
    servidor.listen((req) async {
      final texto = await utf8.decoder.bind(req).join();
      peticiones.add('${req.method} ${req.uri.path}');
      consultas.add(req.uri.queryParameters);
      Map<String, dynamic> cuerpo = {};
      if (texto.isNotEmpty) {
        cuerpo = jsonDecode(texto) as Map<String, dynamic>;
        cuerpos.add(cuerpo);
      }
      req.response.headers.contentType = ContentType.json;
      if (rechazar && req.method != 'GET') {
        req.response
          ..statusCode = 400
          ..write(
            jsonEncode({'error': 'el monto del movimiento no puede ser 0'}),
          );
      } else if (req.method == 'GET') {
        req.response.write(jsonEncode(lista));
      } else if (req.uri.path.endsWith('/anular')) {
        req.response.write(
          jsonEncode(
            _json(estado: 'anulado', motivo: cuerpo['motivo'] as String?),
          ),
        );
      } else if (req.method == 'PUT') {
        req.response.write(
          jsonEncode(
            _json(
              precio: cuerpo['precio'] as Object,
              nota: cuerpo['nota'] as String?,
            ),
          ),
        );
      } else {
        req.response
          ..statusCode = 201
          ..write(jsonEncode(_json(precio: cuerpo['precio'] as Object)));
      }
      await req.response.close();
    });
  });

  tearDown(() async {
    await servidor.close(force: true);
    movimientosCaja.clear();
    categoriasMovimiento.clear();
    notasMovimientoLocales.clear();
  });

  test('registrar manda el movimiento al servidor y lo guarda', () async {
    final m = await MovimientoCajaService.instance.registrar(
      categoria: _categoriaSalida,
      monto: 25.5,
      medio: _efectivo,
      nota: ' hielo ',
    );
    expect(peticiones, ['POST /api/movimientos']);
    expect(cuerpos.single['categoria_movimiento_id'], _catId);
    expect(cuerpos.single['medio_pago_id'], _medioId);
    expect(cuerpos.single['precio'], 25.5);
    expect(cuerpos.single['nota'], 'hielo');
    expect(m.id, _movId);
    expect(m.tipo, TipoMovimiento.egreso);
    expect(m.monto, 25.5);
    // El servidor aún no guarda la nota: se conserva la escrita aquí.
    expect(m.nota, 'hielo');
    expect(movimientosCaja.single.id, _movId);
  });

  test('si el servidor lo rechaza no queda nada registrado', () async {
    rechazar = true;
    await expectLater(
      MovimientoCajaService.instance.registrar(
        categoria: _categoriaSalida,
        monto: 10,
        medio: _efectivo,
      ),
      throwsA(predicate((e) => e.toString().contains('no puede ser 0'))),
    );
    expect(movimientosCaja, isEmpty);
  });

  test('con categorías de demostración se queda en memoria', () async {
    final m = await MovimientoCajaService.instance.registrar(
      categoria: categoriasMovimientoBase.firstWhere(
        (c) => c.tipo == TipoMovimiento.ingreso,
      ),
      monto: 50,
      medio: const MedioPago(
        id: 'mp1',
        medioPago: 'Efectivo',
        aplicaComision: false,
      ),
    );
    expect(peticiones, isEmpty);
    expect(m.id, startsWith('local-'));
    expect(m.tipo, TipoMovimiento.ingreso);
    expect(movimientosCaja, hasLength(1));
  });

  test(
    'cargarDelTurno pide desde el inicio de la caja y no pierde las notas',
    () async {
      notasMovimientoLocales[_movId] = 'hielo';
      lista = [
        _json(),
        _json(
          id: '01925b6a-9b1d-7234-a123-abcdef0123c4',
          tipo: 'I',
          precio: 10,
        ),
      ];
      final desde = DateTime(2026, 10, 20, 0, 0);
      await MovimientoCajaService.instance.cargarDelTurno(desde);

      expect(peticiones, ['GET /api/movimientos']);
      expect(consultas.single['fecha_desde'], desde.toUtc().toIso8601String());
      expect(movimientosCaja, hasLength(2));
      expect(movimientosCaja.firstWhere((m) => m.id == _movId).nota, 'hielo');

      // Leer otra vez no duplica.
      await MovimientoCajaService.instance.cargarDelTurno(desde);
      expect(movimientosCaja, hasLength(2));
    },
  );

  test('cargarCategorias lee tipo y estado', () async {
    lista = [
      {
        'id': _catId,
        'categoria': 'Compra de insumos',
        'tipo': 'E',
        'estado': true,
      },
      {'id': 'x1', 'categoria': 'Otros ingresos', 'tipo': 'I', 'estado': false},
    ];
    await MovimientoCajaService.instance.cargarCategorias();
    expect(categoriasMovimiento, hasLength(2));
    expect(categoriasMovimiento.first.tipo, TipoMovimiento.egreso);
    // Solo cuentan las activas; si no hay de un tipo, se usan las de partida.
    expect(categoriasDeTipo(TipoMovimiento.egreso).single.id, _catId);
    expect(
      categoriasDeTipo(TipoMovimiento.ingreso).first.id,
      categoriasMovimientoBase
          .firstWhere((c) => c.tipo == TipoMovimiento.ingreso)
          .id,
    );
  });

  group('editar y anular (rutas que el backend aún debe entregar)', () {
    Future<MovimientoCaja> uno() => MovimientoCajaService.instance.registrar(
      categoria: _categoriaSalida,
      monto: 25.5,
      medio: _efectivo,
    );

    test('anular manda el motivo y el movimiento queda, anulado', () async {
      final m = await uno();
      peticiones.clear();
      final a = await MovimientoCajaService.instance.anular(
        m,
        motivo: 'Se registró dos veces',
      );
      expect(peticiones, ['POST /api/movimientos/$_movId/anular']);
      expect(cuerpos.last['motivo'], 'Se registró dos veces');
      expect(a.anulado, isTrue);
      expect(a.motivoAnulacion, 'Se registró dos veces');
      // Sigue en la lista, pero ya no suma ni resta.
      expect(movimientosCaja.single.anulado, isTrue);
      expect(movimientosCaja.single.efecto, 0);
    });

    test('anular exige un motivo', () async {
      final m = await uno();
      await expectLater(
        MovimientoCajaService.instance.anular(m, motivo: '  '),
        throwsA(predicate((e) => e.toString().contains('motivo'))),
      );
      expect(movimientosCaja.single.anulado, isFalse);
    });

    test('editar manda los cambios con PUT', () async {
      final m = await uno();
      peticiones.clear();
      final e = await MovimientoCajaService.instance.editar(
        m,
        categoria: _categoriaSalida,
        monto: 30,
        medio: _efectivo,
        nota: 'corregido',
      );
      expect(peticiones, ['PUT /api/movimientos/$_movId']);
      expect(cuerpos.last['precio'], 30);
      expect(e.monto, 30);
      expect(movimientosCaja.single.monto, 30);
    });
  });
}

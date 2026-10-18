import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/mesas_por_liberar_store.dart';
import 'package:frontend_bijao/data/mesas_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/mesa.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/services/pedido_service.dart';
import 'package:frontend_bijao/services/pedido_mozo_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pedidoId = '44444444-4444-4444-8444-444444444444';
const _carta = '11111111-1111-4111-8111-111111111111';
const _taper = '22222222-2222-4222-8222-222222222222';
const _mesa = '33333333-3333-4333-8333-333333333333';

Map<String, dynamic> _detalle({int version = 1, int cantidad = 2}) => {
  'id': _pedidoId,
  'version': version,
  'estado': 'pendiente',
  'tipo': 'normal',
  'mesa_id': _mesa,
  'mesa_numero': 4,
  'usuario_id': 'u-1',
  'mozo_nombre': 'Ana',
  'instante_inicio': '2026-10-13T12:00:00-05:00',
  'costo_delivery': 0,
  'total_descuento': 0,
  'total': 28.0 * cantidad + 5.0 * cantidad,
  'descuentos': [],
  'items': [
    {
      'id': 'd-1',
      'version': version,
      'tipo_item': 'carta',
      'carta_id': _carta,
      'nombre': 'Tacacho con Cecina',
      'estado': 'pendiente',
      'cantidad': cantidad,
      'precio_unitario': 28.0,
      'descuento_fila': 0,
      'total_fila': 28.0 * cantidad,
      'tipo_entrega': 'mesa',
    },
    {
      'id': 'd-2',
      'version': 1,
      'tipo_item': 'taper',
      'taper_id': _taper,
      'nombre': 'Táper grande',
      'estado': 'pendiente',
      'cantidad': cantidad,
      'precio_unitario': 5.0,
      'descuento_fila': 0,
      'total_fila': 5.0 * cantidad,
      'tipo_entrega': 'mesa',
    },
  ],
};

PedidoLine _linea() => const PedidoLine(
  id: 'local',
  cartaId: _carta,
  nombrePlato: 'Tacacho con Cecina',
  cantidad: 2,
  modificadores: [],
  presentacion: null,
  promocion: null,
  comentario: null,
  precioUnitario: 28,
  descuentoAplicado: 0,
  precioTotalLinea: 56,
  aplicaTaper: true,
  taperId: _taper,
  precioTaper: 5,
  precioBase: 28,
);

void main() {
  late HttpServer servidor;
  final peticiones = <String>[];
  final cuerpos = <Map<String, dynamic>>[];
  // Respuesta que se devuelve a la próxima llamada PATCH.
  late int Function() estadoPatch;
  late Object Function() cuerpoPatch;
  // Respuesta de la lista de pedidos del mozo.
  var listaActual = <Map<String, dynamic>>[];
  // Respuesta de /mozo/mesas/por-liberar (la arma el backend).
  var porLiberarActual = <Map<String, dynamic>>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    peticiones.clear();
    cuerpos.clear();
    pedidos.clear();
    detallesPorPedido.clear();
    estadoPatch = () => 200;
    cuerpoPatch = () => _detalle(version: 2, cantidad: 3);
    listaActual = [];
    porLiberarActual = [];
    limpiarMesasPorLiberar();
    AuthService.instance.userNotifier.value = const Usuario(
      id: 'u-1',
      nombre: 'Ana',
      email: 'a@a',
      rol: AppRole.mesero,
    );
    mesas
      ..clear()
      ..add(const Mesa(id: _mesa, numero: 4, estado: 'ocupada'));

    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    ApiClient.instance.setBaseUrl('http://127.0.0.1:${servidor.port}');
    servidor.listen((req) async {
      final texto = await utf8.decoder.bind(req).join();
      peticiones.add('${req.method} ${req.uri.path}');
      if (texto.isNotEmpty) {
        cuerpos.add(jsonDecode(texto) as Map<String, dynamic>);
      }
      Object cuerpo;
      var estado = 200;
      if (req.method == 'POST') {
        cuerpo = _detalle();
        estado = 201;
      } else if (req.method == 'PATCH') {
        estado = estadoPatch();
        cuerpo = cuerpoPatch();
      } else if (req.uri.path == '/api/v1/mozo/pedidos') {
        cuerpo = listaActual;
      } else if (req.uri.path == '/api/v1/mozo/mesas/por-liberar') {
        cuerpo = porLiberarActual;
      } else {
        cuerpo = _detalle(version: 7, cantidad: 2);
      }
      req.response
        ..statusCode = estado
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(cuerpo));
      await req.response.close();
    });
  });

  tearDown(() async => servidor.close(force: true));

  test(
    'crear: envía filas sin precios y deja el pedido del servidor',
    () async {
      final d = await PedidoMozoService.instance.crear(
        lineas: [_linea()],
        mesaId: _mesa,
      );

      expect(peticiones, ['POST /api/v1/mozo/pedidos']);
      final items = cuerpos.single['items'] as List;
      expect(items.length, 2);
      expect(items[1]['taper_id'], _taper);
      expect(d.id, _pedidoId);

      final p = pedidos.single;
      expect(p.id, _pedidoId);
      expect(p.version, 1);
      expect(p.mozoNombre, 'Ana');
      expect(p.mesaNumero, 4);
      final lineas = detallesPorPedido[_pedidoId]!;
      expect(lineas.map((l) => l.id), ['d-1', 'd-2']);
      expect(lineas.fold(0.0, (s, l) => s + l.precioTotalLinea), 66);
    },
  );

  test('cambiar cantidad: usa la versión de la fila y refresca', () async {
    await PedidoMozoService.instance.crear(lineas: [_linea()], mesaId: _mesa);
    final fila = detallesPorPedido[_pedidoId]!.first;
    await PedidoMozoService.instance.cambiarCantidad(_pedidoId, fila, 3);

    expect(
      peticiones.last,
      'PATCH /api/v1/mozo/pedidos/$_pedidoId/items/d-1/cantidad',
    );
    expect(cuerpos.last, {'cantidad': 3, 'version': 1});
    expect(pedidos.single.version, 2);
    expect(detallesPorPedido[_pedidoId]!.first.cantidad, 3);
  });

  test('409 sin código: recarga el pedido y avisa que cambió', () async {
    await PedidoMozoService.instance.crear(lineas: [_linea()], mesaId: _mesa);
    final fila = detallesPorPedido[_pedidoId]!.first;
    estadoPatch = () => 409;
    cuerpoPatch = () => {'error': 'El pedido fue modificado por otro usuario'};

    await expectLater(
      PedidoMozoService.instance.cambiarCantidad(_pedidoId, fila, 3),
      throwsA(isA<PedidoCambioException>()),
    );
    expect(peticiones.last, 'GET /api/v1/mozo/pedidos/$_pedidoId');
    expect(pedidos.single.version, 7); // quedó con lo que tiene el servidor
  });

  test('409 por stock: se propaga con su código', () async {
    await PedidoMozoService.instance.crear(lineas: [_linea()], mesaId: _mesa);
    final fila = detallesPorPedido[_pedidoId]!.first;
    estadoPatch = () => 409;
    cuerpoPatch = () => {
      'error': "el plato 'Tacacho' se encuentra agotado",
      'codigo': 'AGOTADO',
      'carta_id': _carta,
    };

    await expectLater(
      PedidoMozoService.instance.cambiarCantidad(_pedidoId, fila, 9),
      throwsA(
        isA<ApiException>().having(
          (e) => e.details['codigo'],
          'codigo',
          'AGOTADO',
        ),
      ),
    );
    expect(peticiones.last, startsWith('PATCH'));
  });

  test('la propina local sobrevive al refresco', () async {
    await PedidoMozoService.instance.crear(lineas: [_linea()], mesaId: _mesa);
    establecerPropinaPedido(_pedidoId, 4);
    expect(propinaDePedido(_pedidoId), 4);

    await PedidoMozoService.instance.obtener(_pedidoId);
    expect(propinaDePedido(_pedidoId), 4);
    expect(detallesPorPedido[_pedidoId]!.length, 3);
  });

  test('un pedido que deja de venir en la lista NO deja la mesa por liberar', () async {
    // Caso del error: el pedido es de otro mozo (estaba en memoria) y la lista
    // de este mozo ya no lo trae. No significa que se haya cobrado.
    await PedidoMozoService.instance.crear(lineas: [_linea()], mesaId: _mesa);
    await PedidoMozoService.instance.sincronizar(); // la lista ya no lo trae
    expect(pedidos, isEmpty);
    expect(mesasPorLiberar(), isEmpty);
    expect(hayMesasPorLiberarPendientes, false);
  });

  test('las mesas por liberar son las que informa el backend', () async {
    porLiberarActual = [
      {
        'mesa_id': _mesa,
        'mesa_numero': 4,
        'zona_id': 'z',
        'zona_nombre': 'Salón',
        'pedido_id': _pedidoId,
        'mozo_id': 'u-1',
      },
    ];
    await PedidoMozoService.instance.sincronizar();
    expect(peticiones, contains('GET /api/v1/mozo/mesas/por-liberar'));
    expect(mesasPorLiberar().map((m) => m.id), [_mesa]);
    expect(hayMesasPorLiberarPendientes, true);

    // El backend ya no la informa (alguien la liberó): desaparece.
    porLiberarActual = [];
    await recargarMesasPorLiberar();
    expect(mesasPorLiberar(), isEmpty);
  });

  test(
    'si la mesa no está en el catálogo local se arma con los datos del backend',
    () async {
      mesas.clear();
      porLiberarActual = [
        {
          'mesa_id': _mesa,
          'mesa_numero': 4,
          'zona_id': 'z',
          'zona_nombre': 'Terraza',
        },
      ];
      await recargarMesasPorLiberar();
      final m = mesasPorLiberar().single;
      expect(
        [m.id, m.numero, m.zona, m.estaOcupada],
        [_mesa, 4, 'Terraza', true],
      );
    },
  );

  test(
    'a un mozo no le salen mesas de otro mozo aunque lleguen en la lista',
    () async {
      porLiberarActual = [
        {'mesa_id': _mesa, 'mesa_numero': 4, 'mozo_id': 'otro-mozo'},
        {
          'mesa_id': '99999999-9999-4999-8999-999999999999',
          'mesa_numero': 7,
          'mozo_id': 'u-1',
        },
      ];
      await recargarMesasPorLiberar();
      expect(mesasPorLiberar().map((m) => m.numero), [7]); // solo la suya
    },
  );

  test('el administrador sí ve las de todos', () async {
    AuthService.instance.userNotifier.value = const Usuario(
      id: 'admin',
      nombre: 'Admin',
      email: 'a@a',
      rol: AppRole.administrador,
    );
    porLiberarActual = [
      {'mesa_id': _mesa, 'mesa_numero': 4, 'mozo_id': 'otro-mozo'},
    ];
    await recargarMesasPorLiberar();
    expect(mesasPorLiberar().map((m) => m.numero), [4]);
  });

  test(
    'una mesa con un pedido abierto que la app conoce no se ofrece',
    () async {
      await PedidoMozoService.instance.crear(lineas: [_linea()], mesaId: _mesa);
      porLiberarActual = [
        {'mesa_id': _mesa, 'mesa_numero': 4, 'mozo_id': 'u-1'},
      ];
      await recargarMesasPorLiberar();
      expect(mesasPorLiberar(), isEmpty); // hay un pedido abierto en la mesa 4
    },
  );

  test('al cambiar de usuario no queda la lista del anterior ni si falla la lectura', () async {
    fijarMesasPorLiberar('otro-usuario', [mesas.first]);
    expect(hayMesasPorLiberarPendientes, true);

    // Servidor caído: la lectura falla.
    ApiClient.instance.setBaseUrl('http://127.0.0.1:1');
    await recargarMesasPorLiberar();

    expect(mesasPorLiberar(), isEmpty);
  });

  test(
    'cerrar sesión borra los pedidos y las mesas por liberar en memoria',
    () async {
      await PedidoMozoService.instance.crear(lineas: [_linea()], mesaId: _mesa);
      // Otra mesa ya cobrada (la 4 tiene el pedido abierto).
      porLiberarActual = [
        {'mesa_id': '99999999-9999-4999-8999-999999999999', 'mesa_numero': 7},
      ];
      await recargarMesasPorLiberar();
      expect(pedidos, isNotEmpty);
      expect(hayMesasPorLiberarPendientes, true);

      await AuthService.instance.logout();

      expect(pedidos, isEmpty);
      expect(detallesPorPedido, isEmpty);
      expect(mesasPorLiberar(), isEmpty);
    },
  );

  test('un pedido anulado no deja la mesa por liberar', () async {
    await PedidoMozoService.instance.crear(lineas: [_linea()], mesaId: _mesa);
    actualizarEstadoPedido(_pedidoId, 'anulado');
    await PedidoMozoService.instance.sincronizar();
    expect(mesasPorLiberar(), isEmpty);
  });

  test(
    'liberar una mesa llama al servidor y la quita de "por liberar"',
    () async {
      AuthService.instance.userNotifier.value = const Usuario(
        id: 'u1',
        nombre: 'mozo1',
        email: 'm@m',
        rol: AppRole.mesero,
      );
      addTearDown(() => AuthService.instance.userNotifier.value = null);
      porLiberarActual = [
        {'mesa_id': _mesa, 'mesa_numero': 4},
      ];
      await recargarMesasPorLiberar();
      expect(hayMesasPorLiberarPendientes, true);

      await PedidoService.instance.liberarMesa(_mesa, 4);
      quitarMesaPorLiberar(_mesa);

      expect(peticiones, contains('POST /api/v1/mozo/mesas/$_mesa/liberar'));
      expect(cuerpos.last, {'forzar': false});
      expect(hayMesasPorLiberarPendientes, false);
    },
  );
}

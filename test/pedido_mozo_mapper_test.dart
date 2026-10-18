import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/data/promociones_store.dart';
import 'package:frontend_bijao/models/promocion.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/services/pedido_mozo_mapper.dart';

const _carta = '11111111-1111-4111-8111-111111111111';
const _taper = '22222222-2222-4222-8222-222222222222';
const _mesa = '33333333-3333-4333-8333-333333333333';

PedidoLine _linea({
  String cartaId = _carta,
  String nombre = 'Tacacho con Cecina',
  int cantidad = 2,
  double precio = 28,
  bool taper = false,
  bool libre = false,
  String? comentario,
}) => PedidoLine(
  id: 'local',
  cartaId: cartaId,
  nombrePlato: nombre,
  cantidad: cantidad,
  modificadores: const [],
  presentacion: null,
  promocion: null,
  comentario: comentario,
  precioUnitario: precio,
  descuentoAplicado: 0,
  precioTotalLinea: precio * cantidad,
  aplicaTaper: taper,
  taperId: taper ? _taper : null,
  precioTaper: taper ? 5 : 0,
  esLibre: libre,
  nombreLibre: libre ? nombre : null,
  precioBase: precio,
);

void main() {
  test('plato con táper: dos filas y ningún precio', () {
    final body = armarPedidoMozo(
      lineas: [_linea(taper: true, comentario: 'sin ají')],
      mesaId: _mesa,
    );
    final items = body['items'] as List;
    expect(body['mesa_id'], _mesa);
    expect(items.length, 2);
    expect(items[0]['carta_id'], _carta);
    expect(items[0]['cantidad'], 2);
    expect(items[0]['comentario'], 'sin ají');
    expect(items[1]['taper_id'], _taper);
    expect(items[1]['cantidad'], 2);
    for (final it in items) {
      expect(it.containsKey('precio'), false);
      expect(it.containsKey('precio_base'), false);
      expect(it.containsKey('precio_taper'), false);
    }
  });

  test('plato libre envía su precio; delivery va como libre; ajustes no', () {
    final body = armarPedidoMozo(
      lineas: [
        _linea(
          cartaId: 'libre',
          nombre: 'Arroz a la cubana',
          libre: true,
          precio: 15,
          cantidad: 1,
        ),
        _linea(
          cartaId: cartaIdCargoDelivery,
          nombre: 'Cargo por delivery',
          precio: 3,
          cantidad: 1,
        ),
        _linea(
          cartaId: cartaIdAjuste,
          nombre: 'Propina: 10%',
          precio: 4,
          cantidad: 1,
        ),
      ],
    );
    final items = body['items'] as List;
    expect(items.length, 2);
    expect(items[0]['es_libre'], true);
    expect(items[0]['precio_unitario_libre'], 15);
    expect(items[1]['nombre_libre'], 'Cargo por delivery');
    expect(body.containsKey('mesa_id'), false);
  });

  test('delivery: el costo viaja en delivery y no como ítem', () {
    final body = armarPedidoMozo(
      lineas: [
        _linea(),
        _linea(
          cartaId: cartaIdCargoDelivery,
          nombre: 'Cargo por delivery',
          precio: 3,
          cantidad: 1,
        ),
      ],
      tipo: 'delivery',
      delivery: const DatosDelivery(
        direccion: 'Jr. Lima 123',
        telefono: '999',
        costoEnvio: 3,
      ),
    );
    expect((body['items'] as List).length, 1);
    expect(body['delivery']['direccion'], 'Jr. Lima 123');
    expect(body['delivery']['costo_envio'], 3);
  });

  test('respuesta del backend: ids, versiones, descuentos y delivery', () {
    final r = parsearDetalleMozo({
      'id': 'p-1',
      'version': 4,
      'estado': 'pendiente',
      'mesa_numero': 4,
      'mozo_nombre': 'Ana',
      'costo_delivery': 3.0,
      'total_descuento': 5.0,
      'total': 70.0,
      'descuentos': [
        {
          'id': 'x-1',
          'motivo': 'Empleado',
          'tipo': 'porcentaje',
          'valor': 10,
          'monto_aplicado': 5.0,
        },
      ],
      'items': [
        {
          'id': 'd-1',
          'version': 1,
          'tipo_item': 'carta',
          'carta_id': _carta,
          'nombre': 'Tacacho con Cecina',
          'estado': 'pendiente',
          'cantidad': 2,
          'precio_unitario': 28.0,
          'descuento_fila': 0,
          'total_fila': 56.0,
          'tipo_entrega': 'mesa',
        },
        {
          'id': 'd-2',
          'version': 1,
          'tipo_item': 'taper',
          'taper_id': _taper,
          'nombre': 'Táper grande',
          'estado': 'pendiente',
          'cantidad': 2,
          'precio_unitario': 5.0,
          'descuento_fila': 0,
          'total_fila': 10.0,
          'tipo_entrega': 'mesa',
        },
        {
          'id': 'd-3',
          'version': 3,
          'tipo_item': 'carta',
          'carta_id': _carta,
          'nombre': 'Jugo',
          'estado': 'servido',
          'cantidad': 1,
          'precio_unitario': 6.0,
          'descuento_fila': 0,
          'total_fila': 6.0,
        },
        {
          'id': 'd-4',
          'version': 2,
          'tipo_item': 'carta',
          'nombre': 'Anulado',
          'estado': 'anulado',
          'cantidad': 1,
          'precio_unitario': 1.0,
          'total_fila': 1.0,
        },
      ],
    });

    expect(r.id, 'p-1');
    expect(r.version, 4);
    expect(r.mozoNombre, 'Ana');
    expect(r.servidas, {'d-3'});
    expect(r.lineas.length, 5); // 3 filas + delivery + descuento
    expect(r.lineas[0].cartaId, _carta);
    expect(esLineaTaper(r.lineas[1]), true);
    expect(r.lineas[2].version, 3);
    final suma = r.lineas.fold(0.0, (s, l) => s + l.precioTotalLinea);
    expect(suma, closeTo(r.total, 0.001)); // 56+10+6+3-5
  });

  test('pedido de empleado: viaja el tipo y se reconoce por el tipo o el descuento', () {
    final body = armarPedidoMozo(
      lineas: [_linea()],
      mesaId: _mesa,
      tipo: 'empleado',
    );
    expect(body['tipo'], 'empleado');
    expect(
      parsearDetalleMozo({'id': 'p', 'tipo': 'empleado', 'items': []}).tipo,
      'empleado',
    );

    final normal = Pedido(
      id: 'p-emp',
      numeroPedido: '1',
      mesaNumero: 1,
      fechaPedido: DateTime(2026),
    );
    detallesPorPedido['p-emp'] = [];
    expect(esPedidoDeEmpleado(normal), false);
    expect(esPedidoDeEmpleado(normal.copyWith(esEmpleado: true)), true);
    // Descuento de empleado aplicado después de crear el pedido.
    detallesPorPedido['p-emp'] = [
      _linea(
        cartaId: cartaIdAjuste,
        nombre: 'Descuento: Empleado',
        precio: -5,
        cantidad: 1,
      ),
    ];
    expect(esPedidoDeEmpleado(normal), true);
    detallesPorPedido.remove('p-emp');
  });

  test('cronómetro: fin del pedido por hora de fin o por estado cerrado', () {
    final inicio = DateTime(2026, 10, 13, 12, 0, 0);
    expect(fechaDeFin('12:45:30', inicio), DateTime(2026, 10, 13, 12, 45, 30));
    expect(
      fechaDeFin('00:10:00', DateTime(2026, 10, 13, 23, 50)),
      DateTime(2026, 10, 14, 0, 10),
    );
    expect(fechaDeFin(null, inicio), null);
    expect(fechaDeFin('', inicio), null);

    final abierto = Pedido(
      id: 'a',
      numeroPedido: '1',
      mesaNumero: 1,
      fechaPedido: inicio,
    );
    expect(abierto.terminado, false);
    for (final e in ['servido', 'pagado', 'anulado', 'devuelto']) {
      expect(abierto.copyWith(estado: e).terminado, true, reason: e);
    }

    final cerrado = parsearDetalleMozo({
      'id': 'p',
      'estado': 'pagado',
      'instante_inicio': '2026-10-13T12:00:00-05:00',
      'hora_fin': '12:30:00',
      'items': [],
    });
    expect(cerrado.fin, isNotNull);
    expect(
      parsearDetalleMozo({'id': 'p', 'estado': 'pendiente', 'items': []}).fin,
      null,
    );
  });

  test('tipo de entrega, cliente y envío: se envían y se leen del backend', () {
    final body = armarPedidoMozo(
      lineas: [_linea()],
      tipoEntrega: 'llevar',
      nombreCliente: ' Carlos Diaz ',
    );
    expect(body['tipo_entrega'], 'llevar');
    expect(body['nombre_cliente'], 'Carlos Diaz');
    expect((body['items'] as List).first['tipo_entrega'], 'llevar');
    expect(
      armarPedidoMozo(lineas: [_linea()], mesaId: _mesa)['tipo_entrega'],
      'mesa',
    );

    final d = parsearDetalleMozo({
      'id': 'p',
      'tipo_entrega': 'delivery',
      'nombre_cliente': 'Juan Perez',
      'costo_delivery': 5.0,
      'delivery': {
        'direccion': 'Av. Los Cedros 456',
        'referencia': 'Casa de 2 pisos',
        'telefono': '987654321',
        'costo_envio': 5.0,
      },
      'items': [],
    });
    expect(d.tipoEntrega, 'delivery');
    expect(d.nombreCliente, 'Juan Perez');
    expect(d.delivery?.direccion, 'Av. Los Cedros 456');
    expect(d.delivery?.telefono, '987654321');
    expect(parsearDetalleMozo({'id': 'q', 'items': []}).tipoEntrega, 'mesa');
    expect(parsearDetalleMozo({'id': 'q', 'items': []}).delivery, null);

    final llevar = Pedido(
      id: 'l',
      numeroPedido: '1',
      mesaNumero: 0,
      tipoPedido: 'llevar',
      fechaPedido: DateTime(2026),
    );
    expect(llevar.ubicacion, 'Para llevar');
  });

  test('una promoción pedida vuelve con sus componentes y su precio', () {
    promociones
      ..clear()
      ..add(const Promocion(id: 'pr-1', nombre: 'Combo del día'));
    addTearDown(promociones.clear);
    final r = parsearDetalleMozo({
      'id': 'p',
      'items': [
        {
          'id': 'd-1',
          'version': 1,
          'tipo_item': 'promocion',
          'promocion_id': 'pr-1',
          'nombre': 'Combo del día',
          'estado': 'pendiente',
          'cantidad': 2,
          'precio_unitario': 20.0,
          'total_fila': 40.0,
          'componentes': [
            {
              'id': 'c-1',
              'componente_id': 'k-1',
              'opcion_id': 'o-1',
              'carta_id': 'x-1',
              'nombre': 'Tacacho',
              'cantidad': 1,
              'total_componente': 14.0,
            },
            {
              'id': 'c-2',
              'componente_id': 'k-2',
              'opcion_id': 'o-2',
              'carta_id': 'x-2',
              'nombre': 'Jugo',
              'cantidad': 1,
              'total_componente': 6.0,
            },
          ],
        },
      ],
    });
    final l = r.lineas.single;
    expect(esLineaPromocion(l), true);
    expect(l.promocion?.nombre, 'Combo del día');
    expect(l.componentes.map((c) => c.nombre), ['Tacacho', 'Jugo']);
    expect(l.precioTotalLinea, 40);
  });
}

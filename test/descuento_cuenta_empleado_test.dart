import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/pagos_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/services/pedido_service.dart';
import 'package:frontend_bijao/utils/ticket_texto.dart';

// Pedido de empleado con descuento del 100%: el administrador debe ver la
// cuenta en S/ 0.00 (no a precio completo), y los tickets dicen "consumo de
// empleado" sin repetir la nota con el nombre.
Pedido _pedido({String? notas}) => Pedido(
  id: 'p13',
  numeroPedido: '0013',
  mesaNumero: 0,
  tipoPedido: 'empleado',
  estado: 'servido',
  fechaPedido: DateTime(2026, 11, 11, 16, 44),
  usuarioId: 'u1',
  esEmpleado: true,
  notas: notas,
);

const _agua = PedidoLine(
  id: 'l1',
  cartaId: 'c1',
  nombrePlato: 'Agua',
  cantidad: 1,
  modificadores: [],
  presentacion: null,
  promocion: null,
  comentario: null,
  precioUnitario: 4,
  descuentoAplicado: 0,
  precioTotalLinea: 4,
);

String _texto(List<LineaTicket> l) => l.map((x) => x.texto).join('\n');

void main() {
  tearDown(() {
    pedidos.clear();
    detallesPorPedido.clear();
  });

  group('descuentos de la cuenta que trae /api/pedidos', () {
    test('uno de toda la cuenta queda como línea negativa', () {
      final lineas = lineasDeDescuentoDeCuenta([
        {'id': 'd1', 'detalle_id': null, 'motivo': 'Empleado', 'monto': 4.0},
      ]);
      expect(lineas.length, 1);
      expect(lineas.first.nombrePlato, 'Descuento: Empleado');
      expect(lineas.first.precioTotalLinea, -4.0);
      expect(lineas.first.cartaId, cartaIdAjuste);
    });

    test('los de una línea, los de monto 0 y un valor inválido no entran', () {
      expect(
        lineasDeDescuentoDeCuenta([
          {'id': 'd1', 'detalle_id': 'l1', 'motivo': 'Promo', 'monto': 2.0},
          {'id': 'd2', 'detalle_id': null, 'motivo': 'Nada', 'monto': 0},
        ]),
        isEmpty,
      );
      expect(lineasDeDescuentoDeCuenta(null), isEmpty);
      expect(lineasDeDescuentoDeCuenta('algo'), isEmpty);
    });

    test('con el descuento, el total y lo que falta quedan en 0.00', () {
      final p = _pedido();
      pedidos.add(p);
      detallesPorPedido[p.id] = [
        _agua,
        ...lineasDeDescuentoDeCuenta([
          {'id': 'd1', 'detalle_id': null, 'motivo': 'Empleado', 'monto': 4.0},
        ]),
      ];
      expect(totalDePedido(p.id), 0.0);
      expect(faltaPorPagarDePedido(p.id), 0.0);
    });

    test('sin ese dato, la cuenta se vería a precio completo (el error)', () {
      final p = _pedido();
      pedidos.add(p);
      detallesPorPedido[p.id] = [_agua];
      expect(totalDePedido(p.id), 4.0);
      expect(faltaPorPagarDePedido(p.id), 4.0);
    });
  });

  group('vista previa de familia y de empleado con delivery', () {
    const sede = (
      nombre: 'RESTAURANTE BIJAO',
      direccion: 'Av. Principal 123',
      telefono: '',
      ruc: '2012',
    );

    Pedido conDelivery({required bool empleado}) => Pedido(
      id: 'p17',
      numeroPedido: '0017',
      mesaNumero: 0,
      tipoPedido: 'delivery',
      estado: 'servido',
      fechaPedido: DateTime(2026, 11, 11, 17, 19),
      usuarioId: 'u1',
      esEmpleado: empleado,
      costoDelivery: 7,
      notas: 'Cliente: Alexis 2',
    );

    void familia(Pedido p) {
      pedidos.add(p);
      detallesPorPedido[p.id] = [
        _agua,
        ...lineasDeDescuentoDeCuenta([
          {
            'id': 'd1',
            'detalle_id': null,
            'motivo': 'Cuenta cero',
            'monto': 4.0,
          },
        ]),
      ];
    }

    test('familia con delivery: comanda, cuenta y vista previa en vivo', () {
      final p = conDelivery(empleado: false);
      familia(p);
      // El cargo de delivery es una línea más de la cuenta.
      detallesPorPedido[p.id]!.add(
        const PedidoLine(
          id: 'delivery-p17',
          cartaId: cartaIdCargoDelivery,
          nombrePlato: 'Cargo por delivery',
          cantidad: 1,
          modificadores: [],
          presentacion: null,
          promocion: null,
          comentario: null,
          precioUnitario: 7,
          descuentoAplicado: 0,
          precioTotalLinea: 7,
        ),
      );
      final lineas = detallesPorPedido[p.id]!;
      // 4.00 de comida − 4.00 de descuento + 7.00 de delivery = 7.00 (no 14.00).
      expect(totalDePedido(p.id), 7.0);
      expect(
        _texto(ticketComanda(pedido: p, lineas: lineas, mozo: 'Alexis')),
        contains('TIPO: CONSUMO FAMILIA (DELIVERY)'),
      );
      expect(
        _texto(
          ticketBoleta(pedido: p, lineas: lineas, mozo: 'Alexis', sede: sede),
        ),
        contains('TIPO: CONSUMO FAMILIA (DELIVERY)'),
      );
      expect(
        _texto(
          ticketComprobante(
            tipo: 'ticket_venta',
            pedido: p,
            lineas: lineas,
            mozo: 'Alexis',
            sede: sede,
          ),
        ),
        contains('TIPO: CONSUMO FAMILIA (DELIVERY)'),
      );
    });

    test('empleado con delivery', () {
      final p = conDelivery(empleado: true);
      pedidos.add(p);
      detallesPorPedido[p.id] = [_agua];
      expect(
        _texto(ticketComanda(pedido: p, lineas: [_agua], mozo: 'Alexis')),
        contains('TIPO: CONSUMO DE EMPLEADO (DELIVERY)'),
      );
    });

    test('un pedido normal con delivery no cambia', () {
      final p = conDelivery(empleado: false);
      pedidos.add(p);
      detallesPorPedido[p.id] = [_agua];
      expect(etiquetaConsumoEspecial(p), isNull);
      expect(
        _texto(ticketComanda(pedido: p, lineas: [_agua], mozo: 'Alexis')),
        contains('TIPO: >> DELIVERY <<'),
      );
    });

    test('familia sin delivery ni para llevar: solo el consumo', () {
      final p = Pedido(
        id: 'p18',
        numeroPedido: '0018',
        mesaNumero: 4,
        tipoPedido: 'mesa',
        estado: 'servido',
        fechaPedido: DateTime(2026, 11, 11, 18),
        usuarioId: 'u1',
      );
      familia(p);
      expect(etiquetaConsumoEspecial(p), 'CONSUMO FAMILIA');
    });
  });

  group('vista previa de un pedido de empleado', () {
    test('la comanda dice consumo de empleado y no repite el cliente', () {
      final texto = _texto(
        ticketComanda(
          pedido: _pedido(notas: 'Cliente: ana'),
          lineas: [_agua],
          mozo: 'manolo',
        ),
      );
      expect(texto, contains('TIPO: CONSUMO DE EMPLEADO'));
      expect(texto, isNot(contains('NOTA PEDIDO')));
      expect(texto, isNot(contains('Cliente: ana')));
    });

    test('las notas reales del pedido se conservan', () {
      final texto = _texto(
        ticketComanda(
          pedido: _pedido(notas: 'Cliente: ana\nSin ají'),
          lineas: [_agua],
          mozo: 'manolo',
        ),
      );
      expect(texto, contains('NOTA PEDIDO: Sin ají'));
    });

    test('la cuenta marca "CONSUMO DE EMPLEADO"', () {
      const sede = (
        nombre: 'RESTAURANTE BIJAO',
        direccion: 'Av. Principal 123',
        telefono: '',
        ruc: '2012',
      );
      final texto = _texto(
        ticketBoleta(
          pedido: _pedido(notas: 'Cliente: ana'),
          lineas: [_agua],
          mozo: 'manolo',
          sede: sede,
        ),
      );
      expect(texto, contains('CONSUMO DE EMPLEADO'));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/pedido.dart';

Pedido _p(String id, String estado, DateTime fecha) => Pedido(
  id: id,
  numeroPedido: id.substring(0, 4),
  mesaNumero: 0,
  tipoPedido: 'llevar',
  estado: estado,
  fechaPedido: fecha,
  usuarioId: 'u1',
);

void main() {
  setUp(() {
    pedidos.clear();
    detallesPorPedido.clear();
    idsDeOtrosDias.clear();
  });

  test('consultar un día pasado no quita los pedidos activos de hoy', () {
    final hoy = _p('aaaa-hoy', 'servido', DateTime(2026, 11, 12, 13));
    sincronizarPedidosDesdeServidor([hoy], {});

    final ayer = _p('bbbb-ayer', 'pagado', DateTime(2026, 11, 8, 13));
    fusionarPedidosDeOtroDia([ayer], {'bbbb-ayer': const []});

    expect(pedidos.map((p) => p.id), containsAll(['aaaa-hoy', 'bbbb-ayer']));
    expect(detallesPorPedido.containsKey('bbbb-ayer'), isTrue);
  });

  test('una recarga normal conserva los pedidos del día consultado', () {
    final hoy = _p('aaaa-hoy', 'servido', DateTime(2026, 11, 12, 13));
    sincronizarPedidosDesdeServidor([hoy], {});
    final ayer = _p('bbbb-ayer', 'pagado', DateTime(2026, 11, 8, 13));
    fusionarPedidosDeOtroDia([ayer], {'bbbb-ayer': const []});

    // El servidor solo trae lo activo y lo de hoy.
    sincronizarPedidosDesdeServidor([hoy], {});

    expect(pedidos.map((p) => p.id), containsAll(['aaaa-hoy', 'bbbb-ayer']));
    expect(detallesPorPedido.containsKey('bbbb-ayer'), isTrue);
  });

  test('un pedido que ya está en la lista no se reemplaza', () {
    final hoy = _p('aaaa-hoy', 'servido', DateTime(2026, 11, 12, 13));
    sincronizarPedidosDesdeServidor([hoy], {});

    fusionarPedidosDeOtroDia([
      _p('aaaa-hoy', 'pagado', DateTime(2026, 11, 12, 13)),
    ], {});

    expect(pedidos.length, 1);
    expect(pedidos.single.estado, 'servido');
  });
}

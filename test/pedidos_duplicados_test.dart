import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/mesas_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/mesa.dart';
import 'package:frontend_bijao/models/pedido.dart';

Pedido _pedido(String id, int mesa) => Pedido(
  id: id,
  numeroPedido: '7afb',
  mesaNumero: mesa,
  estado: 'pendiente',
  tipoPedido: 'mesa',
  fechaPedido: DateTime(2026, 10, 29, 10, 28),
);

void main() {
  tearDown(() {
    pedidos.clear();
    detallesPorPedido.clear();
    mesas.clear();
  });

  test('un pedido que cambió de mesa llega dos veces y queda una sola', () {
    mesas
      ..clear()
      ..addAll(const [
        Mesa(id: 'm6', numero: 6, estado: 'disponible'),
        Mesa(id: 'm7', numero: 7, estado: 'ocupada'),
      ]);
    sincronizarPedidosDesdeServidor([
      _pedido('p1', 6),
      _pedido('p1', 7),
      _pedido('p2', 3),
    ], {});
    expect(pedidos.length, 2);
    // Se queda con la fila de la mesa que hoy está ocupada.
    expect(pedidos.firstWhere((p) => p.id == 'p1').mesaNumero, 7);
  });

  test('el orden de las filas no cambia el resultado', () {
    mesas
      ..clear()
      ..addAll(const [
        Mesa(id: 'm6', numero: 6, estado: 'disponible'),
        Mesa(id: 'm7', numero: 7, estado: 'ocupada'),
      ]);
    sincronizarPedidosDesdeServidor([_pedido('p1', 7), _pedido('p1', 6)], {});
    expect(pedidos.single.mesaNumero, 7);
  });
}

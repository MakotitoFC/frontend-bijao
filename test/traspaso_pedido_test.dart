import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/traspasos_store.dart';
import 'package:frontend_bijao/models/traspaso_pedido.dart';

TraspasoPedido _t(
  String id,
  String pedido,
  String origen,
  String destino, [
  String estado = 'pendiente',
]) => TraspasoPedido(
  id: id,
  pedidoId: pedido,
  origenId: origen,
  origenNombre: 'Origen $origen',
  destinoId: destino,
  destinoNombre: 'Destino $destino',
  estado: estado,
);

void main() {
  tearDown(() => reemplazarTraspasos(const []));

  test('lee la solicitud con los nombres que manda el servidor', () {
    final t = TraspasoPedido.fromJson({
      'id': 't1',
      'pedido_id': 'p1',
      'pedido_numero': '76e3',
      'mozo_origen_id': 'a',
      'mozo_origen_nombre': 'Ana',
      'mozo_destino_id': 'b',
      'mozo_destino_nombre': 'Beto',
      'estado': 'pendiente',
    });
    expect(t.pendiente, true);
    expect(t.origenNombre, 'Ana');
    expect(t.destinoNombre, 'Beto');
    expect(t.pedidoNumero, '76e3');
  });

  test('solo quedan las pendientes', () {
    reemplazarTraspasos([
      _t('1', 'p1', 'a', 'b'),
      _t('2', 'p2', 'a', 'c', 'rechazado'),
      _t('3', 'p3', 'a', 'c', 'aceptado'),
    ]);
    expect(traspasosPendientes.map((t) => t.id), ['1']);
  });

  test('un pedido tiene a lo sumo una solicitud pendiente a la vista', () {
    reemplazarTraspasos([_t('1', 'p1', 'a', 'b')]);
    expect(traspasoPendienteDe('p1')?.destinoNombre, 'Destino b');
    expect(traspasoPendienteDe('p2'), isNull);
  });

  test('cada mozo ve solo lo que debe responder', () {
    reemplazarTraspasos([
      _t('1', 'p1', 'a', 'b'),
      _t('2', 'p2', 'a', 'c'),
      _t('3', 'p3', 'c', 'b'),
    ]);
    expect(traspasosPorResponder('b').map((t) => t.id), ['1', '3']);
    expect(traspasosPorResponder('c').map((t) => t.id), ['2']);
    expect(traspasosPorResponder('a'), isEmpty);
  });

  test('al cambiar la lista se avisa a la pantalla', () {
    final antes = traspasosRevision.value;
    reemplazarTraspasos([_t('1', 'p1', 'a', 'b')]);
    expect(traspasosRevision.value, antes + 1);
  });
}

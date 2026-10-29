import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/pagos_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/services/pedido_mozo_mapper.dart';

Map<String, dynamic> _item(
  String id,
  String nombre,
  double precio, {
  String estado = 'pendiente',
  List<Map<String, dynamic>> hijos = const [],
}) => {
  'id': id,
  'nombre': nombre,
  'cantidad': 1,
  'precio_unitario': precio,
  'total_fila': precio,
  'estado': estado,
  'tipo_item': 'plato',
  'version': 1,
  'hijos': hijos,
};

void main() {
  tearDown(() {
    detallesPorPedido.clear();
    lineasAnuladasPorPedido.clear();
  });

  test('las líneas anuladas se apartan y no suman en la cuenta', () {
    final d = parsearDetalleMozo({
      'id': 'p1',
      'items': [
        _item('a', 'Chaufa nuevo', 40),
        _item('b', 'Chaufa viejo', 35, estado: 'anulado'),
        _item('c', 'Táper viejo', 5, estado: 'devuelto'),
      ],
    });
    expect(d.lineas.map((l) => l.nombrePlato), ['Chaufa nuevo']);
    expect(d.anuladas.map((l) => l.nombrePlato), [
      'Chaufa viejo',
      'Táper viejo',
    ]);
    expect(d.anuladas.every(lineaAnulada), true);

    detallesPorPedido['p1'] = d.lineas;
    lineasAnuladasPorPedido['p1'] = d.anuladas;
    // El total y el saldo salen solo de lo vigente.
    expect(totalDePedido('p1'), 40);
    expect(saldoPendienteDePedido('p1'), 40);
  });

  test('una línea anulada dentro de otra también se aparta', () {
    final d = parsearDetalleMozo({
      'id': 'p2',
      'items': [
        _item(
          'a',
          'Plato',
          20,
          hijos: [_item('h', 'Extra quitado', 3, estado: 'anulado')],
        ),
      ],
    });
    expect(d.lineas.length, 1);
    expect(d.anuladas.single.nombrePlato, 'Extra quitado');
  });
}

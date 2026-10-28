import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/services/pedido_mozo_mapper.dart';

const _carta = '0190f3a0-7b1e-7c3a-9d4e-1a2b3c4d5e6f';

PedidoLine _linea({int cantidad = 2, double precio = 15}) => PedidoLine(
  id: 'l1',
  cartaId: _carta,
  nombrePlato: 'Lomo saltado',
  cantidad: cantidad,
  modificadores: const [],
  presentacion: null,
  promocion: null,
  comentario: null,
  precioUnitario: precio,
  descuentoAplicado: 0,
  precioTotalLinea: precio * cantidad,
);

void main() {
  test('el precio a medida reemplaza al de la carta y recalcula el total', () {
    final l = _linea().conPrecio(8.5);
    expect(l.precioUnitario, 8.5);
    expect(l.precioTotalLinea, 17);
    expect(l.cantidad, 2);
    expect(l.descuentoAplicado, 0);
  });

  test('en un pedido de personal cada plato viaja con su precio', () {
    final cuerpo = armarPedidoMozo(
      lineas: [_linea().conPrecio(8.5)],
      tipo: 'empleado',
    );
    final item = (cuerpo['items'] as List).single as Map<String, dynamic>;
    expect(cuerpo['tipo'], 'empleado');
    expect(item['carta_id'], _carta);
    expect(item['precio_personal'], 8.5);
  });

  test('en un pedido normal no se manda precio a medida', () {
    final cuerpo = armarPedidoMozo(lineas: [_linea()]);
    final item = (cuerpo['items'] as List).single as Map<String, dynamic>;
    expect(item.containsKey('precio_personal'), false);
  });
}

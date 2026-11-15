import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/models/movimiento_caja.dart';

// El movimiento de un cobro lleva el número diario del pedido ("#0017") para
// mostrarlo como etiqueta en Ingresos y salidas.
Map<String, dynamic> _json({String? numero}) => {
  'id': 'm1',
  'tipo': 'I',
  'categoria_movimiento_id': 'c1',
  'categoria_nombre': 'Cobro',
  'precio': 36,
  'medio_pago_id': 'mp1',
  'medio_pago_nombre': 'Efectivo',
  'fecha_movimiento': '2026-11-15T12:00:00Z',
  'estado': 'activo',
  'numero_pedido': ?numero,
};

void main() {
  test('lee el número del pedido sin el "#"', () {
    expect(MovimientoCaja.fromJson(_json(numero: '#0017')).numeroPedido, '0017');
  });

  test('sin número (rotura, alquiler, gasto) queda vacío', () {
    expect(MovimientoCaja.fromJson(_json()).numeroPedido, isNull);
    expect(MovimientoCaja.fromJson(_json(numero: '')).numeroPedido, isNull);
  });

  test('copyWith conserva el número', () {
    final m = MovimientoCaja.fromJson(_json(numero: '#0003'));
    expect(m.copyWith(anulado: true).numeroPedido, '0003');
  });
}

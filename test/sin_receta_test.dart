import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/models/inventario_movimiento.dart';
import 'package:frontend_bijao/utils/sin_receta.dart';

void main() {
  test('quita la palabra receta sin reemplazarla', () {
    expect(sinReceta('Consumo por receta'), 'Consumo');
    expect(sinReceta("Consumo receta 'AGUA' (1 u)"), "Consumo 'AGUA' (1 u)");
    expect(sinReceta("Reversión receta 'AGUA' (3 u)"), "Reversión 'AGUA' (3 u)");
    expect(sinReceta('Compra del día'), 'Compra del día');
    expect(sinReceta('Reversa de consumo'), 'Reversa de consumo');
  });

  test('los movimientos leídos del servidor no muestran "receta"', () {
    final m = InventarioMovimiento.fromJson({
      'tipo_movimiento_id': 'x',
      'tipo_movimiento_nombre': 'Consumo por receta',
      'cantidad': 1,
      'notas': "Consumo receta 'AGUA' (1 u)",
      'fecha': '2026-11-15T10:00:00Z',
    });
    expect(m.tipoMovimiento.tipoMovimiento, 'Consumo');
    expect(m.notas, "Consumo 'AGUA' (1 u)");
  });
}

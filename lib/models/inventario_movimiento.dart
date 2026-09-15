import 'tipo_movimiento.dart';

// Refleja la tabla `inventario_movimiento` (versión simplificada en memoria).
class InventarioMovimiento {
  final String productoInventarioId;
  final TipoMovimiento tipoMovimiento;
  final double cantidad;
  final String? notas;
  final DateTime fecha;

  const InventarioMovimiento({
    required this.productoInventarioId,
    required this.tipoMovimiento,
    required this.cantidad,
    this.notas,
    required this.fecha,
  });
}

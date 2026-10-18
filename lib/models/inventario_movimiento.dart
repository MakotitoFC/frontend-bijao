import '../data/catalogos_store.dart';
import 'tipo_movimiento.dart';

// Refleja la tabla `inventario_movimiento` (libro o kardex del inventario). La
// cantidad se guarda siempre como magnitud positiva; el tipo dice si suma o resta.
class InventarioMovimiento {
  final String id;
  final String productoInventarioId;
  final String? productoNombre;
  final TipoMovimiento tipoMovimiento;
  final double cantidad;
  final double costoUnitario;
  final double costoTotal;
  final String? usuarioNombre;
  final String? notas;
  final DateTime fecha;

  const InventarioMovimiento({
    this.id = '',
    required this.productoInventarioId,
    this.productoNombre,
    required this.tipoMovimiento,
    required this.cantidad,
    this.costoUnitario = 0,
    this.costoTotal = 0,
    this.usuarioNombre,
    this.notas,
    required this.fecha,
  });

  String get tipoMovimientoId => tipoMovimiento.id;

  factory InventarioMovimiento.fromJson(Map<String, dynamic> json) {
    final tipoId = json['tipo_movimiento_id']?.toString() ?? '';
    final nombre = json['tipo_movimiento_nombre']?.toString() ?? 'Movimiento';
    final cantidad = (json['cantidad'] as num?)?.toDouble() ?? 0;
    final conocido = tiposMovimiento.where((t) => t.id == tipoId).firstOrNull;
    final tipo =
        conocido ??
        TipoMovimiento(
          id: tipoId,
          codigo: json['tipo_movimiento_codigo']?.toString() ?? '',
          tipoMovimiento: nombre,
          // Si el tipo no está en el catálogo, el signo de la cantidad guardada
          // dice si sumó o restó.
          signo: cantidad >= 0 ? 1 : -1,
        );
    final fecha = DateTime.tryParse(json['fecha']?.toString() ?? '');
    return InventarioMovimiento(
      id: json['id']?.toString() ?? '',
      productoInventarioId: json['producto_inventario_id']?.toString() ?? '',
      productoNombre: json['producto_nombre']?.toString(),
      tipoMovimiento: tipo,
      cantidad: cantidad.abs(),
      costoUnitario: (json['costo_unitario'] as num?)?.toDouble() ?? 0,
      costoTotal: (json['costo_total'] as num?)?.toDouble() ?? 0,
      usuarioNombre: json['usuario_nombre']?.toString(),
      notas: json['notas']?.toString(),
      fecha: fecha?.toLocal() ?? DateTime.now(),
    );
  }
}

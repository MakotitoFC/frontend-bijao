// Refleja la tabla `promocion`.
class Promocion {
  final String id;
  final String nombre;
  final String? descripcion;
  final String tipo; // 'porcentaje' | 'monto'
  final double valor;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final bool activa;

  const Promocion({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.tipo,
    required this.valor,
    required this.fechaInicio,
    required this.fechaFin,
    this.activa = true,
  });

  String get etiqueta => tipo == 'porcentaje'
      ? '-${valor.toStringAsFixed(0)}%'
      : '-S/ ${valor.toStringAsFixed(2)}';
}

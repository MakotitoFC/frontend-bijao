// Refleja la tabla `compra`.
class Compra {
  final String id;
  final DateTime fechaCompra;
  final String proveedor;
  final double total;
  final String? notas;

  const Compra({
    required this.id,
    required this.fechaCompra,
    required this.proveedor,
    required this.total,
    this.notas,
  });
}

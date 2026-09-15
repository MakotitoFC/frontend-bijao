// Refleja la tabla `tipo_movimiento`. `esEntrada` no es una columna real:
// es una bandera solo de UI para saber si suma o resta del stock.
class TipoMovimiento {
  final int id;
  final String tipoMovimiento;
  final bool esEntrada;

  const TipoMovimiento({
    required this.id,
    required this.tipoMovimiento,
    required this.esEntrada,
  });
}

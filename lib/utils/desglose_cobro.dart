// Desglose del cobro que se muestra en el resumen de Pagar: cuánto es de la
// cuenta y cuánto de roturas o alquiler, de modo que las filas sumen el total.
//
// Con un solo medio de pago, la cuenta es el saldo y las roturas van aparte.
// "Por montos" (varios medios): lo que cubren las filas, menos lo que sobra
// (vuelto o propina), ya incluye las roturas. Mostrarlas como un monto aparte y
// dejar la cuenta con ese mismo total las contaba dos veces en pantalla.
({double cuenta, double roturas}) desgloseCuentaYRoturas({
  required bool porMontos,
  required double asignado,
  required double sobraAplicable,
  required double saldo,
  required double cargos,
}) {
  if (!porMontos) return (cuenta: saldo, roturas: cargos);
  final cubierto = asignado - sobraAplicable;
  final tope = cubierto < 0 ? 0.0 : cubierto;
  final roturas = cargos < tope ? cargos : tope;
  return (cuenta: cubierto - roturas, roturas: roturas);
}

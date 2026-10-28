// Cliente de la boleta o factura emitida de cada pedido (nombre y documento),
// para que el ticket de la cuenta no diga "CLIENTES VARIOS" cuando se emitió el
// comprobante a nombre de alguien. Vive en memoria de este dispositivo.
final Map<String, ({String nombre, String tipoDoc, String documento})>
clienteDeComprobantePorPedido = {};

// Guarda el cliente de un comprobante recién emitido. Los comprobantes sin
// nombre real ("CLIENTES VARIOS") no dejan nada.
void recordarClienteDeComprobante(
  String pedidoId, {
  required String nombre,
  required String tipoDoc,
  required String documento,
}) {
  final n = nombre.trim();
  if (pedidoId.isEmpty || n.isEmpty || n.toUpperCase() == 'CLIENTES VARIOS') {
    return;
  }
  clienteDeComprobantePorPedido[pedidoId] = (
    nombre: n,
    tipoDoc: tipoDoc,
    documento: documento.trim(),
  );
}

// "Juan Pérez (DNI 12345678)": cómo se ve el cliente en el ticket.
String? etiquetaClienteDeComprobante(String pedidoId) {
  final c = clienteDeComprobantePorPedido[pedidoId];
  if (c == null) return null;
  final etiquetaDoc = switch (c.tipoDoc) {
    '1' => 'DNI',
    '6' => 'RUC',
    _ => '',
  };
  final tieneDoc =
      etiquetaDoc.isNotEmpty &&
      c.documento.isNotEmpty &&
      c.documento != '00000000';
  return tieneDoc ? '${c.nombre} ($etiquetaDoc ${c.documento})' : c.nombre;
}

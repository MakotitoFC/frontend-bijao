import '../models/pedido.dart';

// Dirección que se manda al emitir un ticket de venta: la de entrega y, junto,
// el teléfono del cliente separado con " | " ("Av. Los Pinos 123 | Tel. 987654321").
// El ticket imprime ese campo en su línea de dirección, así el teléfono sale
// impreso sin que el servidor cambie. Solo para el ticket de venta (documento
// interno): en boletas y facturas la dirección es dato fiscal y no se mezcla.
// Devuelve null si el pedido no tiene ni dirección ni teléfono.
String? direccionConTelefono(Pedido pedido) {
  final direccion = (pedido.direccionDelivery ?? '').trim();
  final celular = (pedido.clienteCelular ?? '').trim();
  final telefono = celular.isEmpty ? '' : 'Tel. $celular';
  final partes = [
    if (direccion.isNotEmpty) direccion,
    if (telefono.isNotEmpty) telefono,
  ];
  return partes.isEmpty ? null : partes.join(' | ');
}

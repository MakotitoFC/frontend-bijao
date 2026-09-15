import 'carta_presentacion.dart';
import 'modificador.dart';
import 'promocion.dart';
import 'taper.dart';

// Línea del carrito en memoria; su forma corresponde a `pedidos_detalle`
// (+ `pedidos_detalle_modificador`) que se enviará al backend más adelante.
class PedidoLine {
  final String id;
  final String cartaId;
  final String nombrePlato;
  final int cantidad;
  final List<Modificador> modificadores;
  final Taper? taper;
  final CartaPresentacion? presentacion;
  final Promocion? promocion;
  final String? comentario;
  final double precioUnitario; // base + modificadores + taper, por unidad
  final double descuentoAplicado; // total de la línea
  final double precioTotalLinea; // total final de la línea (con descuento)

  const PedidoLine({
    required this.id,
    required this.cartaId,
    required this.nombrePlato,
    required this.cantidad,
    required this.modificadores,
    required this.presentacion,
    required this.taper,
    required this.promocion,
    required this.comentario,
    required this.precioUnitario,
    required this.descuentoAplicado,
    required this.precioTotalLinea,
  });
}

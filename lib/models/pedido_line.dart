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
  // Estado de la línea (pedidos_detalle.estado): null = normal, 'incidencia'
  // = tiene una devolución/reclamo reportado (ver incidencias_store.dart).
  final String? estado;

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
    this.estado,
  });

  PedidoLine copyWith({String? estado}) => PedidoLine(
    id: id,
    cartaId: cartaId,
    nombrePlato: nombrePlato,
    cantidad: cantidad,
    modificadores: modificadores,
    presentacion: presentacion,
    taper: taper,
    promocion: promocion,
    comentario: comentario,
    precioUnitario: precioUnitario,
    descuentoAplicado: descuentoAplicado,
    precioTotalLinea: precioTotalLinea,
    estado: estado ?? this.estado,
  );
}

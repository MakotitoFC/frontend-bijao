import 'carta_presentacion.dart';
import 'modificador.dart';
import 'promocion.dart';

// Línea del carrito en memoria; su forma corresponde a `pedidos_detalle`
// (+ `pedidos_detalle_modificador`) que se enviará al backend más adelante.
class PedidoLine {
  final String id;
  final String cartaId;
  final String nombrePlato;
  final int cantidad;
  final List<Modificador> modificadores;
  final CartaPresentacion? presentacion;
  final Promocion? promocion;
  final String? comentario;
  final double precioUnitario; // base + modificadores, por unidad
  final double descuentoAplicado; // total de la línea
  final double precioTotalLinea; // total final de la línea (con descuento)
  final String tipoEntrega; // 'mesa', 'llevar', 'delivery'
  final bool aplicaTaper;
  final String? taperId;
  final double precioTaper;
  final bool esLibre;
  final String? nombreLibre;
  final String? descripcionLibre;
  final double precioBase;
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
    required this.promocion,
    required this.comentario,
    required this.precioUnitario,
    required this.descuentoAplicado,
    required this.precioTotalLinea,
    this.tipoEntrega = 'mesa',
    this.aplicaTaper = false,
    this.taperId,
    this.precioTaper = 0.0,
    this.esLibre = false,
    this.nombreLibre,
    this.descripcionLibre,
    this.precioBase = 0.0,
    this.estado,
  });

  factory PedidoLine.fromJson(Map<String, dynamic> json) {
    final cant = (json['cantidad'] as num?)?.toInt() ?? 1;
    final pUnit = (json['precio_base'] as num?)?.toDouble() ??
        (json['precio'] as num?)?.toDouble() ??
        0.0;
    final pTotal = (json['precio'] as num?)?.toDouble() ?? (pUnit * cant);
    final desc = (json['descuento_aplicado'] as num?)?.toDouble() ?? 0.0;

    return PedidoLine(
      id: json['id']?.toString() ?? '',
      cartaId: json['carta_id']?.toString() ?? '',
      nombrePlato: json['plato_nombre']?.toString() ??
          json['nombre_libre']?.toString() ??
          'Plato',
      cantidad: cant,
      modificadores: const [],
      presentacion: null,
      promocion: null,
      comentario: json['comentarios']?.toString(),
      precioUnitario: pUnit,
      descuentoAplicado: desc,
      precioTotalLinea: pTotal,
      tipoEntrega: json['tipo_entrega']?.toString() ?? 'mesa',
      aplicaTaper: json['aplica_taper'] == true,
      taperId: json['taper_id']?.toString(),
      precioTaper: (json['precio_taper'] as num?)?.toDouble() ?? 0.0,
      esLibre: json['es_libre'] == true,
      nombreLibre: json['nombre_libre']?.toString(),
      descripcionLibre: json['descripcion_libre']?.toString(),
      precioBase: pUnit,
      estado: json['estado']?.toString(),
    );
  }

  // Nueva cantidad: reescala el descuento de la línea y su total.
  PedidoLine conCantidad(int nueva) {
    final desc = cantidad == 0 ? 0.0 : descuentoAplicado / cantidad * nueva;
    return PedidoLine(
      id: id,
      cartaId: cartaId,
      nombrePlato: nombrePlato,
      cantidad: nueva,
      modificadores: modificadores,
      presentacion: presentacion,
      promocion: promocion,
      comentario: comentario,
      precioUnitario: precioUnitario,
      descuentoAplicado: desc,
      precioTotalLinea: precioUnitario * nueva - desc,
      tipoEntrega: tipoEntrega,
      aplicaTaper: aplicaTaper,
      taperId: taperId,
      precioTaper: precioTaper,
      esLibre: esLibre,
      nombreLibre: nombreLibre,
      descripcionLibre: descripcionLibre,
      precioBase: precioBase,
      estado: estado,
    );
  }

  PedidoLine conComentario(String? nuevo) => PedidoLine(
    id: id,
    cartaId: cartaId,
    nombrePlato: nombrePlato,
    cantidad: cantidad,
    modificadores: modificadores,
    presentacion: presentacion,
    promocion: promocion,
    comentario: nuevo,
    precioUnitario: precioUnitario,
    descuentoAplicado: descuentoAplicado,
    precioTotalLinea: precioTotalLinea,
    tipoEntrega: tipoEntrega,
    aplicaTaper: aplicaTaper,
    taperId: taperId,
    precioTaper: precioTaper,
    esLibre: esLibre,
    nombreLibre: nombreLibre,
    descripcionLibre: descripcionLibre,
    precioBase: precioBase,
    estado: estado,
  );

  PedidoLine copyWith({String? estado}) => PedidoLine(
    id: id,
    cartaId: cartaId,
    nombrePlato: nombrePlato,
    cantidad: cantidad,
    modificadores: modificadores,
    presentacion: presentacion,
    promocion: promocion,
    comentario: comentario,
    precioUnitario: precioUnitario,
    descuentoAplicado: descuentoAplicado,
    precioTotalLinea: precioTotalLinea,
    tipoEntrega: tipoEntrega,
    aplicaTaper: aplicaTaper,
    taperId: taperId,
    precioTaper: precioTaper,
    esLibre: esLibre,
    nombreLibre: nombreLibre,
    descripcionLibre: descripcionLibre,
    precioBase: precioBase,
    estado: estado ?? this.estado,
  );
}

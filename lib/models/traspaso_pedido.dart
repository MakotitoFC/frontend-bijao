// Solicitud para pasar un pedido de un mozo a otro. El mozo destino la acepta
// (el pedido pasa a ser suyo) o la rechaza (el pedido sigue con el de origen).
class TraspasoPedido {
  final String id;
  final String pedidoId;
  final String? pedidoNumero;
  final String? ubicacion;
  final String origenId;
  final String origenNombre;
  final String destinoId;
  final String destinoNombre;
  // 'pendiente' | 'aceptado' | 'rechazado' | 'cancelado'
  final String estado;
  final DateTime? creado;

  const TraspasoPedido({
    required this.id,
    required this.pedidoId,
    this.pedidoNumero,
    this.ubicacion,
    required this.origenId,
    required this.origenNombre,
    required this.destinoId,
    required this.destinoNombre,
    this.estado = 'pendiente',
    this.creado,
  });

  bool get pendiente => estado == 'pendiente';

  factory TraspasoPedido.fromJson(Map<String, dynamic> json) => TraspasoPedido(
    id: json['id']?.toString() ?? '',
    pedidoId: json['pedido_id']?.toString() ?? '',
    pedidoNumero: (json['pedido_numero'] ?? json['codigo_orden'])?.toString(),
    ubicacion: json['ubicacion']?.toString(),
    origenId: (json['mozo_origen_id'] ?? json['origen_id'])?.toString() ?? '',
    origenNombre:
        (json['mozo_origen_nombre'] ?? json['origen_nombre'])?.toString() ?? '',
    destinoId:
        (json['mozo_destino_id'] ?? json['destino_id'])?.toString() ?? '',
    destinoNombre:
        (json['mozo_destino_nombre'] ?? json['destino_nombre'])?.toString() ??
        '',
    estado: json['estado']?.toString() ?? 'pendiente',
    creado: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal(),
  );
}

// Refleja la tabla `pedidos` (esquema real en Supabase). `mesaNumero` +
// `mesasUnidas` reemplazan el join real vía `mesa_pedido` (que sí admite
// varias mesas por pedido, por eso `mesasUnidas`) mientras no hay backend.
class Pedido {
  final String id;
  final String numeroPedido; // pedidos.numero_pedido
  final int mesaNumero;
  final List<int> mesasUnidas; // otras mesas unidas a esta, comparten cuenta
  final String estado; // 'pendiente' | 'preparando' | 'listo' | 'entregado' | 'cancelado' | 'anulado'
  final String tipoPedido; // 'llevar' | 'mesa' | 'delivery'
  final DateTime fechaPedido;
  final String? notas; // pedidos.notas
  final String? clienteNombre; // pedidos.cliente_nombre
  final String? clienteCelular; // pedidos.cliente_celular
  final String? direccionDelivery; // pedidos.direccion_delivery
  final DateTime? fechaFinalizacion; // pedidos.fecha_finalizacion
  final String? usuarioId; // pedidos.usuario_id (mesero que tomó el pedido)

  const Pedido({
    required this.id,
    required this.numeroPedido,
    required this.mesaNumero,
    this.mesasUnidas = const [],
    this.estado = 'pendiente',
    this.tipoPedido = 'mesa',
    required this.fechaPedido,
    this.notas,
    this.clienteNombre,
    this.clienteCelular,
    this.direccionDelivery,
    this.fechaFinalizacion,
    this.usuarioId,
  });

  List<int> get todasLasMesas => [mesaNumero, ...mesasUnidas];

  String get codigoCorto {
    if (id.length <= 6) return id;
    return id.substring(id.length - 6);
  }

  String get etiquetaEstado {
    switch (estado) {
      case 'pendiente':
        return 'Pendiente';
      case 'preparando':
        return 'En preparación';
      case 'listo':
        return 'Listo';
      case 'entregado':
        return 'Entregado';
      case 'cancelado':
        return 'Cancelado';
      case 'anulado':
        return 'Anulado';
      default:
        return estado;
    }
  }

  String get etiquetaTipoPedido {
    switch (tipoPedido) {
      case 'llevar':
        return 'Llevar';
      case 'delivery':
        return 'Delivery';
      default:
        return 'Mesa';
    }
  }

  // Al pasar a 'listo' o 'entregado' se fija la fecha de finalización (corta
  // el cronómetro del pedido).
  Pedido copyWith({String? estado}) {
    final nuevo = estado ?? this.estado;
    final finaliza = nuevo == 'listo' || nuevo == 'entregado';
    return Pedido(
      id: id,
      numeroPedido: numeroPedido,
      mesaNumero: mesaNumero,
      mesasUnidas: mesasUnidas,
      estado: nuevo,
      tipoPedido: tipoPedido,
      fechaPedido: fechaPedido,
      notas: notas,
      clienteNombre: clienteNombre,
      clienteCelular: clienteCelular,
      direccionDelivery: direccionDelivery,
      fechaFinalizacion:
          fechaFinalizacion ?? (finaliza ? DateTime.now() : null),
      usuarioId: usuarioId,
    );
  }
}

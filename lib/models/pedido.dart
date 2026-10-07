// Refleja la tabla `pedidos` (esquema real en Supabase). `mesaNumero` +
// `mesasUnidas` reemplazan el join real vía `mesa_pedido` (que sí admite
// varias mesas por pedido, por eso `mesasUnidas`) mientras no hay backend.
class Pedido {
  final String id;
  final String numeroPedido; // pedidos.numero_pedido
  final int mesaNumero;
  final List<int> mesasUnidas; // otras mesas unidas a esta, comparten cuenta
  final String estado; // 'pendiente' | 'preparando' | 'listo' | 'entregado' | 'cancelado' | 'anulado'
  final String tipoPedido; // 'mesa' | 'delivery'
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

  factory Pedido.fromJson(Map<String, dynamic> json) {
    DateTime fecha;
    if (json['created_at'] != null) {
      fecha = DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now();
    } else if (json['fecha_pedido'] != null) {
      final fStr = json['fecha_pedido'].toString();
      final hStr = json['hora_inicio']?.toString() ?? '00:00:00';
      fecha = DateTime.tryParse('${fStr}T$hStr') ?? DateTime.now();
    } else {
      fecha = DateTime.now();
    }

    final rawEstado = (json['estado']?.toString() ?? 'pendiente').toLowerCase();
    final estadoNormalizado = rawEstado == 'pedido' ? 'pendiente' : rawEstado;

    return Pedido(
      id: json['id']?.toString() ?? '',
      numeroPedido: json['numero_pedido']?.toString() ??
          (json['id'] != null && json['id'].toString().length >= 4
              ? json['id'].toString().substring(0, 4)
              : '0000'),
      mesaNumero: (json['mesa_numero'] as num?)?.toInt() ?? 0,
      mesasUnidas: const [],
      estado: estadoNormalizado,
      tipoPedido: json['tipo']?.toString() ?? 'mesa',
      fechaPedido: fecha,
      notas: json['comentarios']?.toString(),
      clienteNombre: json['cliente_nombre']?.toString() ?? json['mozo_nombre']?.toString(),
      clienteCelular: json['cliente_celular']?.toString(),
      direccionDelivery: json['direccion_delivery']?.toString(),
      usuarioId: json['usuario_id']?.toString(),
    );
  }

  List<int> get todasLasMesas => [mesaNumero, ...mesasUnidas];

  String get codigoCorto {
    if (id.length <= 6) return id;
    return id.substring(id.length - 6);
  }

  String get etiquetaEstado {
    switch (estado.toLowerCase()) {
      case 'pendiente':
      case 'pedido':
        return 'Pendiente';
      case 'servido':
        return 'Servido';
      case 'en_camino':
        return 'En camino';
      case 'entregado':
        return 'Entregado';
      case 'en_cuenta':
        return 'En cuenta';
      case 'pagado':
        return 'Pagado';
      case 'devuelto':
        return 'Devuelto';
      case 'anulado':
        return 'Anulado';
      case 'cancelado':
        return 'Cancelado';
      case 'preparando':
        return 'En preparación';
      case 'listo':
        return 'Listo';
      default:
        return estado;
    }
  }

  String get etiquetaTipoPedido {
    switch (tipoPedido.toLowerCase()) {
      case 'delivery':
        return 'Delivery';
      case 'empleado':
        return 'Empleado';
      default:
        return 'Mesa';
    }
  }

  // Edición de los datos del pedido (cliente, contacto, dirección y notas).
  Pedido conDatos({
    required String? clienteNombre,
    required String? clienteCelular,
    required String? direccionDelivery,
    required String? notas,
  }) => Pedido(
    id: id,
    numeroPedido: numeroPedido,
    mesaNumero: mesaNumero,
    mesasUnidas: mesasUnidas,
    estado: estado,
    tipoPedido: tipoPedido,
    fechaPedido: fechaPedido,
    notas: notas,
    clienteNombre: clienteNombre,
    clienteCelular: clienteCelular,
    direccionDelivery: direccionDelivery,
    fechaFinalizacion: fechaFinalizacion,
    usuarioId: usuarioId,
  );

  // Al pasar a 'listo' o 'entregado' se fija la fecha de finalización (corta
  // el cronómetro del pedido).
  Pedido copyWith({
    String? id,
    String? numeroPedido,
    int? mesaNumero,
    List<int>? mesasUnidas,
    String? estado,
    String? tipoPedido,
    DateTime? fechaPedido,
    String? notas,
    String? clienteNombre,
    String? clienteCelular,
    String? direccionDelivery,
    DateTime? fechaFinalizacion,
    String? usuarioId,
  }) {
    final nuevo = estado ?? this.estado;
    final finaliza = nuevo == 'listo' || nuevo == 'entregado';
    return Pedido(
      id: id ?? this.id,
      numeroPedido: numeroPedido ?? this.numeroPedido,
      mesaNumero: mesaNumero ?? this.mesaNumero,
      mesasUnidas: mesasUnidas ?? this.mesasUnidas,
      estado: nuevo,
      tipoPedido: tipoPedido ?? this.tipoPedido,
      fechaPedido: fechaPedido ?? this.fechaPedido,
      notas: notas ?? this.notas,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteCelular: clienteCelular ?? this.clienteCelular,
      direccionDelivery: direccionDelivery ?? this.direccionDelivery,
      fechaFinalizacion: fechaFinalizacion ?? (finaliza ? DateTime.now() : this.fechaFinalizacion),
      usuarioId: usuarioId ?? this.usuarioId,
    );
  }
}

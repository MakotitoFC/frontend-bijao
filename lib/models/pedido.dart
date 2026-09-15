// Refleja la tabla `pedidos`. `mesaNumero` + `mesasUnidas` reemplazan el
// join real vía `mesa_pedido` (que sí admite varias mesas por pedido, por
// eso `mesasUnidas`) mientras no hay backend.
class Pedido {
  final String id;
  final int mesaNumero;
  final List<int> mesasUnidas; // otras mesas unidas a esta, comparten cuenta
  final String estado; // 'pendiente' | 'en_preparacion' | 'listo' | 'entregado'
  final String tipoPedido; // 'llevar' | 'mesa' | 'delivery'
  final DateTime fechaPedido;
  final String? comentarios;

  const Pedido({
    required this.id,
    required this.mesaNumero,
    this.mesasUnidas = const [],
    this.estado = 'pendiente',
    this.tipoPedido = 'mesa',
    required this.fechaPedido,
    this.comentarios,
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
      case 'en_preparacion':
        return 'En preparación';
      case 'listo':
        return 'Listo';
      case 'entregado':
        return 'Entregado';
      case 'pagado':
        return 'Pagado';
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

  Pedido copyWith({String? estado}) => Pedido(
    id: id,
    mesaNumero: mesaNumero,
    mesasUnidas: mesasUnidas,
    estado: estado ?? this.estado,
    tipoPedido: tipoPedido,
    fechaPedido: fechaPedido,
    comentarios: comentarios,
  );
}

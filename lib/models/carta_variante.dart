import '../utils/json_num.dart';

// Refleja la tabla `carta_variante`: tamaños de un plato con precio propio
// (ej. pescado pequeño, mediano o grande). Los pesos mínimo y máximo son
// opcionales y sirven para sugerir la clasificación automática de una pieza.
class CartaVariante {
  final String id;
  final String cartaId;
  final String nombre;
  final double precioCliente;
  final double precioPersonal;
  final double? pesoMinKg;
  final double? pesoMaxKg;
  final bool estado;

  const CartaVariante({
    required this.id,
    required this.cartaId,
    required this.nombre,
    required this.precioCliente,
    required this.precioPersonal,
    this.pesoMinKg,
    this.pesoMaxKg,
    this.estado = true,
  });

  factory CartaVariante.fromJson(Map<String, dynamic> json) => CartaVariante(
    id: json['id']?.toString() ?? '',
    cartaId: json['carta_id']?.toString() ?? '',
    nombre: json['nombre']?.toString() ?? '',
    precioCliente: jsonDouble(json['precio_cliente']) ?? 0,
    precioPersonal: jsonDouble(json['precio_personal']) ?? 0,
    pesoMinKg: jsonDouble(json['peso_min_kg']),
    pesoMaxKg: jsonDouble(json['peso_max_kg']),
    estado: json['estado'] != false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'carta_id': cartaId,
    'nombre': nombre,
    'precio_cliente': precioCliente,
    'precio_personal': precioPersonal,
    'peso_min_kg': pesoMinKg,
    'peso_max_kg': pesoMaxKg,
    'estado': estado,
  };

  CartaVariante copyWith({
    String? id,
    String? cartaId,
    String? nombre,
    double? precioCliente,
    double? precioPersonal,
    double? pesoMinKg,
    double? pesoMaxKg,
    bool? estado,
  }) => CartaVariante(
    id: id ?? this.id,
    cartaId: cartaId ?? this.cartaId,
    nombre: nombre ?? this.nombre,
    precioCliente: precioCliente ?? this.precioCliente,
    precioPersonal: precioPersonal ?? this.precioPersonal,
    pesoMinKg: pesoMinKg ?? this.pesoMinKg,
    pesoMaxKg: pesoMaxKg ?? this.pesoMaxKg,
    estado: estado ?? this.estado,
  );
}

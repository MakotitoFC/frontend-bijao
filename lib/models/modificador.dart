import '../utils/json_num.dart';

// Refleja la tabla `modificador` en PostgreSQL.
class Modificador {
  final String id;
  final String cartaId;
  final String nombre;
  final String tipo; // 'ajuste' | 'adicional' | 'agregar' | 'quitar'
  final double precioAjuste;
  final bool estado;

  const Modificador({
    required this.id,
    required this.cartaId,
    required this.nombre,
    required this.tipo,
    required this.precioAjuste,
    this.estado = true,
  });

  factory Modificador.fromJson(Map<String, dynamic> json) {
    return Modificador(
      id: json['id'] as String,
      cartaId: json['carta_id'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      tipo: json['tipo'] as String? ?? 'ajuste',
      precioAjuste: jsonDouble(json['precio_ajuste']) ?? 0.0,
      estado: json['estado'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'carta_id': cartaId,
    'nombre': nombre,
    'tipo': tipo,
    'precio_ajuste': precioAjuste,
    'estado': estado,
  };
}

// Refleja la tabla `categoria_comida` en PostgreSQL.
class CategoriaComida {
  final String id;
  final String categoria;
  final int orden;
  final bool estado;
  final DateTime? creadoEn;

  const CategoriaComida({
    required this.id,
    required this.categoria,
    this.orden = 0,
    this.estado = true,
    this.creadoEn,
  });

  factory CategoriaComida.fromJson(Map<String, dynamic> json) {
    return CategoriaComida(
      id: json['id'] as String,
      categoria: json['categoria'] as String? ?? '',
      orden: json['orden'] as int? ?? 0,
      estado: json['estado'] as bool? ?? true,
      creadoEn: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoria': categoria,
    'estado': estado,
  };
}

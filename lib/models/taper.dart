class Taper {
  final String id;
  final String nombre;
  final double precio;
  final bool estado;
  final String? sedeId;

  const Taper({
    required this.id,
    required this.nombre,
    required this.precio,
    this.estado = true,
    this.sedeId,
  });

  factory Taper.fromJson(Map<String, dynamic> json) {
    return Taper(
      id: json['id'] as String,
      nombre: json['nombre'] as String? ?? '',
      precio: (json['precio'] is num) ? (json['precio'] as num).toDouble() : 0.0,
      estado: json['estado'] as bool? ?? true,
      sedeId: json['sede_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'precio': precio,
    'estado': estado,
    if (sedeId != null) 'sede_id': sedeId,
  };
}

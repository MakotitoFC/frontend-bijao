class Zona {
  final String id;
  final String zona;
  final bool estado;
  final String? sedeId;

  const Zona({
    required this.id,
    required this.zona,
    this.estado = true,
    this.sedeId,
  });

  factory Zona.fromJson(Map<String, dynamic> json) => Zona(
    id: json['id'] as String,
    zona: json['zona'] as String? ?? '',
    estado: json['estado'] as bool? ?? true,
    sedeId: json['sede_id'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'zona': zona,
    'estado': estado,
    if (sedeId != null) 'sede_id': sedeId,
  };

  Zona copyWith({String? id, String? zona, bool? estado, String? sedeId}) => Zona(
    id: id ?? this.id,
    zona: zona ?? this.zona,
    estado: estado ?? this.estado,
    sedeId: sedeId ?? this.sedeId,
  );
}

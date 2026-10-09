// Refleja la tabla `mesa` en PostgreSQL.
class Mesa {
  final String id;
  final int numero;
  final String estado; // 'disponible' | 'ocupada'
  final int capacidad;
  final String zonaId;
  final String zona;

  const Mesa({
    required this.id,
    required this.numero,
    required this.estado,
    this.capacidad = 0,
    this.zonaId = '',
    this.zona = 'Salón Principal',
  });

  bool get estaLibre => estado == 'disponible' || estado == 'libre';
  bool get estaOcupada => estado == 'ocupada';

  int get numeroSillas => capacidad;

  Mesa copyWith({String? estado, int? capacidad, String? zonaId, String? zona}) => Mesa(
    id: id,
    numero: numero,
    estado: estado ?? this.estado,
    capacidad: capacidad ?? this.capacidad,
    zonaId: zonaId ?? this.zonaId,
    zona: zona ?? this.zona,
  );

  factory Mesa.fromJson(Map<String, dynamic> json) {
    final rawEstado = (json['estado'] as String?)?.toLowerCase() ?? 'disponible';
    // 'reservada' ya no se maneja: una mesa con ese estado heredado se toma como libre.
    final estado = (rawEstado == 'libre' || rawEstado == 'reservada')
        ? 'disponible'
        : rawEstado;

    return Mesa(
      id: json['id'] as String,
      numero: json['numero'] as int? ?? 1,
      estado: estado,
      capacidad: json['numero_sillas'] as int? ?? json['capacidad'] as int? ?? 4,
      zonaId: json['zona_id'] as String? ?? '',
      zona: json['zona'] as String? ?? 'Salón Principal',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'numero': numero,
    'estado': (estado == 'libre') ? 'disponible' : estado,
    'numero_sillas': capacidad,
    if (zonaId.isNotEmpty) 'zona_id': zonaId,
  };
}

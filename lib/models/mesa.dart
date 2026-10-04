// Refleja la tabla `mesas`. `capacidad` (cantidad de clientes, define las
// sillas que se dibujan) y `zona` (agrupa el plano por ambiente) no existen
// en la BD todavía: capacidad 0 = automática, zona por defecto 'Principal'.
class Mesa {
  final String id;
  final int numero;
  final String estado; // 'libre' | 'ocupada'
  final int capacidad;
  final String zona;

  const Mesa({
    required this.id,
    required this.numero,
    required this.estado,
    this.capacidad = 0,
    this.zona = 'Principal',
  });

  Mesa copyWith({String? estado, int? capacidad, String? zona}) => Mesa(
    id: id,
    numero: numero,
    estado: estado ?? this.estado,
    capacidad: capacidad ?? this.capacidad,
    zona: zona ?? this.zona,
  );
}

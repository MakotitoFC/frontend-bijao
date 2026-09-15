// Refleja la tabla `mesa`.
class Mesa {
  final String id;
  final int numero;
  final String estado; // 'libre' | 'ocupada'

  const Mesa({required this.id, required this.numero, required this.estado});

  Mesa copyWith({String? estado}) =>
      Mesa(id: id, numero: numero, estado: estado ?? this.estado);
}

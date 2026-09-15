import '../models/mesa.dart';

// TODO: reemplazar por `mesa` real del servidor local cuando esté disponible.
final mockMesas = List.generate(
  8,
  (i) => Mesa(id: 'm${i + 1}', numero: i + 1, estado: 'libre'),
);

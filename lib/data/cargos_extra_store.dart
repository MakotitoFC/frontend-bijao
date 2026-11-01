// Cargos extra que se cobran al pagar un pedido (roturas o alquiler de menaje:
// platos, vasos, etc.). El servidor todavía no los conoce: quedan registrados
// solo en la app, por pedido.
class CargoExtra {
  final String nombre;
  final double monto;

  const CargoExtra({required this.nombre, required this.monto});
}

final Map<String, List<CargoExtra>> cargosExtraPorPedido = {};

List<CargoExtra> cargosExtraDe(String pedidoId) =>
    cargosExtraPorPedido[pedidoId] ?? const [];

double totalCargosExtra(String pedidoId) =>
    cargosExtraDe(pedidoId).fold(0.0, (s, c) => s + c.monto);

void registrarCargosExtra(String pedidoId, List<CargoExtra> cargos) {
  if (cargos.isEmpty) return;
  cargosExtraPorPedido[pedidoId] = [...cargosExtraDe(pedidoId), ...cargos];
}

// Menaje que se puede cobrar por rotura o alquiler.
const menajeCobrable = <String>[
  'Plato',
  'Plato hondo',
  'Vaso',
  'Copa',
  'Taza',
  'Jarra',
  'Cubierto',
  'Cuchara',
  'Tenedor',
  'Cuchillo',
  'Bandeja',
  'Olla',
  'Parrilla',
];

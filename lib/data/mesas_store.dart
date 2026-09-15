import '../models/mesa.dart';
import 'mock_mesas.dart';

// Estado en memoria de mesas, compartido entre Mesas/Pedidos y Pagos
// (cobrar un pedido libera la mesa).
// TODO: reemplazar por `mesa` real al conectar el servidor local.
final List<Mesa> mesas = List.of(mockMesas);

void actualizarEstadoMesa(int numero, String estado) {
  final index = mesas.indexWhere((m) => m.numero == numero);
  if (index != -1) mesas[index] = mesas[index].copyWith(estado: estado);
}

// Uniones de mesas (refleja que `mesa_pedido` admite varias mesas por
// pedido): par bidireccional numero -> numero de la mesa con la que está
// unida. Solo se permite unir mesas libres; al cobrar el pedido compartido
// se separan automáticamente.
final Map<int, int> mesaUnidaCon = {};

bool estaUnida(int numero) => mesaUnidaCon.containsKey(numero);

int? parejaDe(int numero) => mesaUnidaCon[numero];

void unirMesas(int a, int b) {
  mesaUnidaCon[a] = b;
  mesaUnidaCon[b] = a;
}

void separarMesas(int numero) {
  final pareja = mesaUnidaCon.remove(numero);
  if (pareja != null) mesaUnidaCon.remove(pareja);
}

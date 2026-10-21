import '../models/carta_presentacion.dart';
import '../models/unidad_bebida.dart';

// Catálogo de unidades de bebida (tabla `unidad_bebida`, ej. Vaso, Jarra).
final List<UnidadBebida> unidadesBebida = [];

// Tamaños/envases por plato (tabla `carta_presentacion`, ej. vaso/botella).
// Se cargan desde el backend.
final List<CartaPresentacion> presentaciones = [];

List<CartaPresentacion> presentacionesDeCarta(
  String cartaId, {
  bool soloActivas = false,
}) => presentaciones
    .where((p) => p.cartaId == cartaId && (!soloActivas || p.estado))
    .toList();

void reemplazarPresentacionesDeCarta(
  String cartaId,
  List<CartaPresentacion> nuevas,
) {
  presentaciones
    ..removeWhere((p) => p.cartaId == cartaId)
    ..addAll(nuevas);
}

void eliminarPresentacionesDeCarta(String cartaId) =>
    presentaciones.removeWhere((p) => p.cartaId == cartaId);

double? precioMinimoDePresentaciones(String cartaId) {
  final precios = presentacionesDeCarta(
    cartaId,
    soloActivas: true,
  ).map((p) => p.precioCliente);
  if (precios.isEmpty) return null;
  return precios.reduce((a, b) => a < b ? a : b);
}

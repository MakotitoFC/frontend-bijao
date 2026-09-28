import '../models/promocion.dart';

// Promociones (tabla `promocion`) y a qué platos aplica cada una
// (`promocion_carta`). Se cargan desde el backend.
final List<Promocion> promociones = [];
final Map<String, String> promocionCartaIds = {};

Promocion? promocionDeCarta(String cartaId) {
  final promoId = promocionCartaIds[cartaId];
  if (promoId == null) return null;
  for (final promo in promociones) {
    if (promo.id == promoId) return promo;
  }
  return null;
}

Set<String> cartasDePromocion(String promocionId) => promocionCartaIds.entries
    .where((e) => e.value == promocionId)
    .map((e) => e.key)
    .toSet();

void asignarCartasAPromocion(String promocionId, Set<String> cartaIds) {
  promocionCartaIds.removeWhere((_, promoId) => promoId == promocionId);
  for (final cartaId in cartaIds) {
    promocionCartaIds[cartaId] = promocionId;
  }
}

void agregarPromocion(Promocion promocion) => promociones.add(promocion);

void actualizarPromocion(Promocion promocion) {
  final index = promociones.indexWhere((p) => p.id == promocion.id);
  if (index != -1) promociones[index] = promocion;
}

void eliminarPromocion(String id) {
  promociones.removeWhere((p) => p.id == id);
  promocionCartaIds.removeWhere((_, promoId) => promoId == id);
}

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

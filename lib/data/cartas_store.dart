import 'package:flutter/foundation.dart';

import '../models/carta_item.dart';

// Platos y bebidas de la carta (tabla `productos`). Se cargan desde el
// backend.
final ValueNotifier<List<CartaItem>> cartasNotifier = ValueNotifier([]);

// Platos eliminados (borrado lógico, estado `eliminado`). No se muestran en la
// carta ni se pueden vender, pero se conservan para el historial y para
// resolver referencias (pedidos, promociones).
final List<CartaItem> cartasEliminadas = [];

List<CartaItem> todasLasCartas() => [
  ...cartasNotifier.value,
  ...cartasEliminadas,
];

// Busca un plato por id, incluso si fue eliminado.
CartaItem? cartaPorId(String? id) {
  if (id == null) return null;
  for (final c in todasLasCartas()) {
    if (c.id == id) return c;
  }
  return null;
}

import 'package:flutter/foundation.dart';

import '../models/carta_item.dart';

// Platos y bebidas de la carta (tabla `productos`). Se cargan desde el
// backend.
final ValueNotifier<List<CartaItem>> cartasNotifier = ValueNotifier([]);

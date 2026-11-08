import '../models/carta_item.dart';
import '../services/catalog_service.dart';

// Táper de un plato para sus tarjetas: "Nombre · S/ 2.00", o la cantidad si
// tiene varios. Sin táper, null (no se muestra nada).
String? textoTaperDePlato(CartaItem item) {
  final ids = item.taperIds.isNotEmpty
      ? item.taperIds
      : [if (item.taperId != null) item.taperId!];
  if (ids.isEmpty) return null;
  if (ids.length > 1) return '${ids.length} tápers';
  final t = CatalogService.instance.tapers
      .where((x) => x.id == ids.first)
      .firstOrNull;
  // El plato tiene táper pero su nombre aún no se leyó: se avisa igual.
  if (t == null) return item.taperNombre ?? 'Con táper';
  return '${t.nombre} · S/ ${t.precio.toStringAsFixed(2)}';
}

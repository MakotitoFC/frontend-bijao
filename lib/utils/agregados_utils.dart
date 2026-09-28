// `productos.agregados` (jsonb) puede tener dos tipos de entradas:
// - Extra suelto: {'nombre': 'Palta extra', 'precio': 3.0}
// - Grupo de extras: {'grupo': 'Salsas', 'cantidadMaxima': 2, 'items': [
//     {'nombre': 'BBQ', 'precio': 0}, {'nombre': 'Ají', 'precio': 1.0},
//   ]}
// Estos helpers separan y leen ambos tipos sin duplicar el parseo en cada
// pantalla que usa `agregados`.

bool esGrupoAgregado(Map<String, dynamic> a) => a.containsKey('grupo');

List<Map<String, dynamic>> agregadosSimples(
  List<Map<String, dynamic>> agregados,
) => agregados.where((a) => !esGrupoAgregado(a)).toList();

List<Map<String, dynamic>> gruposDeAgregados(
  List<Map<String, dynamic>> agregados,
) => agregados.where(esGrupoAgregado).toList();

String nombreGrupo(Map<String, dynamic> g) => '${g['grupo']}';

int? cantidadMaximaGrupo(Map<String, dynamic> g) {
  final v = g['cantidadMaxima'];
  return v is num ? v.toInt() : null;
}

List<Map<String, dynamic>> itemsDeGrupo(Map<String, dynamic> g) {
  final items = g['items'];
  if (items is! List) return const [];
  return items.whereType<Map<String, dynamic>>().toList();
}

double? precioDeAgregado(Map<String, dynamic> a) {
  final p = a['precio'];
  return p is num ? p.toDouble() : null;
}

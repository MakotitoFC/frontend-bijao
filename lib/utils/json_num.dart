// El backend (Go) envía los campos `decimal` como texto ("25.50") y los demás
// números como número. Esta función lee ambos casos.
double? jsonDouble(Object? valor) {
  if (valor is num) return valor.toDouble();
  if (valor is String) return double.tryParse(valor);
  return null;
}

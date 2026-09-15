import '../models/promocion.dart';

// Semilla inicial (ver promociones_store.dart para el estado mutable en memoria).
final promoHappyHour = Promocion(
  id: 'promo1',
  nombre: 'Happy Hour Bebidas',
  descripcion: 'Descuento en bebidas por tiempo limitado',
  tipo: 'porcentaje',
  valor: 20,
  fechaInicio: DateTime.now().subtract(const Duration(days: 7)),
  fechaFin: DateTime.now().add(const Duration(days: 23)),
);

final promoAjiDeGallina = Promocion(
  id: 'promo2',
  nombre: 'Promo Ají de Gallina',
  descripcion: 'Descuento fijo en el plato de la casa',
  tipo: 'monto',
  valor: 5,
  fechaInicio: DateTime.now().subtract(const Duration(days: 7)),
  fechaFin: DateTime.now().add(const Duration(days: 23)),
);

final promocionesIniciales = [promoHappyHour, promoAjiDeGallina];

// Semilla de `promocion_carta` (qué platos tiene cada promoción).
const promocionCartaIdsIniciales = {
  'carta5': 'promo1',
  'carta6': 'promo1',
  'carta4': 'promo2',
};

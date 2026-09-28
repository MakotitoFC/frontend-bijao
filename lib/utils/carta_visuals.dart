import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// Ícono de respaldo por categoría e imagen real para algunos platos de
// muestra. Compartido entre el catálogo del pedido y la vista de Productos
// para que ambos usen exactamente el mismo criterio visual.

IconData iconoDeCategoria(String categoriaId) {
  switch (categoriaId) {
    case 'cat1':
      return LucideIcons.utensils;
    case 'cat2':
      return LucideIcons.utensilsCrossed;
    case 'cat3':
      return LucideIcons.cupSoda;
    default:
      return LucideIcons.utensils;
  }
}

String? imagenDeCarta(String cartaId) {
  switch (cartaId) {
    case 'carta1':
      return 'assets/images/Ensalada-de-chonta.webp';
    case 'carta3':
      return 'assets/images/tacacho-con-cecina-y-chorizo.jpg';
    case 'carta5':
      return 'assets/images/aguajina-bebida-selva-peruana-cocatambo.webp';
    default:
      return null;
  }
}

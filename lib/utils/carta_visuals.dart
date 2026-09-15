import 'package:hugeicons/hugeicons.dart';

// Ícono de respaldo por categoría e imagen real para algunos platos de
// muestra. Compartido entre el catálogo del pedido y la vista de Productos
// para que ambos usen exactamente el mismo criterio visual.

List<List<dynamic>> iconoDeCategoria(String categoriaId) {
  switch (categoriaId) {
    case 'cat1':
      return HugeIcons.strokeRoundedServingFood;
    case 'cat2':
      return HugeIcons.strokeRoundedSpoonAndFork;
    case 'cat3':
      return HugeIcons.strokeRoundedSoftDrink02;
    default:
      return HugeIcons.strokeRoundedServingFood;
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

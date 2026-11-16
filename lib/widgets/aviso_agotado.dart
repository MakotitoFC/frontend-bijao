import 'package:flutter/material.dart';

import '../data/disponibilidad_store.dart';
import '../models/carta_item.dart';
import 'app_toast.dart';

// Al agregar a un pedido un plato agotado o por agotarse en inventario se avisa
// al mozo. Si está agotado y la sede lo bloquea, el plato ni siquiera se puede
// elegir.
void avisarSiAgotadoInventario(BuildContext context, CartaItem item) {
  final e = estadoDisponibilidadDe(item.id);
  if (e.tipo == TipoDisponibilidad.stockBajoInventario) {
    showAppToast(
      context,
      e.quedan != null
          ? '${item.nombrePlato}: quedan ${e.quedan} en inventario.'
          : '${item.nombrePlato} está por agotarse en inventario.',
      type: ToastType.info,
      titulo: 'Por agotarse',
    );
    return;
  }
  if (e.tipo == TipoDisponibilidad.agotadoInventario && e.vendible) {
    showAppToast(
      context,
      '${item.nombrePlato} está agotado en inventario. Se puede pedir igual.',
      type: ToastType.warning,
      titulo: 'Agotado',
    );
  }
}

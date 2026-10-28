import 'package:flutter/foundation.dart';

import '../models/traspaso_pedido.dart';

// Traspasos pendientes del usuario (enviados y recibidos). Los trae el
// servidor; aquí quedan en memoria para dibujar el aviso y la bandeja.
final List<TraspasoPedido> traspasosPendientes = [];

// Sube cada vez que cambia la lista, para redibujar lo que la muestra.
final ValueNotifier<int> traspasosRevision = ValueNotifier(0);

void reemplazarTraspasos(List<TraspasoPedido> lista) {
  traspasosPendientes
    ..clear()
    ..addAll(lista.where((t) => t.pendiente));
  traspasosRevision.value++;
}

// Solicitud pendiente de este pedido (la que envió su mozo), si la hay.
TraspasoPedido? traspasoPendienteDe(String pedidoId) {
  for (final t in traspasosPendientes) {
    if (t.pedidoId == pedidoId) return t;
  }
  return null;
}

// Solicitudes que otros mozos le enviaron a [usuarioId] y debe responder.
List<TraspasoPedido> traspasosPorResponder(String usuarioId) => [
  for (final t in traspasosPendientes)
    if (t.destinoId == usuarioId) t,
];

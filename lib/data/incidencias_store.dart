import '../models/incidencia.dart';
import 'pedidos_store.dart';

// Incidencias (devoluciones/reclamos) en memoria.
// TODO: reemplazar por `pedidos_detalle_incidencia` real al conectar el
// servidor local.
final List<Incidencia> incidencias = [];

Incidencia? incidenciaDeLinea(String lineaId) {
  for (final i in incidencias) {
    if (i.pedidoLineaId == lineaId) return i;
  }
  return null;
}

// Registra la incidencia, marca la línea como 'incidencia' y, salvo que la
// acción solicitada sea "descuento" (no implica rehacer nada), la vuelve a
// enviar a cocina (queda pendiente de preparar de nuevo).
Incidencia registrarIncidencia({
  required String pedidoId,
  required String pedidoLineaId,
  required String motivo,
  required String accion,
  String? nota,
}) {
  final incidencia = Incidencia(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    pedidoId: pedidoId,
    pedidoLineaId: pedidoLineaId,
    motivo: motivo,
    accion: accion,
    nota: nota,
    fecha: DateTime.now(),
  );
  incidencias.insert(0, incidencia);
  marcarLineaComoIncidencia(pedidoId, pedidoLineaId);
  if (accion != 'descuento') lineasPreparadas.remove(pedidoLineaId);
  return incidencia;
}

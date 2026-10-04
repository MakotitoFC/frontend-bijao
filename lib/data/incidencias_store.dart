import '../models/incidencia.dart';
import '../models/medio_pago.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import 'cartas_store.dart';
import 'configuracion_store.dart';
import 'creditos_store.dart';
import 'pagos_store.dart';
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

MedioPago _medioPorId(String? id) => mediosPagoActivos.firstWhere(
  (m) => m.id == id,
  orElse: () => mediosPagoActivos.first,
);

String _soles(double v) => 'S/ ${v.toStringAsFixed(2)}';

// Registra la incidencia, marca la línea como 'incidencia' y aplica la
// resolución al pedido. Devuelve la incidencia y un resumen de lo que hizo.
({Incidencia incidencia, String resumen}) registrarIncidencia({
  required Pedido pedido,
  required PedidoLine linea,
  required ReporteProblema reporte,
}) {
  final incidencia = Incidencia(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    pedidoId: pedido.id,
    pedidoLineaId: linea.id,
    categoria: reporte.categoria,
    detalle: reporte.detalle,
    evidencia: reporte.evidencia,
    resolucion: reporte.resolucion,
    fecha: DateTime.now(),
  );
  incidencias.insert(0, incidencia);
  marcarLineaComoIncidencia(pedido.id, linea.id);

  final monto = linea.precioTotalLinea;
  final pagadoLinea = montoPagadoDeLinea(linea.id);
  var resumen = '';

  switch (reporte.resolucion) {
    // Se devuelve el dinero: se descuenta la línea y, si ya estaba pagada,
    // sale un pago negativo por el mismo medio (afecta caja o pasarela).
    case 'reembolso':
      final ajuste = agregarAjusteAPedido(
        pedido.id,
        '$ajusteReembolso${linea.nombrePlato}',
        monto,
      );
      final devuelto = pagadoLinea > 0 ? pagadoLinea.clamp(0, monto) : 0.0;
      if (ajuste != null && devuelto > 0.001) {
        final medio = _medioPorId(reporte.medioReembolsoId);
        registrarReembolso(
          pedido: pedido,
          lineaAjuste: ajuste,
          medioPago: medio,
          monto: devuelto.toDouble(),
        );
        resumen =
            'Reembolso de ${_soles(devuelto.toDouble())} por ${medio.medioPago}.';
      } else {
        resumen = 'Se descontaron ${_soles(monto)} de la cuenta.';
      }
      cerrarSiSaldado(pedido);

    // No se devuelve dinero: se entrega otro producto y, si hay diferencia de
    // precio, se cobra (queda en el saldo) o se devuelve.
    case 'cambio':
      final nuevoPrecio = reporte.reemplazoPrecio ?? monto;
      final nombreNuevo = reporte.reemplazoNombre ?? linea.nombrePlato;
      final ajuste = agregarAjusteAPedido(
        pedido.id,
        '$ajusteCambio${linea.nombrePlato}',
        monto,
      );
      final item = cartasNotifier.value
          .where((c) => c.id == reporte.reemplazoCartaId)
          .firstOrNull;
      agregarLineaAPedido(
        pedido.id,
        PedidoLine(
          id: '${DateTime.now().microsecondsSinceEpoch}-cambio',
          cartaId: item?.id ?? 'reemplazo-manual',
          nombrePlato: nombreNuevo,
          cantidad: 1,
          modificadores: const [],
          presentacion: null,
          promocion: null,
          comentario: 'Cambio de ${linea.nombrePlato}',
          precioUnitario: nuevoPrecio,
          descuentoAplicado: 0,
          precioTotalLinea: nuevoPrecio,
        ),
      );
      final diferencia = nuevoPrecio - monto;
      if (diferencia > 0.001) {
        resumen = 'Diferencia a cobrar: ${_soles(diferencia)}.';
      } else if (diferencia < -0.001) {
        final devuelto = pagadoLinea > 0
            ? pagadoLinea.clamp(0, -diferencia).toDouble()
            : 0.0;
        if (ajuste != null && devuelto > 0.001) {
          final medio = _medioPorId(reporte.medioReembolsoId);
          registrarReembolso(
            pedido: pedido,
            lineaAjuste: ajuste,
            medioPago: medio,
            monto: devuelto,
          );
          resumen =
              'Diferencia devuelta: ${_soles(devuelto)} por ${medio.medioPago}.';
        } else {
          resumen = 'La cuenta baja ${_soles(-diferencia)}.';
        }
      } else {
        resumen = 'Sin diferencia de precio.';
      }
      cerrarSiSaldado(pedido);

    // Se emite un documento que reduce la venta; lo ya pagado queda como
    // saldo a favor del cliente.
    case 'nota_credito':
      agregarAjusteAPedido(
        pedido.id,
        '$ajusteNotaCredito${linea.nombrePlato}',
        monto,
      );
      final aFavor = pagadoLinea > 0
          ? pagadoLinea.clamp(0, monto).toDouble()
          : 0.0;
      final nota = emitirNotaCredito(
        pedido: pedido,
        concepto: linea.nombrePlato,
        monto: monto,
        saldoAFavor: aFavor,
      );
      resumen = aFavor > 0.001
          ? '${nota.numero} emitida: saldo a favor de ${_soles(aFavor)}.'
          : '${nota.numero} emitida: la venta baja ${_soles(monto)}.';
      cerrarSiSaldado(pedido);

    // No se devuelve dinero: se entrega un cupón con vigencia.
    case 'vale':
      final vale = emitirVale(
        pedido: pedido,
        concepto: linea.nombrePlato,
        monto: monto,
      );
      resumen =
          'Vale ${vale.codigo} por ${_soles(monto)}, válido $vigenciaValeDias días.';

    // No se acepta la devolución: todo queda igual.
    default:
      resumen = 'Devolución rechazada: el pago no cambia.';
  }
  return (incidencia: incidencia, resumen: resumen);
}

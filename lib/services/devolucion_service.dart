import '../data/cartas_store.dart';
import '../data/pagos_store.dart';
import '../models/incidencia.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import '../utils/uuid_helper.dart';
import 'api_client.dart';
import 'pago_service.dart';
import 'pedido_mozo_service.dart';
import 'pedido_service.dart';

String _soles(double v) => 'S/ ${v.toStringAsFixed(2)}';

// Devoluciones de una línea contra el servidor:
// `POST /api/v1/caja/pedidos/:id/items/:detalle_id/devolver`. El servidor da de
// baja la línea y, según el tipo, devuelve el dinero (pago negativo) o emite un
// vale con su código y vigencia.
class DevolucionService {
  DevolucionService._();
  static final DevolucionService instance = DevolucionService._();

  final ApiClient _api = ApiClient.instance;

  // ¿Esta devolución se puede hacer en el servidor? Hace falta un pedido y una
  // línea del servidor (con ids UUID).
  bool puedeEnServidor(Pedido pedido, PedidoLine linea) =>
      UuidHelper.isValid(pedido.id) && UuidHelper.isValid(linea.id);

  // Aplica la resolución elegida y devuelve un resumen para mostrar al cajero.
  // Si el servidor la rechaza, lanza el error y no cambia nada.
  Future<String> devolver({
    required Pedido pedido,
    required PedidoLine linea,
    required ReporteProblema reporte,
  }) async {
    final precio = linea.precioTotalLinea;
    final pagado = montoPagadoDeLinea(linea.id);
    final motivo = [
      reporte.categoria,
      reporte.detalle,
    ].where((t) => t.trim().isNotEmpty).join(': ');
    final base = '/api/v1/caja/pedidos/${pedido.id}/items/${linea.id}/devolver';

    String resumen;
    switch (reporte.resolucion) {
      case 'reembolso':
        if (pagado > 0.001) {
          // Se devuelve lo que se había pagado de esa línea, por el medio elegido.
          final devuelto = pagado < precio ? pagado : precio;
          await _api.post(
            base,
            body: {
              'tipo_devolucion': 'efectivo',
              'monto': devuelto,
              'motivo': motivo,
              if (UuidHelper.isValid(reporte.medioReembolsoId ?? ''))
                'medio_pago_id': reporte.medioReembolsoId,
            },
          );
          resumen = 'Reembolso de ${_soles(devuelto)}.';
        } else {
          // Sin pago no hay dinero que devolver: la línea solo sale de la cuenta.
          if (!PedidoMozoService.instance.activo) {
            throw Exception(
              'Esa línea todavía no se cobró: quítala desde el pedido (anular).',
            );
          }
          await PedidoMozoService.instance.anularFila(
            pedido.id,
            linea,
            cantidad: linea.cantidad,
            motivo: motivo,
            urlEvidencia: reporte.evidencia,
          );
          resumen = 'Se descontaron ${_soles(precio)} de la cuenta.';
        }
      case 'vale':
        final res = await _api.post(
          base,
          body: {'tipo_devolucion': 'vale', 'monto': precio, 'motivo': motivo},
        );
        final codigo = res is Map ? res['vale_codigo'] : null;
        final vence = res is Map ? res['fecha_vencimiento'] : null;
        resumen =
            'Vale ${codigo ?? ''} por ${_soles(precio)}'
            '${vence != null ? ', válido hasta $vence' : ''}.';
      case 'nota_credito':
        await _api.post(
          base,
          body: {
            'tipo_devolucion': 'nota_credito',
            'monto': precio,
            'motivo': motivo,
          },
        );
        resumen =
            'Baja registrada por ${_soles(precio)}. La nota de crédito se '
            'emite aparte.';
      case 'cambio':
        await _api.post(
          base,
          body: {
            'tipo_devolucion': 'cambio_plato',
            'monto': precio,
            'motivo': motivo,
          },
        );
        final nuevoPrecio = reporte.reemplazoPrecio ?? precio;
        final item = cartasNotifier.value
            .where((c) => c.id == reporte.reemplazoCartaId)
            .firstOrNull;
        // El plato que se entrega entra al pedido como una línea más.
        await PedidoMozoService.instance.agregarProducto(
          pedido.id,
          PedidoLine(
            id: UuidHelper.v7(),
            cartaId: item?.id ?? 'reemplazo-manual',
            nombrePlato: reporte.reemplazoNombre ?? linea.nombrePlato,
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
        final dif = nuevoPrecio - precio;
        resumen = dif > 0.001
            ? 'Diferencia a cobrar: ${_soles(dif)}.'
            : dif < -0.001
            ? (pagado > 0.001
                  ? 'La diferencia de ${_soles(-dif)} se devuelve al cliente '
                        '(hazlo como reembolso).'
                  : 'La cuenta baja ${_soles(-dif)}.')
            : 'Sin diferencia de precio.';
      default:
        throw Exception('Resolución no válida: ${reporte.resolucion}');
    }

    // El servidor ya cambió la cuenta y los pagos: se vuelve a leer lo suyo.
    try {
      await PedidoService.instance.cargarPedidos();
      await PagoService.instance.cargarDePedido(pedido);
    } catch (_) {}
    return resumen;
  }
}

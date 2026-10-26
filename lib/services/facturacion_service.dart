import '../models/comprobante.dart';
import 'api_client.dart';

// Facturación electrónica contra el servidor (`/api/v1/facturacion/...`): consulta
// de RUC, emisión de boleta, factura o ticket de venta, historial, estado ante
// SUNAT, anulación y reimpresión en la ticketera de caja.
class FacturacionService {
  FacturacionService._();
  static final FacturacionService instance = FacturacionService._();

  static const _base = '/api/v1/facturacion';
  final ApiClient _api = ApiClient.instance;

  // Consulta un RUC (11 dígitos) en SUNAT.
  Future<RucInfo> consultarRuc(String ruc) async {
    final res = await _api.get('$_base/ruc/${ruc.trim()}');
    if (res is! Map<String, dynamic>) {
      throw Exception('El servidor no devolvió datos del RUC');
    }
    return RucInfo.fromJson(res);
  }

  // Emite un comprobante del pedido. Con [imprimir] el servidor lo manda a la
  // ticketera de caja. Si SUNAT lo rechaza, lanza el error (el servidor deja
  // el motivo en el mensaje).
  Future<Comprobante> emitir({
    required String pedidoId,
    required String tipoDocumento,
    String? pagoId,
    String? clienteTipoDoc,
    String? clienteNumDoc,
    String? clienteDenominacion,
    String? clienteDireccion,
    bool imprimir = true,
    // Una sola línea "Consumo" en vez del detalle de platos (boleta o factura).
    bool soloConsumo = false,
  }) async {
    final res = await _api.post(
      '$_base/comprobantes',
      // La emisión puede tardar: SUNAT responde en unos segundos.
      timeout: const Duration(seconds: 45),
      body: {
        'pedido_id': pedidoId,
        'tipo_documento': tipoDocumento,
        'pago_id': ?pagoId,
        'cliente_tipo_doc': ?clienteTipoDoc,
        'cliente_num_doc': ?clienteNumDoc,
        'cliente_denominacion': ?clienteDenominacion,
        'cliente_direccion': ?clienteDireccion,
        'imprimir': imprimir,
        if (soloConsumo) 'solo_consumo': true,
      },
    );
    if (res is! Map<String, dynamic>) {
      throw Exception('El servidor no devolvió el comprobante');
    }
    return Comprobante.fromJson(res);
  }

  // Historial de comprobantes de la sede (del más reciente al más antiguo).
  Future<List<Comprobante>> listar({
    DateTime? desde,
    DateTime? hasta,
    String? tipoDocumento,
    String? estadoSunat,
    String? pedidoId,
  }) async {
    String dia(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final res = await _api.get(
      '$_base/comprobantes',
      queryParams: {
        if (desde != null) 'desde': dia(desde),
        if (hasta != null) 'hasta': dia(hasta),
        'tipo_documento': ?tipoDocumento,
        'estado_sunat': ?estadoSunat,
        'pedido_id': ?pedidoId,
      },
    );
    if (res is! List) return const [];
    return res
        .whereType<Map<String, dynamic>>()
        .map(Comprobante.fromJson)
        .toList();
  }

  // Vuelve a preguntar a SUNAT por un comprobante que quedó pendiente.
  Future<Comprobante> consultarEstado(String id) async {
    final res = await _api.post(
      '$_base/comprobantes/$id/consultar-status',
      body: {},
    );
    if (res is! Map<String, dynamic>) {
      throw Exception('El servidor no devolvió el estado');
    }
    return Comprobante.fromJson(res);
  }

  // Comunicación de baja (anulación) ante SUNAT; el motivo es obligatorio.
  Future<void> anular(String id, {required String motivo}) async {
    await _api.post('$_base/comprobantes/$id/anular', body: {'motivo': motivo});
  }

  // Reenvía el comprobante a la ticketera de caja.
  Future<void> reimprimir(String id) async {
    await _api.post('$_base/comprobantes/$id/imprimir', body: {});
  }
}

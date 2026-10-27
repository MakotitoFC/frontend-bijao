import '../models/comprobante.dart';
import 'api_client.dart';

// Información devuelta por la consulta de DNI en RENIEC / SUNAT / APISUNAT
class DniInfo {
  final String dni;
  final String nombres;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final String nombreCompleto;

  const DniInfo({
    required this.dni,
    required this.nombres,
    required this.apellidoPaterno,
    required this.apellidoMaterno,
    required this.nombreCompleto,
  });

  factory DniInfo.fromJson(Map<String, dynamic> json) {
    return DniInfo(
      dni: json['dni']?.toString() ?? '',
      nombres: json['nombres']?.toString() ?? '',
      apellidoPaterno: json['apellido_paterno']?.toString() ?? '',
      apellidoMaterno: json['apellido_materno']?.toString() ?? '',
      nombreCompleto: json['nombre_completo']?.toString() ?? '',
    );
  }
}

// Configuración fiscal y de identidad de la sede
class SedeConfig {
  final String id;
  final String ruc;
  final String razonSocial;
  final String direccion;
  final String celular;
  final String codigoSerie;
  final double igvPorcentaje;
  final String resolucionSunat;
  final String consultaSunatUrl;
  final String logoUrl;

  const SedeConfig({
    required this.id,
    required this.ruc,
    required this.razonSocial,
    required this.direccion,
    required this.celular,
    required this.codigoSerie,
    required this.igvPorcentaje,
    required this.resolucionSunat,
    required this.consultaSunatUrl,
    required this.logoUrl,
  });

  factory SedeConfig.fromJson(Map<String, dynamic> json) => SedeConfig(
        id: json['id']?.toString() ?? '',
        ruc: json['ruc']?.toString() ?? '',
        razonSocial: json['razon_social']?.toString() ?? '',
        direccion: json['direccion']?.toString() ?? '',
        celular: json['celular']?.toString() ?? '',
        codigoSerie: json['codigo_serie']?.toString() ?? 'A',
        igvPorcentaje: (json['igv_porcentaje'] is num)
            ? (json['igv_porcentaje'] as num).toDouble()
            : (double.tryParse(json['igv_porcentaje']?.toString() ?? '18') ?? 18.0),
        resolucionSunat: json['resolucion_sunat']?.toString() ?? '',
        consultaSunatUrl: json['consulta_sunat_url']?.toString() ?? '',
        logoUrl: json['logo_url']?.toString() ?? '',
      );
}

// Serie y número correlativo registrado
class SerieCorrelativo {
  final String sedeId;
  final String tipoDocumento;
  final String serie;
  final int ultimoNumero;
  final String? updatedAt;

  const SerieCorrelativo({
    required this.sedeId,
    required this.tipoDocumento,
    required this.serie,
    required this.ultimoNumero,
    this.updatedAt,
  });

  factory SerieCorrelativo.fromJson(Map<String, dynamic> json) => SerieCorrelativo(
        sedeId: json['sede_id']?.toString() ?? '',
        tipoDocumento: json['tipo_documento']?.toString() ?? '',
        serie: json['serie']?.toString() ?? '',
        ultimoNumero: (json['ultimo_numero'] as num?)?.toInt() ?? 0,
        updatedAt: json['updated_at']?.toString(),
      );
}

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

  // Consulta un DNI (8 dígitos) en RENIEC / SUNAT / APISUNAT.
  Future<DniInfo> consultarDni(String dni) async {
    final res = await _api.get('$_base/dni/${dni.trim()}');
    if (res is! Map<String, dynamic>) {
      throw Exception('El servidor no devolvió datos del DNI');
    }
    return DniInfo.fromJson(res);
  }

  // Emite un comprobante del pedido. Con [imprimir] el servidor lo manda a la
  // ticketera de caja. Si SUNAT lo rechaza, lanza el error (el servidor deja
  // el motivo en el mensaje). Con [porConsumo] emite en un solo concepto "Por consumo".
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
    bool porConsumo = false,
    bool incluirRecargo = false,
    bool incluirDelivery = false,
  }) async {
    final esConsumo = soloConsumo || porConsumo;
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
        'incluir_recargo': incluirRecargo,
        'incluir_delivery': incluirDelivery,
        if (esConsumo) ...{
          'solo_consumo': true,
          'por_consumo': true,
        },
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

  // ==========================================================================
  // CONFIGURACIÓN DE SEDE Y SERIES
  // ==========================================================================

  Future<SedeConfig> obtenerSedeConfig() async {
    final res = await _api.get('/api/v1/sede/config');
    if (res is! Map<String, dynamic>) {
      throw Exception('Error obteniendo configuración de la sede');
    }
    return SedeConfig.fromJson(res);
  }

  Future<SedeConfig> guardarSedeConfig(Map<String, dynamic> datos) async {
    final res = await _api.put('/api/v1/sede/config', body: datos);
    if (res is! Map<String, dynamic>) {
      throw Exception('Error guardando configuración de la sede');
    }
    return SedeConfig.fromJson(res);
  }

  Future<List<SerieCorrelativo>> obtenerSeriesCorrelativos() async {
    final res = await _api.get('/api/v1/caja/series');
    if (res is! List) return const [];
    return res
        .whereType<Map<String, dynamic>>()
        .map(SerieCorrelativo.fromJson)
        .toList();
  }

  Future<void> actualizarSerieCorrelativo(String serie, int ultimoNumero, {String? tipoDocumento}) async {
    await _api.post(
      '/api/v1/caja/series',
      body: {
        'serie': serie,
        'ultimo_numero': ultimoNumero,
        'tipo_documento': ?tipoDocumento,
      },
    );
  }
}

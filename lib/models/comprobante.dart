import '../utils/json_num.dart';

// Un comprobante emitido (`comprobante_pago`): boleta, factura o ticket de venta
// interno (este último no va a SUNAT).
class Comprobante {
  final String id;
  final String pedidoId;
  final String tipoDocumento; // 'boleta' | 'factura' | 'ticket_venta'
  final String numeroComprobante; // "B001-00000104"
  final String fechaEmision;
  final String horaEmision;
  final String clienteTipoDoc;
  final String clienteNumDoc;
  final String clienteDenominacion;
  final double total;
  final double totalIgv;
  // 'ACEPTADO' | 'PENDIENTE' | 'RECHAZADO' | 'ANULADO' | 'NO_APLICA' | ...
  final String estadoSunat;
  final String? pdfTicketUrl;
  final String? pdfA4Url;
  final String? mensaje;
  final String? usuarioNombre;

  const Comprobante({
    required this.id,
    required this.pedidoId,
    required this.tipoDocumento,
    required this.numeroComprobante,
    required this.fechaEmision,
    required this.horaEmision,
    required this.clienteTipoDoc,
    required this.clienteNumDoc,
    required this.clienteDenominacion,
    required this.total,
    required this.totalIgv,
    required this.estadoSunat,
    this.pdfTicketUrl,
    this.pdfA4Url,
    this.mensaje,
    this.usuarioNombre,
  });

  factory Comprobante.fromJson(Map<String, dynamic> j) {
    String? texto(String k) {
      final v = j[k]?.toString();
      return (v == null || v.isEmpty) ? null : v;
    }

    return Comprobante(
      id: j['id']?.toString() ?? '',
      pedidoId: j['pedidos_id']?.toString() ?? '',
      tipoDocumento: j['tipo_documento']?.toString() ?? '',
      numeroComprobante: j['numero_comprobante']?.toString() ?? '',
      fechaEmision: j['fecha_emision']?.toString() ?? '',
      horaEmision: j['hora_emision']?.toString() ?? '',
      clienteTipoDoc: j['cliente_tipo_doc']?.toString() ?? '0',
      clienteNumDoc: j['cliente_num_doc']?.toString() ?? '',
      clienteDenominacion: j['cliente_denominacion']?.toString() ?? '',
      total: jsonDouble(j['total']) ?? 0,
      totalIgv: jsonDouble(j['total_igv']) ?? 0,
      estadoSunat: j['estado_sunat']?.toString() ?? '',
      pdfTicketUrl: texto('pdf_ticket_url'),
      pdfA4Url: texto('pdf_a4_url'),
      mensaje: texto('pse_mensaje'),
      usuarioNombre: texto('usuario_nombre'),
    );
  }

  String get tipoEtiqueta => switch (tipoDocumento) {
    'factura' => 'Factura',
    'boleta' => 'Boleta',
    'ticket_venta' => 'Ticket de venta',
    _ => tipoDocumento,
  };

  bool get esInterno => tipoDocumento == 'ticket_venta';
  bool get esFiscal => tipoDocumento == 'boleta' || tipoDocumento == 'factura';
  bool get anulado => estadoSunat == 'ANULADO';
  bool get pendiente =>
      estadoSunat == 'PENDIENTE' || estadoSunat == 'ERROR_CONEXION';
  bool get rechazado => estadoSunat == 'RECHAZADO';
  // Los comprobantes rechazados no valen: no se anulan ni se imprimen.
  bool get puedeAnularse => !anulado && !rechazado;

  String get estadoEtiqueta => switch (estadoSunat) {
    'ACEPTADO' => 'Aceptado',
    'PENDIENTE' => 'Pendiente',
    'ERROR_CONEXION' => 'Sin conexión',
    'RECHAZADO' => 'Rechazado',
    'ANULADO' => 'Anulado',
    'NO_APLICA' => 'Interno',
    _ => estadoSunat,
  };
}

// Datos de un RUC consultados en SUNAT.
class RucInfo {
  final String ruc;
  final String razonSocial;
  final String direccionFiscal;
  final String estado;
  final String condicion;

  const RucInfo({
    required this.ruc,
    required this.razonSocial,
    required this.direccionFiscal,
    required this.estado,
    required this.condicion,
  });

  factory RucInfo.fromJson(Map<String, dynamic> j) => RucInfo(
    ruc: j['ruc']?.toString() ?? '',
    razonSocial: j['razon_social']?.toString() ?? '',
    direccionFiscal: j['direccion_fiscal']?.toString() ?? '',
    estado: j['estado']?.toString() ?? '',
    condicion: j['condicion']?.toString() ?? '',
  );

  // SUNAT: se puede facturar a un RUC ACTIVO y HABIDO.
  bool get puedeFacturarse =>
      estado.toUpperCase() == 'ACTIVO' && condicion.toUpperCase() == 'HABIDO';
}

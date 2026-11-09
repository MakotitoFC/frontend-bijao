import 'package:flutter/foundation.dart';

import '../utils/ticket_texto.dart';
import 'api_client.dart';

// Vista previa de un ticket tal como lo imprimirá el servidor: las mismas líneas
// que salen en la ticketera, sin imprimir nada. Si el servidor no la ofrece o no
// responde, devuelve null y la pantalla usa su vista aproximada.
class PreviewTicket {
  final List<LineaTicket> lineas;
  // El ticket impreso lleva el logo arriba.
  final bool conLogo;

  const PreviewTicket({required this.lineas, required this.conLogo});

  // Lee la respuesta del servidor: `{ancho, lineas: [...], logo_url}`.
  static PreviewTicket? deJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final crudas = json['lineas'];
    if (crudas is! List) return null;
    final lineas = <LineaTicket>[];
    for (final l in crudas.whereType<Map<String, dynamic>>()) {
      final qr = l['qr']?.toString() ?? '';
      if (qr.isNotEmpty) {
        lineas.add(LineaTicket.codigoQr(qr));
        continue;
      }
      lineas.add(
        LineaTicket(
          l['texto']?.toString() ?? '',
          alineacion: switch (l['alineacion']?.toString()) {
            'centro' => AlineacionTicket.centro,
            'derecha' => AlineacionTicket.derecha,
            _ => AlineacionTicket.izquierda,
          },
          negrita: l['negrita'] == true,
          doble: l['doble'] == true,
        ),
      );
    }
    if (lineas.isEmpty) return null;
    return PreviewTicket(
      lineas: lineas,
      conLogo: (json['logo_url']?.toString() ?? '').isNotEmpty,
    );
  }
}

class PreviewTicketService {
  PreviewTicketService._();
  static final PreviewTicketService instance = PreviewTicketService._();

  final ApiClient _api = ApiClient.instance;

  // Solo para pruebas: sustituye la lectura de la cuenta (sin red).
  @visibleForTesting
  Future<PreviewTicket?> Function(String pedidoId)? lectorCuentaDePrueba;

  // La cuenta de consumo de un pedido, como se imprimiría ahora.
  Future<PreviewTicket?> cuenta(String pedidoId) =>
      lectorCuentaDePrueba?.call(pedidoId) ??
      _leer('/api/v1/impresion/preview/cuenta/$pedidoId');

  // El ticket de un comprobante ya emitido, como se imprime.
  Future<PreviewTicket?> comprobante(String comprobanteId) =>
      _leer('/api/v1/impresion/preview/comprobante/$comprobanteId');

  Future<PreviewTicket?> _leer(String ruta) async {
    try {
      return PreviewTicket.deJson(await _api.get(ruta));
    } catch (_) {
      return null;
    }
  }
}

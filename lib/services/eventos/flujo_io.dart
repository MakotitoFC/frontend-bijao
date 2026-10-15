import 'dart:async';
import 'dart:io';

import 'evento_sse.dart';

// Escritorio y móvil: conexión HTTP que se mantiene abierta, con el token en
// la cabecera Authorization.
Stream<EventoSse> abrirFlujoDeEventos({
  required Uri url,
  required String token,
}) async* {
  final cliente = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final peticion = await cliente.getUrl(url);
    peticion.headers
      ..set(HttpHeaders.acceptHeader, 'text/event-stream')
      ..set(HttpHeaders.cacheControlHeader, 'no-cache')
      ..set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final respuesta = await peticion.close();
    if (respuesta.statusCode != 200) {
      await respuesta.drain<void>();
      throw ErrorFlujoEventos(
        'El servidor rechazó la conexión (${respuesta.statusCode}).',
        codigo: respuesta.statusCode,
      );
    }
    // El servidor envía un latido cada 20 s: si pasa un minuto sin nada, la
    // conexión se dio por perdida (cambio de red, suspensión...).
    yield* leerEventosSse(
      respuesta.timeout(
        const Duration(seconds: 60),
        onTimeout: (sink) => sink.addError(
          const ErrorFlujoEventos('Se perdió la conexión con el servidor.'),
        ),
      ),
    );
  } finally {
    cliente.close(force: true);
  }
}

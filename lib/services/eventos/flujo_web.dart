import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'evento_sse.dart';

// Navegador: EventSource no permite cabeceras, por eso el token va en la URL
// (`?token=`), como acepta el backend.
Stream<EventoSse> abrirFlujoDeEventos({
  required Uri url,
  required String token,
}) {
  late final StreamController<EventoSse> control;
  web.EventSource? fuente;
  control = StreamController<EventoSse>(
    onListen: () {
      final direccion = url.replace(
        queryParameters: {...url.queryParameters, 'token': token},
      );
      final f = web.EventSource(direccion.toString());
      fuente = f;
      for (final nombre in nombresDeEventos) {
        f.addEventListener(
          nombre,
          ((web.Event e) {
            final dato = (e as web.MessageEvent).data;
            control.add(
              EventoSse(
                nombre,
                dato.isA<JSString>() ? (dato as JSString).toDart : '',
              ),
            );
          }).toJS,
        );
      }
      // EventSource reintenta solo con el mismo token (que puede haber
      // vencido): se cierra y el servicio vuelve a conectar con el vigente.
      f.onerror = ((web.Event _) {
        f.close();
        if (!control.isClosed) {
          control.addError(
            const ErrorFlujoEventos('Se perdió la conexión con el servidor.'),
          );
          control.close();
        }
      }).toJS;
    },
    onCancel: () {
      fuente?.close();
    },
  );
  return control.stream;
}

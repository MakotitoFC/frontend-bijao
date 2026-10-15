// Abre el flujo de eventos del servidor con la implementación de cada
// plataforma: HTTP en escritorio y móvil, EventSource en el navegador.
export 'flujo_stub.dart'
    if (dart.library.js_interop) 'flujo_web.dart'
    if (dart.library.io) 'flujo_io.dart';

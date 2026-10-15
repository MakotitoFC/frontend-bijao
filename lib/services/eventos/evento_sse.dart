import 'dart:async';
import 'dart:convert';

// Un evento del flujo del servidor (Server-Sent Events).
class EventoSse {
  final String nombre;
  final String datos;

  const EventoSse(this.nombre, this.datos);

  // Los datos suelen ser un JSON; si no lo son, devuelve null.
  Map<String, dynamic>? get json {
    try {
      final d = jsonDecode(datos);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) {
      return null;
    }
  }
}

// El servidor respondió con un error al abrir el flujo (por ejemplo 401).
class ErrorFlujoEventos implements Exception {
  final int? codigo;
  final String mensaje;

  const ErrorFlujoEventos(this.mensaje, {this.codigo});

  @override
  String toString() => mensaje;
}

// Nombres de los eventos que emite el backend. El navegador (EventSource) solo
// entrega los eventos que se piden por nombre.
const nombresDeEventos = <String>[
  'conexion_establecida',
  'PEDIDO_NUEVO',
  'PRODUCTO_AGREGADO',
  'PEDIDO_ACTUALIZADO',
  'ITEM_SERVIDO',
  'PEDIDO_ESTADO_CAMBIADO',
  'PEDIDO_ANULADO',
  'CAMBIO_MESA',
  'MESA_LIBERADA',
  'PLATO_AGOTADO',
  'STOCK_ACTUALIZADO',
  'APERTURA_DIARIA_COMPLETA',
];

// Convierte los bytes del flujo en eventos. Formato: líneas `event: nombre` y
// `data: ...`, y una línea vacía cierra el evento. Las líneas que empiezan con
// `:` son latidos (keepalive) y se ignoran.
Stream<EventoSse> leerEventosSse(Stream<List<int>> bytes) async* {
  var nombre = 'message';
  final datos = <String>[];
  await for (final linea
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (linea.isEmpty) {
      if (datos.isNotEmpty) yield EventoSse(nombre, datos.join('\n'));
      nombre = 'message';
      datos.clear();
    } else if (linea.startsWith(':')) {
      continue;
    } else if (linea.startsWith('event:')) {
      nombre = linea.substring(6).trim();
    } else if (linea.startsWith('data:')) {
      datos.add(linea.substring(5).trimLeft());
    }
  }
}

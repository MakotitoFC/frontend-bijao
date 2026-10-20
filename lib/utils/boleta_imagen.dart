import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../data/logo_ticket_store.dart';
import '../widgets/ticket_papel.dart';
import 'ticket_texto.dart';

// Convierte la boleta en una imagen PNG, tal como se ve en pantalla (con logo,
// QR y borde de papel), para guardarla y mandarla al cliente.

// Dibuja [contenido] fuera de la pantalla y devuelve su captura en PNG. Devuelve
// null si no se pudo.
Future<Uint8List?> capturarWidgetPng(
  BuildContext context,
  Widget contenido, {
  double pixelRatio = 3,
}) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return null;
  final llave = GlobalKey();
  final entrada = OverlayEntry(
    builder: (_) => Positioned(
      left: -10000,
      top: 0,
      child: Material(
        color: Colors.white,
        child: RepaintBoundary(key: llave, child: contenido),
      ),
    ),
  );
  overlay.insert(entrada);
  try {
    // Un par de cuadros para que se arme y se pinte antes de capturar.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final objeto = llave.currentContext?.findRenderObject();
    if (objeto is! RenderRepaintBoundary) return null;
    final imagen = await objeto.toImage(pixelRatio: pixelRatio);
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
    return datos?.buffer.asUint8List();
  } catch (_) {
    return null;
  } finally {
    entrada.remove();
  }
}

// PNG de la boleta de venta a partir de las líneas del ticket.
Future<Uint8List?> boletaComoPng(
  BuildContext context,
  List<LineaTicket> lineas,
) async {
  await cargarLogoTicketLocal();
  if (!context.mounted) return null;
  final local = logoTicketLocal.value;
  final ImageProvider logo = local != null
      ? MemoryImage(local)
      : const AssetImage('assets/images/logo_bijao.png');
  try {
    // El logo tiene que estar cargado antes de la captura.
    await precacheImage(logo, context);
  } catch (_) {}
  if (!context.mounted) return null;
  return capturarWidgetPng(
    context,
    SizedBox(
      width: 460,
      child: ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: TicketPapel(lineas: lineas, logo: logo),
        ),
      ),
    ),
  );
}

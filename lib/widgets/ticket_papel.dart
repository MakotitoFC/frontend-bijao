import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/logo_ticket_store.dart';
import '../utils/ticket_texto.dart';

// Un ticket como sale de la ticketera térmica: tiras de papel blanco con borde
// dentado arriba y abajo, letra de máquina (monoespaciada) y solo negro. El
// texto va en 48 columnas, igual que en el rollo de 80 mm.
class TicketPapel extends StatelessWidget {
  final List<LineaTicket> lineas;
  // Logo de arriba (cuentas de caja): se muestra en blanco y negro, como sale
  // en la ticketera. Si es null no se pone.
  final ImageProvider? logo;

  const TicketPapel({super.key, required this.lineas, this.logo});

  static const _fuentes = ['Courier New', 'Consolas', 'Menlo', 'Roboto Mono'];
  static const double _tamano = 12.5;
  // Una letra monoespaciada mide ~0.6 de su tamaño.
  static const double _anchoCaracter = _tamano * 0.6;

  TextStyle _estilo(LineaTicket l) => TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: _fuentes,
    fontSize: l.doble ? _tamano * 2 : _tamano,
    height: 1.28,
    color: Colors.black,
    fontWeight: l.negrita ? FontWeight.w800 : FontWeight.w500,
    letterSpacing: 0,
  );

  // Código QR en blanco y negro puros.
  Widget _qr(String datos) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Center(
      child: QrImageView(
        data: datos,
        size: 150,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      ),
    ),
  );

  Widget _linea(LineaTicket l) {
    if (l.qr != null) return _qr(l.qr!);
    final alin = switch (l.alineacion) {
      AlineacionTicket.centro => Alignment.center,
      AlineacionTicket.derecha => Alignment.centerRight,
      AlineacionTicket.izquierda => Alignment.centerLeft,
    };
    return Align(
      alignment: alin,
      child: Text(
        l.texto.isEmpty ? ' ' : l.texto,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: _estilo(l),
      ),
    );
  }

  // Negro sobre blanco, sin grises ni colores: una imagen térmica solo tiene
  // puntos negros. Se pasa a escala de grises y se aumenta el contraste.
  static const _aBlancoYNegro = ColorFilter.matrix(<double>[
    // R' = G' = B' = (0.2126 R + 0.7152 G + 0.0722 B) * 3 - 1.2
    0.6378, 2.1456, 0.2166, 0, -306, //
    0.6378, 2.1456, 0.2166, 0, -306, //
    0.6378, 2.1456, 0.2166, 0, -306, //
    0, 0, 0, 1, 0,
  ]);

  Widget _logo(ImageProvider imagen) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Center(
      child: ColorFiltered(
        colorFilter: _aBlancoYNegro,
        child: Image(image: imagen, height: 70, fit: BoxFit.contain),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final anchoTexto = anchoTicket * _anchoCaracter;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipPath(
            clipper: const _BordeDentado(),
            child: Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 26, 14, 26),
              // Si la pantalla es angosta, el ticket entero se achica en vez de
              // partirse.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: anchoTexto,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (logo != null) _logo(logo!),
                      for (final l in lineas) _linea(l),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Borde de sierra arriba y abajo, como el papel recién cortado.
class _BordeDentado extends CustomClipper<Path> {
  const _BordeDentado();

  static const double _alto = 6;
  static const double _ancho = 10;

  @override
  Path getClip(Size size) {
    final p = Path()..moveTo(0, _alto);
    var x = 0.0;
    var arriba = true;
    while (x < size.width) {
      final siguiente = (x + _ancho / 2).clamp(0.0, size.width);
      p.lineTo(siguiente, arriba ? 0 : _alto);
      x = siguiente;
      arriba = !arriba;
    }
    p.lineTo(size.width, size.height - _alto);
    x = size.width;
    arriba = true;
    while (x > 0) {
      final siguiente = (x - _ancho / 2).clamp(0.0, size.width);
      p.lineTo(siguiente, arriba ? size.height : size.height - _alto);
      x = siguiente;
      arriba = !arriba;
    }
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// Ticket con el logo de caja arriba (el último que se subió desde este equipo o,
// si no hay, el logo de la app). Sin [conLogo] es solo el papel.
class TicketConLogo extends StatefulWidget {
  final List<LineaTicket> lineas;
  final bool conLogo;

  const TicketConLogo({super.key, required this.lineas, this.conLogo = true});

  @override
  State<TicketConLogo> createState() => _TicketConLogoState();
}

class _TicketConLogoState extends State<TicketConLogo> {
  @override
  void initState() {
    super.initState();
    cargarLogoTicketLocal();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.conLogo) return TicketPapel(lineas: widget.lineas);
    return ValueListenableBuilder<Uint8List?>(
      valueListenable: logoTicketLocal,
      builder: (context, local, _) => TicketPapel(
        lineas: widget.lineas,
        logo: local != null
            ? MemoryImage(local) as ImageProvider
            : const AssetImage('assets/images/logo_bijao.png'),
      ),
    );
  }
}

import 'package:flutter/material.dart';

// Texto de una línea que se adapta a su contenedor sin cortarse con "…": usa la
// primera versión de [textos] (de la más larga a la más corta) que quepa; si
// ni la más corta cabe, la achica hasta que quepa.
// Ejemplo: ['PARA LLEVAR', 'LLEVAR'].
class TextoAdaptable extends StatelessWidget {
  final List<String> textos;
  final TextStyle? style;
  final TextAlign textAlign;
  // Dónde queda el texto dentro del espacio (y hacia dónde se achica).
  final AlignmentGeometry alineacion;
  // true: ocupa solo el ancho del texto (para centrar un icono y su texto juntos
  // en vez de dejar el texto solo en medio de todo el espacio).
  final bool ajustarAncho;

  const TextoAdaptable({
    super.key,
    required this.textos,
    this.style,
    this.textAlign = TextAlign.center,
    this.alineacion = Alignment.center,
    this.ajustarAncho = false,
  });

  @override
  Widget build(BuildContext context) {
    final estilo = DefaultTextStyle.of(context).style.merge(style);
    final escala = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, c) {
        Text texto(String t) => Text(
          t,
          maxLines: 1,
          softWrap: false,
          style: style,
          textAlign: textAlign,
        );
        if (!c.hasBoundedWidth) return texto(textos.first);
        Widget ubicar(Widget w) => Align(
          alignment: alineacion,
          widthFactor: ajustarAncho ? 1 : null,
          child: w,
        );
        for (final t in textos) {
          final medida = TextPainter(
            text: TextSpan(text: t, style: estilo),
            textDirection: TextDirection.ltr,
            textScaler: escala,
            maxLines: 1,
          )..layout();
          if (medida.width <= c.maxWidth) return ubicar(texto(t));
        }
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alineacion,
          child: texto(textos.last),
        );
      },
    );
  }
}

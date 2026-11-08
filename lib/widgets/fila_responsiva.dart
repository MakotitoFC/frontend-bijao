import 'package:flutter/material.dart';

// Fila de campos que, si no hay ancho para ponerlos lado a lado, se apila uno
// bajo el otro (en vez de apretarlos o desbordarse). Decide por el ancho que
// recibe, no por el de la pantalla, así también sirve dentro de modales.
// [flex] reparte el ancho cuando caben en fila; [anchoMinimo] es el ancho por
// debajo del cual se apilan.
class FilaResponsiva extends StatelessWidget {
  final List<Widget> hijos;
  final List<int>? flex;
  final double espacio;
  final double anchoMinimo;

  const FilaResponsiva({
    super.key,
    required this.hijos,
    this.flex,
    this.espacio = 12,
    this.anchoMinimo = 480,
  });

  // Para convertir un `Row` existente: se le pasan los mismos hijos (los
  // `Expanded` aportan su contenido y su `flex`; los `SizedBox` separadores se
  // ignoran).
  factory FilaResponsiva.fila({
    Key? key,
    required List<Widget> children,
    double espacio = 12,
    double anchoMinimo = 480,
  }) {
    final hijos = <Widget>[];
    final flex = <int>[];
    for (final w in children) {
      if (w is Expanded) {
        hijos.add(w.child);
        flex.add(w.flex);
      } else if (w is! SizedBox) {
        hijos.add(w);
        flex.add(1);
      }
    }
    return FilaResponsiva(
      key: key,
      hijos: hijos,
      flex: flex,
      espacio: espacio,
      anchoMinimo: anchoMinimo,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < anchoMinimo) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < hijos.length; i++) ...[
                if (i > 0) SizedBox(height: espacio),
                hijos[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < hijos.length; i++) ...[
              if (i > 0) SizedBox(width: espacio),
              Expanded(flex: flex?[i] ?? 1, child: hijos[i]),
            ],
          ],
        );
      },
    );
  }
}

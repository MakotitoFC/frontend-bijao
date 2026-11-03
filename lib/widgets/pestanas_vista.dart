import 'package:flutter/material.dart';

import 'submenu_lateral.dart';

// Subvistas de un módulo: la barra oscura de subsecciones arriba (con "<" y ">"
// si no caben) y, debajo, el contenido de la pestaña elegida.
class PestanasVista extends StatefulWidget {
  final List<({String etiqueta, WidgetBuilder contenido})> pestanas;

  const PestanasVista({super.key, required this.pestanas});

  @override
  State<PestanasVista> createState() => _PestanasVistaState();
}

class _PestanasVistaState extends State<PestanasVista> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubmenuSuperior(
          entradas: [
            for (var i = 0; i < widget.pestanas.length; i++)
              SubmenuEntrada.item('$i', widget.pestanas[i].etiqueta),
          ],
          seleccionada: '$_indice',
          onSeleccionar: (c) => setState(() => _indice = int.parse(c)),
        ),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(_indice),
            child: widget.pestanas[_indice].contenido(context),
          ),
        ),
      ],
    );
  }
}

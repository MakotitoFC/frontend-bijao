import 'package:flutter/material.dart';

import 'submenu_lateral.dart';

// Subvistas de un módulo: la barra oscura de subsecciones arriba (con "<" y ">"
// si no caben) y, debajo, el contenido de la pestaña elegida.
class PestanasVista extends StatefulWidget {
  final List<({String etiqueta, WidgetBuilder contenido})> pestanas;
  // Para pasar a otra pestaña desde dentro del contenido: se escribe la
  // etiqueta de la pestaña y la vista la abre (y deja el valor en null).
  final ValueNotifier<String?>? irA;

  const PestanasVista({super.key, required this.pestanas, this.irA});

  @override
  State<PestanasVista> createState() => _PestanasVistaState();
}

class _PestanasVistaState extends State<PestanasVista> {
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    widget.irA?.addListener(_ir);
  }

  @override
  void dispose() {
    widget.irA?.removeListener(_ir);
    super.dispose();
  }

  void _ir() {
    final etiqueta = widget.irA?.value;
    if (etiqueta == null) return;
    final i = widget.pestanas.indexWhere((p) => p.etiqueta == etiqueta);
    widget.irA!.value = null;
    if (i >= 0 && mounted) setState(() => _indice = i);
  }

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

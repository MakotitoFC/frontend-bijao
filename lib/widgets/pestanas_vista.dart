import 'package:flutter/material.dart';

import 'app_tag.dart';
import 'tabs_desplazables.dart';

// Subvistas de un módulo: una fila de pestañas verdes arriba y, debajo, el
// contenido de la pestaña elegida (mismo estilo que los tabs de Cocina).
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
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: TabsDesplazables(
            child: Row(
              children: [
                for (var i = 0; i < widget.pestanas.length; i++)
                  _pastilla(widget.pestanas[i].etiqueta, i),
              ],
            ),
          ),
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

  Widget _pastilla(String etiqueta, int i) {
    return AppTag(
      etiqueta: etiqueta,
      activo: i == _indice,
      onTap: () => setState(() => _indice = i),
    );
  }
}

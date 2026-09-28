import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
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
    final activo = i == _indice;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => setState(() => _indice = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: Neon.etiqueta(activa: activo, radio: 24),
          child: Text(
            etiqueta,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.verdeTexto,
            ),
          ),
        ),
      ),
    );
  }
}

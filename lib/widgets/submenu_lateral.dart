import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Una entrada del submenú: una opción que se puede elegir o una etiqueta de
// sección (texto gris que separa grupos de opciones).
class SubmenuEntrada {
  final String? clave;
  final String etiqueta;

  const SubmenuEntrada.item(String this.clave, this.etiqueta);
  const SubmenuEntrada.seccion(this.etiqueta) : clave = null;

  bool get esSeccion => clave == null;
}

// Barra horizontal de subvistas de un módulo (por ejemplo, Ventas), que va
// debajo del header. Lleva el mismo fondo oscuro que el menú principal.
class SubmenuSuperior extends StatelessWidget {
  final List<SubmenuEntrada> entradas;
  final String? seleccionada;
  final ValueChanged<String> onSeleccionar;

  const SubmenuSuperior({
    super.key,
    required this.entradas,
    required this.seleccionada,
    required this.onSeleccionar,
  });

  Widget _item(SubmenuEntrada e) {
    final activa = e.clave == seleccionada;
    return InkWell(
      onTap: () => onSeleccionar(e.clave!),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: activa ? AppColors.primaryGreen : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          e.etiqueta,
          maxLines: 1,
          style: TextStyle(
            fontSize: 13,
            fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
            color: activa ? AppColors.primaryGreen : Colors.white70,
          ),
        ),
      ),
    );
  }

  // Etiqueta de una sección: separa los grupos de opciones.
  Widget _seccion(SubmenuEntrada e, {required bool primera}) => Padding(
    padding: EdgeInsets.only(left: primera ? 6 : 14, right: 6),
    child: Row(
      children: [
        if (!primera) ...[
          Container(width: 1, height: 18, color: Colors.white24),
          const SizedBox(width: 14),
        ],
        Text(
          e.etiqueta,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Colors.white38,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.navbar,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < entradas.length; i++)
              entradas[i].esSeccion
                  ? _seccion(entradas[i], primera: i == 0)
                  : _item(entradas[i]),
          ],
        ),
      ),
    );
  }
}

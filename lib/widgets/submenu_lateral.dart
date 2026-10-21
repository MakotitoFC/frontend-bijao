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

// Segunda columna del menú: lista vertical con las subvistas de un módulo
// (por ejemplo, Ventas o Configuración), junto al menú principal. Lleva el mismo
// fondo oscuro que el menú principal.
class SubmenuLateral extends StatelessWidget {
  final String? titulo;
  final List<SubmenuEntrada> entradas;
  final String? seleccionada;
  final ValueChanged<String> onSeleccionar;
  final double ancho;

  const SubmenuLateral({
    super.key,
    this.titulo,
    required this.entradas,
    required this.seleccionada,
    required this.onSeleccionar,
    this.ancho = 220,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ancho,
      decoration: BoxDecoration(
        color: AppColors.navbar,
        border: const Border(left: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (titulo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 16, 14),
              child: Text(
                titulo!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(10, titulo == null ? 20 : 0, 10, 16),
              children: [for (final e in entradas) _entrada(e)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _entrada(SubmenuEntrada e) {
    if (e.esSeccion) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
        child: Text(
          e.etiqueta,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white38,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    final activa = e.clave == seleccionada;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: activa
            ? AppColors.primaryGreen.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.button),
          onTap: () => onSeleccionar(e.clave!),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              e.etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                color: activa ? AppColors.primaryGreen : Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

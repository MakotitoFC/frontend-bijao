import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Tag de filtro/pestaña: trazo gris sin fondo; el seleccionado va oscuro con
// texto blanco. Esquinas menos redondeadas (AppRadii.tag) que los botones.
class AppTag extends StatelessWidget {
  final String etiqueta;
  final bool activo;
  final VoidCallback? onTap;
  final int? cantidad;
  final IconData? icono;
  final VoidCallback? onQuitar;
  final String tooltipQuitar;
  // Color propio (ej. naranja del plato del día): seleccionado se rellena con él
  // y sin seleccionar usa su trazo y texto.
  final Color? color;
  // Trazo propio cuando no está seleccionado (por defecto el del color).
  final Color? colorBorde;

  const AppTag({
    super.key,
    required this.etiqueta,
    required this.activo,
    this.onTap,
    this.cantidad,
    this.icono,
    this.onQuitar,
    this.tooltipQuitar = 'Quitar',
    this.color,
    this.colorBorde,
  });

  @override
  Widget build(BuildContext context) {
    final colorBase = color ?? AppColors.navbar;
    final colorTexto = activo ? Colors.white : (color ?? Colors.grey.shade400);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.tag),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: AppSizes.control,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: activo ? colorBase : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.tag),
            border: Border.all(
              color: activo
                  ? colorBase
                  : (colorBorde ?? color ?? Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null) ...[
                Icon(icono, size: 14, color: colorTexto),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorTexto,
                  ),
                ),
              ),
              if (cantidad != null) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activo ? Colors.white : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$cantidad',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: activo ? colorBase : Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
              if (onQuitar != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: tooltipQuitar,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onQuitar,
                    child: Icon(Icons.close, size: 14, color: colorTexto),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

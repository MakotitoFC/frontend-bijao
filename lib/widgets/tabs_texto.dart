import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tabs_desplazables.dart';

// Una pestaña de [TabsTexto].
class TabTexto {
  final String etiqueta;
  final bool activa;
  final VoidCallback onTap;
  // Cuántos elementos tiene (se ve pequeño junto al nombre).
  final int? cantidad;
  // Quitar la pestaña (por ejemplo, eliminar una categoría); solo se ofrece en
  // la pestaña activa.
  final VoidCallback? onQuitar;
  final String tooltipQuitar;

  const TabTexto({
    required this.etiqueta,
    required this.activa,
    required this.onTap,
    this.cantidad,
    this.onQuitar,
    this.tooltipQuitar = 'Quitar',
  });
}

// Pestañas de solo texto, sin caja ni fondo, separadas por una línea fina. La
// activa va en verde y en negrita; las demás, en gris. Si no caben, la fila se
// desliza con "<" y ">".
class TabsTexto extends StatelessWidget {
  final List<TabTexto> tabs;

  const TabsTexto({super.key, required this.tabs});

  @override
  Widget build(BuildContext context) {
    final movil = AppBreakpoints.esMobile(context);
    return TabsDesplazables(
      child: SizedBox(
        height: AppSizes.control,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < tabs.length; i++) ...[
              if (i > 0)
                Container(width: 1, height: 18, color: Colors.grey.shade300),
              _tab(tabs[i], movil),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tab(TabTexto t, bool movil) {
    final color = t.activa ? AppColors.primaryGreen : Colors.grey.shade600;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.tag),
      onTap: t.onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: movil ? 12 : 20, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.etiqueta,
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                fontWeight: t.activa ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
            if (t.cantidad != null) ...[
              const SizedBox(width: 6),
              Text(
                '${t.cantidad}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: t.activa ? color : Colors.grey.shade400,
                ),
              ),
            ],
            if (t.activa && t.onQuitar != null) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: t.tooltipQuitar,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: t.onQuitar,
                  child: Icon(Icons.close, size: 14, color: color),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

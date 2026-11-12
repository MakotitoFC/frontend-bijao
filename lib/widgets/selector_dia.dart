import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../theme/app_theme.dart';
import 'selector_rango_fechas.dart';

// Elige un solo día: flechas para ir al día anterior o al siguiente y, entre
// ellas, el calendario de la app (el mismo de los rangos, pero de un día). No
// deja pasar de hoy.
class SelectorDia extends StatelessWidget {
  final DateTime dia;
  final ValueChanged<DateTime> onChanged;

  const SelectorDia({super.key, required this.dia, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final d = DateUtils.dateOnly(dia);
    final esHoy = !d.isBefore(hoy);
    Widget flecha(String tip, IconData icono, VoidCallback? onTap) => Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.tag),
        onTap: onTap,
        child: Container(
          width: AppSizes.control,
          height: AppSizes.control,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.tag),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Icon(
            icono,
            size: 18,
            color: onTap == null ? Colors.grey.shade400 : Colors.black87,
          ),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        flecha(
          'Día anterior',
          LucideIcons.chevronLeft,
          () => onChanged(d.subtract(const Duration(days: 1))),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: SelectorRangoFechas(
            valor: DateTimeRange(start: d, end: d),
            conAtajos: false,
            soloDia: true,
            onChanged: (r) {
              if (r != null) onChanged(DateUtils.dateOnly(r.start));
            },
          ),
        ),
        const SizedBox(width: 6),
        flecha(
          'Día siguiente',
          LucideIcons.chevronRight,
          esHoy ? null : () => onChanged(d.add(const Duration(days: 1))),
        ),
      ],
    );
  }
}

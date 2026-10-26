import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../theme/app_theme.dart';
import 'selector_rango_fechas.dart';

// Elige un solo día: flechas para ir al día anterior o al siguiente y un botón
// con la fecha que abre el calendario. No deja pasar de hoy.
class SelectorDia extends StatelessWidget {
  final DateTime dia;
  final ValueChanged<DateTime> onChanged;

  const SelectorDia({super.key, required this.dia, required this.onChanged});

  Future<void> _elegir(BuildContext context) async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final r = await showDatePicker(
      context: context,
      initialDate: dia.isAfter(hoy) ? hoy : dia,
      firstDate: DateTime(2020),
      lastDate: hoy,
    );
    if (r != null) onChanged(DateUtils.dateOnly(r));
  }

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
        child: SizedBox(
          width: AppSizes.control,
          height: AppSizes.control,
          child: Icon(
            icono,
            size: 18,
            color: onTap == null ? Colors.grey.shade400 : Colors.black87,
          ),
        ),
      ),
    );
    return Container(
      height: AppSizes.control,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.tag),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          flecha(
            'Día anterior',
            LucideIcons.chevronLeft,
            () => onChanged(d.subtract(const Duration(days: 1))),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadii.tag),
            onTap: () => _elegir(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Icon(LucideIcons.calendar, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    etiquetaRangoFechas(DateTimeRange(start: d, end: d)),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          flecha(
            'Día siguiente',
            LucideIcons.chevronRight,
            esHoy ? null : () => onChanged(d.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }
}

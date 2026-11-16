import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../theme/app_theme.dart';
import 'menu_flotante.dart';
import 'selector_rango_fechas.dart';

DateTimeRange periodoDeUnDia(DateTime d) {
  final dia = DateUtils.dateOnly(d);
  return DateTimeRange(start: dia, end: dia);
}

// Los atajos del filtro: Hoy, Ayer, últimos 7 días y este mes.
DateTimeRange? periodoAtajo(String clave, {DateTime? ahora}) {
  final hoy = DateUtils.dateOnly(ahora ?? DateTime.now());
  return switch (clave) {
    'hoy' => DateTimeRange(start: hoy, end: hoy),
    'ayer' => periodoDeUnDia(hoy.subtract(const Duration(days: 1))),
    '7' => DateTimeRange(
      start: hoy.subtract(const Duration(days: 6)),
      end: hoy,
    ),
    'mes' => DateTimeRange(start: DateTime(hoy.year, hoy.month, 1), end: hoy),
    _ => null,
  };
}

// Un solo control de fechas para todo el módulo: flechas para moverse de día en
// día, el botón con el periodo (que abre el calendario) y un menú con los atajos.
// Las flechas solo valen cuando el periodo es un día; no se pasa de hoy.
class FiltroPeriodo extends StatelessWidget {
  final DateTimeRange valor;
  final ValueChanged<DateTimeRange> onChanged;

  const FiltroPeriodo({super.key, required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final ini = DateUtils.dateOnly(valor.start);
    final fin = DateUtils.dateOnly(valor.end);
    final esDia = ini == fin;

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
          esDia
              ? () => onChanged(
                  periodoDeUnDia(ini.subtract(const Duration(days: 1))),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: SelectorRangoFechas(
            valor: valor,
            conAtajos: false,
            onChanged: (r) {
              if (r != null) {
                onChanged(
                  DateTimeRange(
                    start: DateUtils.dateOnly(r.start),
                    end: DateUtils.dateOnly(r.end),
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 6),
        flecha(
          'Día siguiente',
          LucideIcons.chevronRight,
          esDia && ini.isBefore(hoy)
              ? () =>
                    onChanged(periodoDeUnDia(ini.add(const Duration(days: 1))))
              : null,
        ),
        const SizedBox(width: 6),
        MenuFlotante<String>(
          tooltip: 'Atajos',
          anchoMinimo: 190,
          opciones: const [
            OpcionMenu(
              valor: 'hoy',
              etiqueta: 'Hoy',
              icono: LucideIcons.calendarCheck,
            ),
            OpcionMenu(
              valor: 'ayer',
              etiqueta: 'Ayer',
              icono: LucideIcons.calendarMinus,
            ),
            OpcionMenu(
              valor: '7',
              etiqueta: 'Últimos 7 días',
              icono: LucideIcons.calendarRange,
            ),
            OpcionMenu(
              valor: 'mes',
              etiqueta: 'Este mes',
              icono: LucideIcons.calendarDays,
            ),
          ],
          onSeleccionar: (k) {
            final p = periodoAtajo(k);
            if (p != null) onChanged(p);
          },
          disparador: (context, abierto) => Container(
            width: AppSizes.control,
            height: AppSizes.control,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.tag),
              border: Border.all(
                color: abierto ? AppColors.primaryGreen : Colors.grey.shade300,
              ),
            ),
            child: Icon(
              LucideIcons.chevronDown,
              size: 18,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }
}

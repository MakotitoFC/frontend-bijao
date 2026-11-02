import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../theme/app_theme.dart';
import 'dialogo_app.dart';
import 'selector_rango_fechas.dart';

// Qué reporte se pidió y de qué día ("aaaa-mm-dd").
typedef PedidoDeReporte = ({String accion, String fecha});

// Reportes de caja de otro día: se elige el día con el selector de fechas de la
// app y, dentro del mismo modal, el reporte. Devuelve la acción ('consolidado'
// o 'detallado') y la fecha; null si se cierra.
class ReportesOtraFechaDialog extends StatefulWidget {
  const ReportesOtraFechaDialog({super.key});

  @override
  State<ReportesOtraFechaDialog> createState() =>
      _ReportesOtraFechaDialogState();
}

class _ReportesOtraFechaDialogState extends State<ReportesOtraFechaDialog> {
  DateTime _dia = DateUtils.dateOnly(DateTime.now());

  String get _fecha =>
      '${_dia.year.toString().padLeft(4, '0')}-'
      '${_dia.month.toString().padLeft(2, '0')}-'
      '${_dia.day.toString().padLeft(2, '0')}';

  void _pedir(String accion) =>
      Navigator.of(context).pop((accion: accion, fecha: _fecha));

  @override
  Widget build(BuildContext context) {
    return DialogoApp(
      titulo: 'Reportes de otra fecha',
      ancho: 460,
      children: [
        Text(
          'Día del reporte',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: SelectorRangoFechas(
            valor: DateTimeRange(start: _dia, end: _dia),
            soloHoy: true,
            onChanged: (r) => setState(
              () => _dia = DateUtils.dateOnly(r?.start ?? DateTime.now()),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _OpcionReporte(
          icono: LucideIcons.printer,
          color: AppColors.primaryGreen,
          titulo: 'Imprimir consolidado del día (ticket)',
          detalle: 'Desglose de turnos y métodos de pago',
          onTap: () => _pedir('consolidado'),
        ),
        _OpcionReporte(
          icono: LucideIcons.fileText,
          color: const Color(0xFF9333EA),
          titulo: 'Ver / descargar súper reporte detallado (PDF/HTML)',
          detalle: 'Pedidos, mesas, mozos, anulaciones y rectificaciones',
          onTap: () => _pedir('detallado'),
        ),
      ],
    );
  }
}

// Una opción del modal: al pasar el cursor se colorea de verde, como las
// opciones de los selectores.
class _OpcionReporte extends StatefulWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;

  const _OpcionReporte({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.detalle,
    required this.onTap,
  });

  @override
  State<_OpcionReporte> createState() => _OpcionReporteState();
}

class _OpcionReporteState extends State<_OpcionReporte> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: widget.onTap,
      onHover: (v) => setState(() => _encima = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _encima
              ? AppColors.primaryGreen.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(widget.icono, size: 22, color: widget.color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.titulo,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _encima ? AppColors.primaryGreen : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.detalle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

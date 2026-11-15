import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../models/caja_servidor.dart';
import '../theme/app_theme.dart';
import 'selector_dia.dart';

// Caja: el día que se mira (flechas y calendario) y, debajo, los turnos de ese
// día. Se adapta al ancho: "Volver a Hoy" y los turnos bajan de línea cuando no
// caben (celular y tablet).
class SelectorDiaYTurnos extends StatelessWidget {
  final DateTime dia;
  final bool esHoy;
  final List<AperturaCaja> aperturas;
  final String? aperturaSeleccionadaId;
  final bool cargando;
  final ValueChanged<DateTime> onDia;
  final ValueChanged<String> onApertura;

  const SelectorDiaYTurnos({
    super.key,
    required this.dia,
    required this.esHoy,
    required this.aperturas,
    required this.aperturaSeleccionadaId,
    required this.cargando,
    required this.onDia,
    required this.onApertura,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // El día y, si no es hoy, el acceso para volver. Bajan de línea si no
          // caben juntos.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SelectorDia(dia: dia, onChanged: onDia),
              if (!esHoy)
                ActionChip(
                  avatar: const Icon(LucideIcons.arrowRight, size: 14),
                  label: const Text('Volver a Hoy'),
                  onPressed: () => onDia(DateTime.now()),
                ),
            ],
          ),
          if (aperturas.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Turnos del día:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
                for (var i = 0; i < aperturas.length; i++)
                  _turno(aperturas[i], i),
              ],
            ),
          ],
          if (cargando) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    );
  }

  Widget _turno(AperturaCaja ap, int i) {
    final esSel = aperturaSeleccionadaId == ap.id;
    final esActiva = ap.abierta;
    return ChoiceChip(
      avatar: Icon(
        esActiva ? LucideIcons.lockOpen : LucideIcons.lock,
        size: 13,
        color: esSel
            ? Colors.white
            : (esActiva ? AppColors.primaryGreen : Colors.grey.shade600),
      ),
      label: Text(
        '${ap.turnoNombre ?? "Turno ${i + 1}"}${esActiva ? " (En curso)" : ""}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: esSel ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: esSel,
      selectedColor: AppColors.primaryGreen,
      labelStyle: TextStyle(color: esSel ? Colors.white : Colors.black87),
      onSelected: (sel) {
        if (sel) onApertura(ap.id);
      },
    );
  }
}

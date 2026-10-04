import 'package:flutter/material.dart';

import '../data/configuracion_store.dart';
import '../theme/app_theme.dart';
import 'app_tag.dart';

// Propina para el mesero: se elige un porcentaje sugerido o se escribe el monto.
// Devuelve el monto en soles (0 quita la propina) o null si se cancela.
class PropinaDialog extends StatefulWidget {
  // Consumo sobre el que se calculan los porcentajes.
  final double base;
  final double actual;

  const PropinaDialog({super.key, required this.base, this.actual = 0});

  @override
  State<PropinaDialog> createState() => _PropinaDialogState();
}

class _PropinaDialogState extends State<PropinaDialog> {
  late final _monto = TextEditingController(
    text: widget.actual > 0 ? widget.actual.toStringAsFixed(2) : '',
  );

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  double get _valor =>
      double.tryParse(_monto.text.trim().replaceAll(',', '.')) ?? 0;

  List<double> get _porcentajes {
    final sugerido = config.propinaSugerida;
    final lista = <double>{5, 10, 15, sugerido}.toList()..sort();
    return lista;
  }

  bool _esPorcentaje(double pct) =>
      (_valor - widget.base * pct / 100).abs() < 0.005 && _valor > 0;

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final ancho = MediaQuery.sizeOf(context).width;
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: esMobile ? ancho : 400,
          maxWidth: esMobile ? ancho : 400,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            esMobile ? 28 : 22,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Propina para el mesero',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Consumo: S/ ${widget.base.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),
              Wrap(
                runSpacing: 8,
                children: [
                  for (final pct in _porcentajes)
                    AppTag(
                      etiqueta: '${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1)}%',
                      activo: _esPorcentaje(pct),
                      onTap: () => setState(
                        () => _monto.text = (widget.base * pct / 100)
                            .toStringAsFixed(2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _monto,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => Navigator.of(context).pop(_valor),
                decoration: const InputDecoration(
                  labelText: 'Monto de la propina (S/)',
                  prefixText: 'S/ ',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (widget.actual > 0)
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(0.0),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      child: const Text('Quitar'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _valor > 0
                        ? () => Navigator.of(context).pop(_valor)
                        : null,
                    child: const Text('Aplicar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'campo_texto.dart';
import 'dialogo_app.dart';

// Propina para el mesero: se escribe el monto en soles. Devuelve el monto (0
// quita la propina) o null si se cancela.
class PropinaDialog extends StatefulWidget {
  final double actual;

  const PropinaDialog({super.key, this.actual = 0});

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
          minWidth: esMobile ? ancho : 360,
          maxWidth: esMobile ? ancho : 360,
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
                      'Propina',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  BotonCerrarCircular(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SeparadorDialogo(),
              // Sin alto fijo: el campo toma el alto de su texto y no se corta.
              CampoTexto(
                controller: _monto,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (_valor > 0) Navigator.of(context).pop(_valor);
                },
                decoration: const InputDecoration(hintText: 'S/.'),
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

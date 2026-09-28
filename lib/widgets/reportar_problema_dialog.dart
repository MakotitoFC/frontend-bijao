import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_select.dart';

// Reporta un problema con un plato ya pedido (devolución/reclamo): motivo,
// acción solicitada y una nota opcional. Devuelve (motivo, accion, nota) o
// null si se cancela.
class ReportarProblemaDialog extends StatefulWidget {
  final String nombrePlato;

  const ReportarProblemaDialog({super.key, required this.nombrePlato});

  @override
  State<ReportarProblemaDialog> createState() =>
      _ReportarProblemaDialogState();
}

class _ReportarProblemaDialogState extends State<ReportarProblemaDialog> {
  static const _acciones = [
    AppSelectItem(value: 'rehacer', label: 'Rehacer el plato'),
    AppSelectItem(value: 'descuento', label: 'Descuento'),
    AppSelectItem(value: 'no_cobrar', label: 'No cobrar nada'),
    AppSelectItem(value: 'casa', label: 'A cuenta de la casa'),
  ];

  final _formKey = GlobalKey<FormState>();
  final _motivoController = TextEditingController();
  final _notaController = TextEditingController();
  String? _accion;

  @override
  void dispose() {
    _motivoController.dispose();
    _notaController.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    if (_accion == null) return;
    Navigator.of(context).pop((
      motivo: _motivoController.text.trim(),
      accion: _accion!,
      nota: _notaController.text.trim().isEmpty
          ? null
          : _notaController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: esMobile
            ? BoxConstraints(minWidth: anchoPantalla, maxWidth: anchoPantalla)
            : const BoxConstraints(minWidth: 420, maxWidth: 420),
        child: Form(
          key: _formKey,
          child: Padding(
            padding: EdgeInsets.fromLTRB(28, esMobile ? 28 : 22, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Reportar problema',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.nombrePlato,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _motivoController,
                  autofocus: true,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Motivo',
                    hintText: 'Ej. el plato llegó frío',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa el motivo'
                      : null,
                ),
                const SizedBox(height: 16),
                AppSelect<String>(
                  label: 'Acción solicitada',
                  value: _accion,
                  items: _acciones,
                  hint: 'Elige una acción',
                  onChanged: (v) => setState(() => _accion = v),
                ),
                if (_accion == null) ...[
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      'Elige la acción solicitada',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notaController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Nota (opcional)',
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _guardar,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../data/compras_store.dart';
import '../models/compra.dart';
import '../theme/app_theme.dart';
import '../utils/uuid_helper.dart';

// Nueva compra: solo los datos de la tabla `compra` (fecha y notas). Los
// productos comprados se agregan después, como detalles de esta compra, que se
// guarda en el backend al confirmarla. Devuelve la compra creada, o null si se
// cancela.
class CompraFormDialog extends StatefulWidget {
  const CompraFormDialog({super.key});

  @override
  State<CompraFormDialog> createState() => _CompraFormDialogState();
}

class _CompraFormDialogState extends State<CompraFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notasController = TextEditingController();
  DateTime _fecha = DateTime.now();

  @override
  void dispose() {
    _notasController.dispose();
    super.dispose();
  }

  String _fechaTexto(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    final notas = _notasController.text.trim();
    final compra = Compra(
      id: UuidHelper.v7(),
      fechaCompra: _fecha,
      total: 0,
      notas: notas.isEmpty ? null : notas,
    );
    registrarCompra(compra);
    Navigator.of(context).pop(compra);
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
            : const BoxConstraints(minWidth: 440, maxWidth: 440),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              28,
              esMobile ? 28 : 22,
              28,
              28 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Nueva compra',
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
                Text(
                  'Luego agregarás los productos comprados como detalles.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _elegirFecha,
                  borderRadius: BorderRadius.circular(AppRadii.tag),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha de compra',
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                    child: Text(_fechaTexto(_fecha)),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notasController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _guardar,
                    child: const Text('Crear compra'),
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

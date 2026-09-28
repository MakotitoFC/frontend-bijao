import 'package:flutter/material.dart';

import '../data/mesas_store.dart';
import '../theme/app_theme.dart';

// Alta de una mesa: número y cantidad de clientes (define cuántas sillas se
// dibujan). Devuelve (numero, capacidad) o null si se cancela.
class MesaFormDialog extends StatefulWidget {
  const MesaFormDialog({super.key});

  @override
  State<MesaFormDialog> createState() => _MesaFormDialogState();
}

class _MesaFormDialogState extends State<MesaFormDialog> {
  static const _minimo = 1;
  static const _maximo = 12;

  final _formKey = GlobalKey<FormState>();
  late final _numeroController = TextEditingController(
    text: '${siguienteNumeroMesa()}',
  );
  int _capacidad = 4;

  @override
  void dispose() {
    _numeroController.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((
      numero: int.parse(_numeroController.text.trim()),
      capacidad: _capacidad,
    ));
  }

  Widget _boton(IconData icono, VoidCallback? onTap) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Icon(
        icono,
        size: 18,
        color: onTap == null ? Colors.grey.shade400 : Colors.black87,
      ),
    ),
  );

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
            : const BoxConstraints(minWidth: 400, maxWidth: 400),
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
                    const Expanded(
                      child: Text(
                        'Nueva mesa',
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _numeroController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número de mesa',
                  ),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) return 'Ingresa un número';
                    if (existeMesa(n)) return 'Ya existe la mesa $n';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Cantidad de clientes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _boton(
                      Icons.remove,
                      _capacidad > _minimo
                          ? () => setState(() => _capacidad--)
                          : null,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '$_capacidad',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _capacidad == 1 ? '1 silla' : '$_capacidad sillas',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.verdeTexto,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _boton(
                      Icons.add,
                      _capacidad < _maximo
                          ? () => setState(() => _capacidad++)
                          : null,
                    ),
                  ],
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
                    child: const Text('Crear mesa'),
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

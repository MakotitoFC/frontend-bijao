import 'package:flutter/material.dart';

import '../data/mesas_store.dart';
import '../theme/app_theme.dart';

typedef ZonaFormResultado = ({String nombre, bool eliminar});

// Alta o edición de una zona del local: solo el nombre. En edición también
// permite eliminarla (junto con sus mesas, si todas están libres).
class ZonaFormDialog extends StatefulWidget {
  final String? zona;

  const ZonaFormDialog({super.key, this.zona});

  @override
  State<ZonaFormDialog> createState() => _ZonaFormDialogState();
}

class _ZonaFormDialogState extends State<ZonaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nombreController = TextEditingController(text: widget.zona);

  bool get _editando => widget.zona != null;

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context)
        .pop((nombre: _nombreController.text.trim(), eliminar: false));
  }

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    final puedeEliminar = _editando && puedeEliminarZona(widget.zona!);
    final cantidadMesas = _editando ? mesasDeZona(widget.zona!).length : 0;
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
                    Expanded(
                      child: Text(
                        _editando ? 'Editar zona' : 'Nueva zona',
                        style: const TextStyle(
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
                  controller: _nombreController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la zona',
                    hintText: 'Ej. Terraza, Salón principal',
                  ),
                  onFieldSubmitted: (_) => _guardar(),
                  validator: (v) {
                    final nombre = v?.trim() ?? '';
                    if (nombre.isEmpty) return 'Ingresa el nombre';
                    final cambia =
                        !_editando ||
                        nombre.toLowerCase() != widget.zona!.toLowerCase();
                    if (cambia && existeZona(nombre)) {
                      return 'Ya existe la zona "$nombre"';
                    }
                    return null;
                  },
                ),
                if (_editando && cantidadMesas > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    cantidadMesas == 1
                        ? 'Esta zona tiene 1 mesa.'
                        : 'Esta zona tiene $cantidadMesas mesas.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (_editando)
                      Tooltip(
                        message: puedeEliminar ? 'Eliminar zona y sus mesas' : 'No se puede eliminar: es la única zona o tiene mesas ocupadas/unidas',
                        child: OutlinedButton(
                          onPressed: puedeEliminar
                              ? () => Navigator.of(context)
                                    .pop((nombre: widget.zona!, eliminar: true))
                              : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(
                              color: puedeEliminar
                                  ? AppColors.error
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: const Text('Eliminar'),
                        ),
                      ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _guardar,
                      child: Text(_editando ? 'Guardar' : 'Crear zona'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

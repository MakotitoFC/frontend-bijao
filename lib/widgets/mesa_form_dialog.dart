import 'package:flutter/material.dart';

import '../data/mesas_store.dart';
import '../models/mesa.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';

typedef MesaFormResultado = ({
  int numero,
  int capacidad,
  String zona,
  bool eliminar,
});

// Alta o edición de una mesa: número, cantidad de clientes (define cuántas
// sillas se dibujan) y zona. En edición también permite eliminarla.
class MesaFormDialog extends StatefulWidget {
  final Mesa? mesa;
  final String zonaInicial;

  const MesaFormDialog({super.key, this.mesa, this.zonaInicial = 'Principal'});

  @override
  State<MesaFormDialog> createState() => _MesaFormDialogState();
}

class _MesaFormDialogState extends State<MesaFormDialog> {
  static const _minimo = 1;
  static const _maximo = 12;

  final _formKey = GlobalKey<FormState>();
  late final _numeroController = TextEditingController(
    text: '${widget.mesa?.numero ?? siguienteNumeroMesa()}',
  );
  late int _capacidad = widget.mesa == null
      ? 4
      : capacidadDe(widget.mesa!.numero);
  late String _zona = widget.mesa?.zona ?? widget.zonaInicial;

  bool get _editando => widget.mesa != null;

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
      zona: _zona,
      eliminar: false,
    ));
  }

  void _eliminar() {
    Navigator.of(context).pop((
      numero: widget.mesa!.numero,
      capacidad: _capacidad,
      zona: _zona,
      eliminar: true,
    ));
  }

  Widget _boton(IconData icono, VoidCallback? onTap) => InkWell(
    borderRadius: BorderRadius.circular(AppRadii.tag),
    onTap: onTap,
    child: Container(
      width: AppSizes.control,
      height: AppSizes.control,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.tag),
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
    final puedeEliminar = _editando && puedeEliminarMesa(widget.mesa!.numero);
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
                    Expanded(
                      child: Text(
                        _editando
                            ? 'Editar mesa T-${widget.mesa!.numero}'
                            : 'Nueva mesa',
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
                  controller: _numeroController,
                  autofocus: !_editando,
                  enabled: !_editando,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número de mesa',
                  ),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) return 'Ingresa un número';
                    if (!_editando && existeMesa(n)) {
                      return 'Ya existe la mesa $n';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppSelect<String>(
                  label: 'Zona',
                  value: _zona,
                  items: [
                    for (final z in zonasMesas)
                      AppSelectItem(value: z, label: z),
                  ],
                  onChanged: (v) => setState(() => _zona = v ?? _zona),
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
                Row(
                  children: [
                    if (_editando) ...[
                      Tooltip(
                        message: puedeEliminar
                            ? 'Eliminar mesa'
                            : 'No se puede eliminar una mesa ocupada o unida',
                        child: OutlinedButton(
                          onPressed: puedeEliminar ? _eliminar : null,
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
                    ],
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _guardar,
                      child: Text(_editando ? 'Guardar' : 'Crear mesa'),
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

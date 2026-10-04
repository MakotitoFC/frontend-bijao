import 'package:flutter/material.dart';

import '../data/catalogos_store.dart';
import '../models/producto_inventario.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';

// Alta/edición de un producto de inventario. El stock inicial solo se define
// al crear; después se ajusta con "Ajustar stock" (ver AjustarStockDialog).
// Devuelve el ProductoInventario resultante, o null si se cancela.
class ProductoInventarioFormDialog extends StatefulWidget {
  final ProductoInventario? producto; // null = crear nuevo

  const ProductoInventarioFormDialog({super.key, this.producto});

  @override
  State<ProductoInventarioFormDialog> createState() =>
      _ProductoInventarioFormDialogState();
}

class _ProductoInventarioFormDialogState
    extends State<ProductoInventarioFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nombreController = TextEditingController(
    text: widget.producto?.nombre ?? '',
  );
  late final _descripcionController = TextEditingController(
    text: widget.producto?.descripcion ?? '',
  );
  late final _stockController = TextEditingController(
    text: widget.producto?.stockActual.toString() ?? '0',
  );
  late final _stockMinimoController = TextEditingController(
    text: widget.producto?.stockMinimo.toString() ?? '0',
  );
  late final _costoController = TextEditingController(
    text: widget.producto?.costoReposicion?.toStringAsFixed(2) ?? '',
  );
  late final _precioClienteController = TextEditingController(
    text: widget.producto?.precioCliente?.toStringAsFixed(2) ?? '',
  );
  late final _notasController = TextEditingController(
    text: widget.producto?.notas ?? '',
  );

  late int _tipoProductoId =
      widget.producto?.tipoProductoId ?? tiposProducto.first.id;
  late int _tipoSeguimientoId =
      widget.producto?.tipoSeguimientoId ?? tiposSeguimiento.first.id;
  late int _unidadId =
      widget.producto?.unidadProductoId ?? unidadesProducto.first.id;
  late bool _activo = widget.producto?.estado != 'inactivo';

  bool get _editando => widget.producto != null;

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _stockController.dispose();
    _stockMinimoController.dispose();
    _costoController.dispose();
    _precioClienteController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      ProductoInventario(
        id:
            widget.producto?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim().isEmpty
            ? null
            : _descripcionController.text.trim(),
        tipoProductoId: _tipoProductoId,
        tipoSeguimientoId: _tipoSeguimientoId,
        unidadProductoId: _unidadId,
        stockActual: double.parse(_stockController.text.trim()),
        stockMinimo: double.tryParse(_stockMinimoController.text.trim()) ?? 0,
        costoReposicion: _costoController.text.trim().isEmpty
            ? null
            : double.parse(_costoController.text.trim()),
        precioCliente: _precioClienteController.text.trim().isEmpty
            ? null
            : double.parse(_precioClienteController.text.trim()),
        notas: _notasController.text.trim().isEmpty
            ? null
            : _notasController.text.trim(),
        estado: _activo ? 'activo' : 'inactivo',
      ),
    );
  }

  Widget _campo(
    TextEditingController c,
    String etiqueta, {
    bool numero = false,
    bool habilitado = true,
    String? ayuda,
    String? Function(String?)? validador,
  }) {
    return TextFormField(
      controller: c,
      enabled: habilitado,
      keyboardType: numero
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: InputDecoration(labelText: etiqueta, helperText: ayuda),
      validator: validador,
    );
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
            : const BoxConstraints(minWidth: 460, maxWidth: 460),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(28, esMobile ? 28 : 22, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _editando ? 'Editar producto' : 'Nuevo producto',
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
                _campo(
                  _nombreController,
                  'Nombre',
                  validador: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa el nombre'
                      : null,
                ),
                const SizedBox(height: 14),
                _campo(_descripcionController, 'Descripción (opcional)'),
                const SizedBox(height: 14),
                AppSelect<int>(
                  label: 'Tipo de producto',
                  value: _tipoProductoId,
                  items: [
                    for (final t in tiposProducto)
                      AppSelectItem(value: t.id, label: t.tipoProducto),
                  ],
                  onChanged: (v) => setState(() => _tipoProductoId = v!),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AppSelect<int>(
                        label: 'Seguimiento',
                        value: _tipoSeguimientoId,
                        items: [
                          for (final t in tiposSeguimiento)
                            AppSelectItem(
                              value: t.id,
                              label: t.tipoSeguimiento,
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _tipoSeguimientoId = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppSelect<int>(
                        label: 'Unidad',
                        value: _unidadId,
                        items: [
                          for (final u in unidadesProducto)
                            AppSelectItem(value: u.id, label: u.unidad),
                        ],
                        onChanged: (v) => setState(() => _unidadId = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _campo(
                        _stockController,
                        'Stock inicial',
                        numero: true,
                        habilitado: !_editando,
                        ayuda: _editando ? 'Usa "Ajustar stock"' : null,
                        validador: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa el stock';
                          }
                          if (double.tryParse(v.trim()) == null) {
                            return 'Valor inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _campo(
                        _stockMinimoController,
                        'Stock mínimo',
                        numero: true,
                        ayuda: 'Alerta de stock bajo',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _campo(
                        _costoController,
                        'Costo reposición (S/, opcional)',
                        numero: true,
                        validador: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (double.tryParse(v.trim()) == null) {
                            return 'Valor inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _campo(
                        _precioClienteController,
                        'Precio al cliente (S/, opcional)',
                        numero: true,
                        ayuda: 'Si también se vende directo (ej. pescado)',
                        validador: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (double.tryParse(v.trim()) == null) {
                            return 'Valor inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _campo(_notasController, 'Notas (opcional)'),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  value: _activo,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primaryGreen,
                  onChanged: (value) => setState(() => _activo = value),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _guardar,
                    style: ElevatedButton.styleFrom(),
                    child: Text(
                      _editando ? 'Guardar cambios' : 'Crear producto',
                    ),
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

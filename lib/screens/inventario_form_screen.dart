import 'package:flutter/material.dart';

import '../data/mock_tipos_producto.dart';
import '../data/mock_tipos_seguimiento.dart';
import '../data/mock_unidades_producto.dart';
import '../models/producto_inventario.dart';
import '../models/tipo_producto.dart';
import '../models/tipo_seguimiento.dart';
import '../models/unidad_producto.dart';

// Alta/edición de un producto de inventario (solo Administrador).
// El stock inicial solo se define al crear; después se ajusta con
// "Ajustar stock" en InventarioScreen (simulando `inventario_movimiento`).
// TODO: al conectar el backend, esto pasa a insertar/actualizar
// `producto_inventario` real.
class InventarioFormScreen extends StatefulWidget {
  final ProductoInventario? producto; // null = crear nuevo

  const InventarioFormScreen({super.key, this.producto});

  @override
  State<InventarioFormScreen> createState() => _InventarioFormScreenState();
}

class _InventarioFormScreenState extends State<InventarioFormScreen> {
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
  late final _costoController = TextEditingController(
    text: widget.producto?.costoReposicion?.toStringAsFixed(2) ?? '',
  );
  late final _notasController = TextEditingController(
    text: widget.producto?.notas ?? '',
  );

  late TipoProducto _tipoProducto = mockTiposProducto.firstWhere(
    (t) => t.id == widget.producto?.tipoProductoId,
    orElse: () => mockTiposProducto.first,
  );
  late TipoSeguimiento _tipoSeguimiento = mockTiposSeguimiento.firstWhere(
    (t) => t.id == widget.producto?.tipoSeguimientoId,
    orElse: () => mockTiposSeguimiento.first,
  );
  late UnidadProducto _unidad = mockUnidadesProducto.firstWhere(
    (u) => u.id == widget.producto?.unidadProductoId,
    orElse: () => mockUnidadesProducto.first,
  );
  late bool _activo = widget.producto?.estado != 'inactivo';

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _stockController.dispose();
    _costoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;

    final resultado = ProductoInventario(
      id:
          widget.producto?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      nombre: _nombreController.text.trim(),
      descripcion: _descripcionController.text.trim().isEmpty
          ? null
          : _descripcionController.text.trim(),
      tipoProductoId: _tipoProducto.id,
      tipoSeguimientoId: _tipoSeguimiento.id,
      unidadProductoId: _unidad.id,
      stockActual: double.parse(_stockController.text.trim()),
      costoReposicion: _costoController.text.trim().isEmpty
          ? null
          : double.parse(_costoController.text.trim()),
      notas: _notasController.text.trim().isEmpty
          ? null
          : _notasController.text.trim(),
      estado: _activo ? 'activo' : 'inactivo',
    );
    Navigator.of(context).pop(resultado);
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.producto != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? 'Editar producto' : 'Nuevo producto'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descripcionController,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TipoProducto>(
              initialValue: _tipoProducto,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo de producto'),
              items: mockTiposProducto
                  .map(
                    (t) =>
                        DropdownMenuItem(value: t, child: Text(t.tipoProducto)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _tipoProducto = value!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TipoSeguimiento>(
              initialValue: _tipoSeguimiento,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tipo de seguimiento',
              ),
              items: mockTiposSeguimiento
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.tipoSeguimiento),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _tipoSeguimiento = value!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<UnidadProducto>(
              initialValue: _unidad,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Unidad'),
              items: mockUnidadesProducto
                  .map((u) => DropdownMenuItem(value: u, child: Text(u.unidad)))
                  .toList(),
              onChanged: (value) => setState(() => _unidad = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stockController,
              enabled: !editando,
              decoration: InputDecoration(
                labelText: 'Stock inicial',
                helperText: editando
                    ? 'Usa "Ajustar stock" en la lista para modificarlo'
                    : null,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa el stock';
                if (double.tryParse(v.trim()) == null) return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _costoController,
              decoration: const InputDecoration(
                labelText: 'Costo de reposición (S/, opcional)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (double.tryParse(v.trim()) == null) return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notasController,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo'),
              value: _activo,
              onChanged: (value) => setState(() => _activo = value),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _guardar,
              child: Text(editando ? 'Guardar cambios' : 'Crear producto'),
            ),
          ],
        ),
      ),
    );
  }
}

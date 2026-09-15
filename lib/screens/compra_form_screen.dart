import 'package:flutter/material.dart';

import '../data/compras_store.dart';
import '../data/inventario_store.dart';
import '../data/mock_unidades_producto.dart';
import '../models/compra.dart';
import '../models/compra_detalle.dart';
import '../models/producto_inventario.dart';
import '../models/unidad_producto.dart';

// Registro de una compra a proveedor con sus líneas de detalle.
// Al guardar, repone el stock de cada producto (ver compras_store.dart).
class CompraFormScreen extends StatefulWidget {
  const CompraFormScreen({super.key});

  @override
  State<CompraFormScreen> createState() => _CompraFormScreenState();
}

class _LineaCompra {
  ProductoInventario? producto;
  UnidadProducto? unidad;
  final cantidadController = TextEditingController();
  final precioController = TextEditingController();

  double get cantidad => double.tryParse(cantidadController.text.trim()) ?? 0;
  double get precioUnitario =>
      double.tryParse(precioController.text.trim()) ?? 0;
  double get total => cantidad * precioUnitario;

  void dispose() {
    cantidadController.dispose();
    precioController.dispose();
  }
}

class _CompraFormScreenState extends State<CompraFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _proveedorController = TextEditingController();
  final _notasController = TextEditingController();
  final List<_LineaCompra> _lineas = [_LineaCompra()];

  double get _total => _lineas.fold(0.0, (sum, l) => sum + l.total);

  @override
  void dispose() {
    _proveedorController.dispose();
    _notasController.dispose();
    for (final linea in _lineas) {
      linea.dispose();
    }
    super.dispose();
  }

  void _agregarLinea() => setState(() => _lineas.add(_LineaCompra()));

  void _quitarLinea(int index) => setState(() {
    _lineas[index].dispose();
    _lineas.removeAt(index);
  });

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;

    final lineasValidas = _lineas
        .where((l) => l.producto != null && l.cantidad > 0)
        .toList();
    if (lineasValidas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos una línea con producto y cantidad'),
        ),
      );
      return;
    }

    final compraId = DateTime.now().microsecondsSinceEpoch.toString();
    final compra = Compra(
      id: compraId,
      fechaCompra: DateTime.now(),
      proveedor: _proveedorController.text.trim(),
      total: _total,
      notas: _notasController.text.trim().isEmpty
          ? null
          : _notasController.text.trim(),
    );
    final detalles = lineasValidas
        .map(
          (l) => CompraDetalle(
            id: '$compraId-${l.producto!.id}',
            compraId: compraId,
            productoInventarioId: l.producto!.id,
            cantidad: l.cantidad,
            unidadProductoId: (l.unidad ?? mockUnidadesProducto.first).id,
            precioUnitario: l.precioUnitario,
            precioTotal: l.total,
          ),
        )
        .toList();

    registrarCompra(compra, detalles);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva compra')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _proveedorController,
              decoration: const InputDecoration(labelText: 'Proveedor'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Ingresa el proveedor'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notasController,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            Text('Productos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._lineas.asMap().entries.map(
              (entry) => _LineaCompraCard(
                linea: entry.value,
                onChanged: () => setState(() {}),
                onEliminar: _lineas.length > 1
                    ? () => _quitarLinea(entry.key)
                    : null,
              ),
            ),
            TextButton.icon(
              onPressed: _agregarLinea,
              icon: const Icon(Icons.add),
              label: const Text('Agregar línea'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  'S/ ${_total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _guardar,
              child: const Text('Registrar compra'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineaCompraCard extends StatelessWidget {
  final _LineaCompra linea;
  final VoidCallback onChanged;
  final VoidCallback? onEliminar;

  const _LineaCompraCard({
    required this.linea,
    required this.onChanged,
    this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ProductoInventario>(
                    initialValue: linea.producto,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Producto'),
                    items: productosInventario
                        .map(
                          (p) =>
                              DropdownMenuItem(value: p, child: Text(p.nombre)),
                        )
                        .toList(),
                    onChanged: (value) {
                      linea.producto = value;
                      linea.unidad ??= mockUnidadesProducto
                          .where((u) => u.id == value?.unidadProductoId)
                          .firstOrNull;
                      onChanged();
                    },
                  ),
                ),
                if (onEliminar != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onEliminar,
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: linea.cantidadController,
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<UnidadProducto>(
                    initialValue: linea.unidad,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Unidad'),
                    items: mockUnidadesProducto
                        .map(
                          (u) =>
                              DropdownMenuItem(value: u, child: Text(u.unidad)),
                        )
                        .toList(),
                    onChanged: (value) {
                      linea.unidad = value;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: linea.precioController,
                    decoration: const InputDecoration(
                      labelText: 'Precio unitario (S/)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('S/ ${linea.total.toStringAsFixed(2)}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

import 'package:flutter/material.dart';

import '../data/compras_store.dart';
import '../data/inventario_store.dart';
import '../data/catalogos_store.dart';
import '../models/compra.dart';
import '../models/compra_detalle.dart';
import '../models/producto_inventario.dart';
import '../models/unidad_producto.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';

// Registro de una compra a proveedor con sus líneas de detalle. Al guardar,
// repone el stock de cada producto (ver compras_store.dart). Devuelve true
// si se guardó, o null si se cancela.
class CompraFormDialog extends StatefulWidget {
  const CompraFormDialog({super.key});

  @override
  State<CompraFormDialog> createState() => _CompraFormDialogState();
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

class _CompraFormDialogState extends State<CompraFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _proveedorController = TextEditingController();
  final _notasController = TextEditingController();
  final List<_LineaCompra> _lineas = [_LineaCompra()];
  String? _error;

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
      setState(
        () => _error = 'Agrega al menos una línea con producto y cantidad',
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
            unidadProductoId: (l.unidad ?? unidadesProducto.first).id,
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
            : const BoxConstraints(minWidth: 480, maxWidth: 480),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _proveedorController,
                  decoration: const InputDecoration(labelText: 'Proveedor'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa el proveedor'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notasController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'PRODUCTOS',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < _lineas.length; i++)
                  _lineaCard(_lineas[i], i),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _agregarLinea,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: 16,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Agregar línea',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'S/ ${_total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _guardar,
                    style: ElevatedButton.styleFrom(),
                    child: const Text('Registrar compra'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lineaCard(_LineaCompra linea, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppSelect<ProductoInventario>(
                  hint: 'Selecciona un producto',
                  value: linea.producto,
                  items: [
                    for (final p in productosInventario)
                      AppSelectItem(value: p, label: p.nombre),
                  ],
                  onChanged: (v) => setState(() {
                    linea.producto = v;
                    linea.unidad ??= unidadesProducto
                        .where((u) => u.id == v?.unidadProductoId)
                        .firstOrNull;
                  }),
                ),
              ),
              if (_lineas.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _quitarLinea(index),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: linea.cantidadController,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: linea.precioController,
                  decoration: const InputDecoration(
                    labelText: 'Precio unit. (S/)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'S/ ${linea.total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

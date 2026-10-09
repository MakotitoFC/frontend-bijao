import 'package:flutter/material.dart';

import '../data/catalogos_store.dart';
import '../data/compras_store.dart';
import '../data/inventario_store.dart';
import '../models/compra_detalle.dart';
import '../models/producto_inventario.dart';
import '../models/unidad_producto.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';

// Formulario en línea para agregar un detalle (`compra_detalle`) a una compra
// ya creada. El producto se elige de `producto_inventario` y de él se toma la
// unidad base y el stock. Tras agregar, queda listo para el siguiente detalle.
class CompraDetalleForm extends StatefulWidget {
  final String compraId;
  final VoidCallback onAgregado;
  final VoidCallback onCerrar;

  const CompraDetalleForm({
    super.key,
    required this.compraId,
    required this.onAgregado,
    required this.onCerrar,
  });

  @override
  State<CompraDetalleForm> createState() => _CompraDetalleFormState();
}

class _CompraDetalleFormState extends State<CompraDetalleForm> {
  ProductoInventario? _producto;
  UnidadProducto? _unidad;
  final _cantidad = TextEditingController();
  final _factor = TextEditingController();
  final _precio = TextEditingController();
  final _notas = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _cantidad.dispose();
    _factor.dispose();
    _precio.dispose();
    _notas.dispose();
    super.dispose();
  }

  double _leer(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  // Unidad en la que se lleva el stock del producto.
  UnidadProducto? get _unidadBase => unidadesProducto
      .where((u) => u.id == _producto?.unidadProductoId)
      .firstOrNull;

  // Se compra en una unidad distinta de la base: hay que indicar la equivalencia.
  bool get _necesitaFactor =>
      _producto != null &&
      _unidad != null &&
      _unidad!.id != _producto!.unidadProductoId;

  double get _cantidadValor => _leer(_cantidad);
  double get _factorValor => _necesitaFactor ? _leer(_factor) : 1;
  double get _cantidadBase => _cantidadValor * _factorValor;
  double get _precioUnitario => _leer(_precio);
  double get _total => _cantidadValor * _precioUnitario;
  double get _costoUnitarioBase =>
      _cantidadBase > 0 ? _total / _cantidadBase : 0;

  // Sin ceros de más: 50 → "50", 2.5 → "2.5".
  String _num(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');

  void _elegirProducto(ProductoInventario? p) {
    setState(() {
      _producto = p;
      // Por defecto se compra en la unidad base del producto.
      _unidad = _unidadBase;
      _factor.clear();
      _error = null;
    });
  }

  void _guardar() {
    final producto = _producto;
    if (producto == null) {
      setState(() => _error = 'Elige un producto');
      return;
    }
    if (_cantidadValor <= 0) {
      setState(() => _error = 'Ingresa una cantidad mayor que 0');
      return;
    }
    if (_necesitaFactor && _factorValor <= 0) {
      setState(
        () => _error =
            'Indica a cuántas unidades base equivale 1 ${_unidad!.unidad}',
      );
      return;
    }
    if (_precioUnitario <= 0) {
      setState(() => _error = 'Ingresa el precio por unidad');
      return;
    }
    final notas = _notas.text.trim();
    agregarDetalleACompra(
      widget.compraId,
      CompraDetalle(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        compraId: widget.compraId,
        productoInventarioId: producto.id,
        cantidad: _cantidadValor,
        unidadProductoId: _unidad?.id ?? producto.unidadProductoId,
        factorABase: _factorValor,
        cantidadBase: _cantidadBase,
        precioUnitario: _precioUnitario,
        precioTotal: _total,
        costoUnitarioBase: _costoUnitarioBase,
        notas: notas.isEmpty ? null : notas,
      ),
    );
    // Queda en blanco para agregar el siguiente detalle.
    setState(() {
      _producto = null;
      _unidad = null;
      _cantidad.clear();
      _factor.clear();
      _precio.clear();
      _notas.clear();
      _error = null;
    });
    widget.onAgregado();
  }

  @override
  Widget build(BuildContext context) {
    final base = _unidadBase?.unidad ?? 'unidad base';
    final comprada = _unidad?.unidad ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Nuevo detalle',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onCerrar,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AppSelect<ProductoInventario>(
            label: 'Producto',
            hint: 'Selecciona un producto',
            value: _producto,
            items: [
              for (final p in productosInventario)
                AppSelectItem(value: p, label: p.nombre),
            ],
            onChanged: _elegirProducto,
          ),
          if (_producto != null) ...[
            const SizedBox(height: 8),
            Text(
              'Unidad base: $base · Stock actual: ${_num(_producto!.stockActual)} $base',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _cantidad,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppSelect<UnidadProducto>(
                  label: 'Unidad de compra',
                  hint: 'Unidad',
                  value: _unidad,
                  items: [
                    for (final u in unidadesProducto)
                      AppSelectItem(value: u, label: u.unidad),
                  ],
                  onChanged: (v) => setState(() {
                    _unidad = v;
                    if (!_necesitaFactor) _factor.clear();
                  }),
                ),
              ),
            ],
          ),
          if (_necesitaFactor) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _factor,
              decoration: InputDecoration(
                labelText: '1 $comprada equivale a… ($base)',
                helperText: 'Equivalencia de esta compra a la unidad base',
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _precio,
            decoration: InputDecoration(
              labelText: _unidad == null
                  ? 'Precio por unidad (S/)'
                  : 'Precio por $comprada (S/)',
              filled: true,
              fillColor: Colors.white,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notas,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notas (opcional)',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _producto != null && _cantidadBase > 0
                    ? Text(
                        _necesitaFactor
                            ? 'Cantidad base: ${_num(_cantidadValor)} × ${_num(_factorValor)} = ${_num(_cantidadBase)} $base'
                            : 'Cantidad base: ${_num(_cantidadBase)} $base',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Text(
                'S/ ${_total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _guardar,
              child: const Text('Agregar detalle'),
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

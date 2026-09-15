import 'package:flutter/material.dart';

import '../data/mock_tipos_movimiento.dart';
import '../models/inventario_movimiento.dart';
import '../models/producto_inventario.dart';
import '../models/tipo_movimiento.dart';

// Registra una entrada/salida manual de stock. Devuelve el InventarioMovimiento
// resultante via Navigator.pop, o null si se cancela.
class AjustarStockDialog extends StatefulWidget {
  final ProductoInventario producto;

  const AjustarStockDialog({super.key, required this.producto});

  @override
  State<AjustarStockDialog> createState() => _AjustarStockDialogState();
}

class _AjustarStockDialogState extends State<AjustarStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadController = TextEditingController();
  final _notasController = TextEditingController();
  TipoMovimiento _tipoMovimiento = movEntradaManual;

  @override
  void dispose() {
    _cantidadController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;
    final cantidad = double.parse(_cantidadController.text.trim());

    if (!_tipoMovimiento.esEntrada && cantidad > widget.producto.stockActual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cantidad supera el stock disponible')),
      );
      return;
    }

    Navigator.of(context).pop(
      InventarioMovimiento(
        productoInventarioId: widget.producto.id,
        tipoMovimiento: _tipoMovimiento,
        cantidad: cantidad,
        notas: _notasController.text.trim().isEmpty
            ? null
            : _notasController.text.trim(),
        fecha: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ajustar stock · ${widget.producto.nombre}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Stock actual: ${widget.producto.stockActual}'),
            const SizedBox(height: 16),
            DropdownButtonFormField<TipoMovimiento>(
              initialValue: _tipoMovimiento,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tipo de movimiento',
              ),
              items: mockTiposMovimiento
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.tipoMovimiento),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _tipoMovimiento = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cantidadController,
              decoration: const InputDecoration(labelText: 'Cantidad'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa la cantidad';
                final parsed = double.tryParse(v.trim());
                if (parsed == null || parsed <= 0) return 'Cantidad inválida';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notasController,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _confirmar, child: const Text('Registrar')),
      ],
    );
  }
}

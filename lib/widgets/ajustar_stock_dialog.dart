import 'package:flutter/material.dart';

import '../data/catalogos_store.dart';
import '../models/inventario_movimiento.dart';
import '../models/producto_inventario.dart';
import '../models/tipo_movimiento.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';

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
  String? _error;

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
      setState(() => _error = 'La cantidad supera el stock disponible');
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
                    Expanded(
                      child: Text(
                        'Ajustar stock',
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
                const SizedBox(height: 2),
                Text(
                  '${widget.producto.nombre} · stock actual '
                  '${widget.producto.stockActual}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                AppSelect<TipoMovimiento>(
                  label: 'Tipo de movimiento',
                  value: _tipoMovimiento,
                  items: [
                    for (final t in tiposMovimiento)
                      AppSelectItem(value: t, label: t.tipoMovimiento),
                  ],
                  onChanged: (v) => setState(() {
                    _tipoMovimiento = v!;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cantidadController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Cantidad',
                    errorText: _error,
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresa la cantidad';
                    }
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Cantidad inválida';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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
                    onPressed: _confirmar,
                    style: ElevatedButton.styleFrom(),
                    child: const Text('Registrar'),
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

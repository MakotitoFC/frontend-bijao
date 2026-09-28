import 'package:flutter/material.dart';

import '../data/inventario_store.dart';
import '../data/usuarios_store.dart';
import '../data/utensilios_store.dart';
import '../models/mock_user.dart';
import '../models/producto_inventario.dart';
import '../models/utensilio_roto.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';

// Registra la rotura de un utensilio (tabla `utensilio_roto`) y descuenta
// el stock como merma.
class UtensilioRotoFormDialog extends StatefulWidget {
  const UtensilioRotoFormDialog({super.key});

  @override
  State<UtensilioRotoFormDialog> createState() =>
      _UtensilioRotoFormDialogState();
}

class _UtensilioRotoFormDialogState extends State<UtensilioRotoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadController = TextEditingController(text: '1');
  final _costoController = TextEditingController();
  final _notasController = TextEditingController();

  ProductoInventario? _producto =
      productosInventario.isEmpty ? null : productosInventario.first;
  MockUser? _empleado = usuarios.isEmpty ? null : usuarios.first;

  @override
  void initState() {
    super.initState();
    _actualizarCostoSugerido();
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _costoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  void _actualizarCostoSugerido() {
    final cantidad = int.tryParse(_cantidadController.text.trim()) ?? 0;
    final costoUnitario = _producto?.costoReposicion ?? 0;
    _costoController.text = (cantidad * costoUnitario).toStringAsFixed(2);
  }

  void _guardar() {
    if (!_formKey.currentState!.validate() ||
        _producto == null ||
        _empleado == null) {
      return;
    }
    registrarUtensilioRoto(
      UtensilioRoto(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        productoInventarioId: _producto!.id,
        empleadoId: _empleado!.id,
        cantidad: int.parse(_cantidadController.text.trim()),
        costoTotal: double.parse(_costoController.text.trim()),
        fecha: DateTime.now(),
        notas: _notasController.text.trim().isEmpty
            ? null
            : _notasController.text.trim(),
      ),
    );
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
            : const BoxConstraints(minWidth: 420, maxWidth: 420),
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
                        'Registrar rotura',
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
                const SizedBox(height: 14),
                AppSelect<ProductoInventario>(
                  label: 'Producto',
                  value: _producto,
                  items: [
                    for (final p in productosInventario)
                      AppSelectItem(value: p, label: p.nombre),
                  ],
                  onChanged: (v) => setState(() {
                    _producto = v;
                    _actualizarCostoSugerido();
                  }),
                ),
                const SizedBox(height: 14),
                AppSelect<MockUser>(
                  label: 'Empleado responsable',
                  value: _empleado,
                  items: [
                    for (final u in usuarios)
                      AppSelectItem(value: u, label: u.nombre),
                  ],
                  onChanged: (v) => setState(() => _empleado = v),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _cantidadController,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(_actualizarCostoSugerido),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresa la cantidad';
                    }
                    if (int.tryParse(v.trim()) == null ||
                        int.parse(v.trim()) <= 0) {
                      return 'Cantidad inválida';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _costoController,
                  decoration: const InputDecoration(
                    labelText: 'Costo total (S/)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingresa el costo';
                    if (double.tryParse(v.trim()) == null) {
                      return 'Costo inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
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
                    child: const Text('Registrar rotura'),
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

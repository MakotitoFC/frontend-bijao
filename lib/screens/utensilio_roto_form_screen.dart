import 'package:flutter/material.dart';

import '../data/inventario_store.dart';
import '../data/usuarios_store.dart';
import '../data/utensilios_store.dart';
import '../models/mock_user.dart';
import '../models/producto_inventario.dart';
import '../models/utensilio_roto.dart';

// Registra la rotura de un utensilio/producto de inventario (simula
// `utensilio_roto`) y descuenta el stock automáticamente como merma.
class UtensilioRotoFormScreen extends StatefulWidget {
  const UtensilioRotoFormScreen({super.key});

  @override
  State<UtensilioRotoFormScreen> createState() =>
      _UtensilioRotoFormScreenState();
}

class _UtensilioRotoFormScreenState extends State<UtensilioRotoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadController = TextEditingController(text: '1');
  final _costoController = TextEditingController();
  final _notasController = TextEditingController();

  ProductoInventario? _producto = productosInventario.isEmpty
      ? null
      : productosInventario.first;
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
        _empleado == null)
      return;

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
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar utensilio roto')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<ProductoInventario>(
              initialValue: _producto,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Producto'),
              items: productosInventario
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.nombre)))
                  .toList(),
              onChanged: (value) => setState(() {
                _producto = value;
                _actualizarCostoSugerido();
              }),
              validator: (v) => v == null ? 'Selecciona un producto' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MockUser>(
              initialValue: _empleado,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Empleado responsable',
              ),
              items: usuarios
                  .map((u) => DropdownMenuItem(value: u, child: Text(u.nombre)))
                  .toList(),
              onChanged: (value) => setState(() => _empleado = value),
              validator: (v) => v == null ? 'Selecciona un empleado' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cantidadController,
              decoration: const InputDecoration(labelText: 'Cantidad'),
              keyboardType: TextInputType.number,
              onChanged: (_) => _actualizarCostoSugerido(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa la cantidad';
                if (int.tryParse(v.trim()) == null || int.parse(v.trim()) <= 0)
                  return 'Cantidad inválida';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _costoController,
              decoration: const InputDecoration(labelText: 'Costo total (S/)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa el costo';
                if (double.tryParse(v.trim()) == null) return 'Costo inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notasController,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _guardar,
              child: const Text('Registrar rotura'),
            ),
          ],
        ),
      ),
    );
  }
}

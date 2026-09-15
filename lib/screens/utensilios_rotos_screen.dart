import 'package:flutter/material.dart';

import '../data/inventario_store.dart';
import '../data/usuarios_store.dart';
import '../data/utensilios_store.dart';
import 'utensilio_roto_form_screen.dart';

// Historial de utensilios/menaje roto (solo Administrador).
class UtensiliosRotosScreen extends StatefulWidget {
  const UtensiliosRotosScreen({super.key});

  @override
  State<UtensiliosRotosScreen> createState() => _UtensiliosRotosScreenState();
}

class _UtensiliosRotosScreenState extends State<UtensiliosRotosScreen> {
  Future<void> _registrar() async {
    final registrado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const UtensilioRotoFormScreen()),
    );
    if (registrado == true) setState(() {});
  }

  String _nombreProducto(String id) =>
      productosInventario
          .where((p) => p.id == id)
          .map((p) => p.nombre)
          .firstOrNull ??
      'Producto eliminado';

  String _nombreEmpleado(String id) =>
      usuarios.where((u) => u.id == id).map((u) => u.nombre).firstOrNull ??
      'Usuario eliminado';

  String _formatearFecha(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Utensilios rotos')),
      floatingActionButton: FloatingActionButton(
        onPressed: _registrar,
        child: const Icon(Icons.add),
      ),
      body: utensiliosRotos.isEmpty
          ? const Center(child: Text('Aún no se han registrado roturas'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: utensiliosRotos.length,
              itemBuilder: (context, index) {
                final u = utensiliosRotos[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${u.cantidad}x ${_nombreProducto(u.productoInventarioId)}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '${_nombreEmpleado(u.empleadoId)} · ${_formatearFecha(u.fecha)} · S/ ${u.costoTotal.toStringAsFixed(2)}',
                        ),
                        if (u.notas != null) Text(u.notas!),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FilterChip(
                              label: const Text('Pagado'),
                              selected: u.isPagado,
                              onSelected: (value) => setState(() {
                                actualizarUtensilioRoto(
                                  u.copyWith(isPagado: value),
                                );
                              }),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text('Repuesto'),
                              selected: u.isRespuesto,
                              onSelected: (value) => setState(() {
                                actualizarUtensilioRoto(
                                  u.copyWith(isRespuesto: value),
                                );
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

import 'package:flutter/material.dart';

import '../data/compras_store.dart';
import '../data/inventario_store.dart';
import '../data/mock_unidades_producto.dart';
import 'compra_form_screen.dart';

// Historial de compras a proveedor (solo Administrador).
class ComprasScreen extends StatefulWidget {
  const ComprasScreen({super.key});

  @override
  State<ComprasScreen> createState() => _ComprasScreenState();
}

class _ComprasScreenState extends State<ComprasScreen> {
  String _nombreProducto(String id) =>
      productosInventario
          .where((p) => p.id == id)
          .map((p) => p.nombre)
          .firstOrNull ??
      'Producto eliminado';

  String _unidadDe(int id) =>
      mockUnidadesProducto.firstWhere((u) => u.id == id).unidad;

  Future<void> _nuevaCompra() async {
    final creada = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CompraFormScreen()));
    if (creada == true) setState(() {});
  }

  void _verDetalle(String compraId, String proveedor) {
    final detalles = detallesPorCompra[compraId] ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Compra · $proveedor',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: detalles.length,
                  itemBuilder: (context, index) {
                    final d = detalles[index];
                    return ListTile(
                      title: Text(_nombreProducto(d.productoInventarioId)),
                      subtitle: Text(
                        '${d.cantidad} ${_unidadDe(d.unidadProductoId)} × S/ ${d.precioUnitario.toStringAsFixed(2)}',
                      ),
                      trailing: Text('S/ ${d.precioTotal.toStringAsFixed(2)}'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compras')),
      floatingActionButton: FloatingActionButton(
        onPressed: _nuevaCompra,
        child: const Icon(Icons.add),
      ),
      body: compras.isEmpty
          ? const Center(child: Text('Aún no hay compras registradas'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: compras.length,
              itemBuilder: (context, index) {
                final compra = compras[index];
                return Card(
                  child: ListTile(
                    title: Text(compra.proveedor),
                    subtitle: Text(_formatearFecha(compra.fechaCompra)),
                    trailing: Text(
                      'S/ ${compra.total.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    onTap: () => _verDetalle(compra.id, compra.proveedor),
                  ),
                );
              },
            ),
    );
  }

  String _formatearFecha(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

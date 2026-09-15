import 'package:flutter/material.dart';

import '../data/inventario_store.dart';
import '../data/mock_tipos_producto.dart';
import '../data/mock_unidades_producto.dart';
import '../models/inventario_movimiento.dart';
import '../models/producto_inventario.dart';
import '../widgets/ajustar_stock_dialog.dart';
import 'inventario_form_screen.dart';
import 'utensilios_rotos_screen.dart';

// Catálogo de inventario (solo Administrador): CRUD de productos + registro
// manual de entradas/salidas de stock. Los datos viven en inventario_store.dart
// (compartido con el módulo Compras, que también repone stock).
class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  static const double _umbralStockBajo = 5;

  String _tipoProductoDe(int id) =>
      mockTiposProducto.firstWhere((t) => t.id == id).tipoProducto;

  String _unidadDe(int id) =>
      mockUnidadesProducto.firstWhere((u) => u.id == id).unidad;

  Future<void> _crearProducto() async {
    final nuevo = await Navigator.of(context).push<ProductoInventario>(
      MaterialPageRoute(builder: (_) => const InventarioFormScreen()),
    );
    if (nuevo != null) {
      setState(() => agregarProductoInventario(nuevo));
    }
  }

  Future<void> _editarProducto(ProductoInventario producto) async {
    final editado = await Navigator.of(context).push<ProductoInventario>(
      MaterialPageRoute(
        builder: (_) => InventarioFormScreen(producto: producto),
      ),
    );
    if (editado != null) {
      setState(() => actualizarProductoInventario(editado));
    }
  }

  Future<void> _eliminarProducto(ProductoInventario producto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${producto.nombre}" del inventario?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      setState(() => eliminarProductoInventario(producto.id));
    }
  }

  Future<void> _ajustarStock(ProductoInventario producto) async {
    final movimiento = await showDialog<InventarioMovimiento>(
      context: context,
      builder: (_) => AjustarStockDialog(producto: producto),
    );
    if (movimiento == null) return;

    setState(() => registrarMovimientoInventario(movimiento));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${movimiento.tipoMovimiento.tipoMovimiento} registrada para ${producto.nombre}',
        ),
      ),
    );
  }

  void _verHistorial(ProductoInventario producto) {
    final historial = movimientosInventario[producto.id] ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Movimientos · ${producto.nombre}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: historial.isEmpty
                    ? const Center(
                        child: Text('Sin movimientos registrados aún'),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: historial.length,
                        itemBuilder: (context, index) {
                          final m = historial[index];
                          return ListTile(
                            leading: Icon(
                              m.tipoMovimiento.esEntrada
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: m.tipoMovimiento.esEntrada
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            title: Text(
                              '${m.tipoMovimiento.tipoMovimiento} · ${m.cantidad}',
                            ),
                            subtitle: Text(m.notas ?? '—'),
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
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.broken_image_outlined),
            tooltip: 'Utensilios rotos',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const UtensiliosRotosScreen(),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _crearProducto,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: productosInventario.length,
        itemBuilder: (context, index) {
          final producto = productosInventario[index];
          final stockBajo = producto.stockActual <= _umbralStockBajo;
          return Card(
            child: ListTile(
              title: Text(producto.nombre),
              subtitle: Text(
                '${_tipoProductoDe(producto.tipoProductoId)} · '
                '${producto.stockActual} ${_unidadDe(producto.unidadProductoId)}'
                '${producto.estado == 'inactivo' ? ' · Inactivo' : ''}',
                style: stockBajo ? const TextStyle(color: Colors.red) : null,
              ),
              onTap: () => _verHistorial(producto),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.swap_vert),
                    tooltip: 'Ajustar stock',
                    onPressed: () => _ajustarStock(producto),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Editar',
                    onPressed: () => _editarProducto(producto),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Eliminar',
                    onPressed: () => _eliminarProducto(producto),
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

import 'package:flutter/material.dart';

import '../data/insumos_store.dart';
import '../data/inventario_store.dart';
import '../data/mock_unidades_producto.dart';
import '../data/pedidos_store.dart';
import '../models/carta_insumo.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';

// Vista de cocina (comandas): muestra los pedidos activos (no entregados)
// en orden de llegada y permite avanzar su estado.
class CocinaScreen extends StatefulWidget {
  const CocinaScreen({super.key});

  @override
  State<CocinaScreen> createState() => _CocinaScreenState();
}

class _CocinaScreenState extends State<CocinaScreen> {
  List<Pedido> get _pedidosActivos {
    final activos = pedidos.where((p) => p.estado != 'entregado').toList();
    activos.sort((a, b) => a.fechaPedido.compareTo(b.fechaPedido));
    return activos;
  }

  Color _colorDeEstado(String estado, ColorScheme colorScheme) {
    switch (estado) {
      case 'en_preparacion':
        return Colors.blue;
      case 'listo':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  String _etiquetaDeEstado(String estado) {
    switch (estado) {
      case 'en_preparacion':
        return 'En preparación';
      case 'listo':
        return 'Listo';
      case 'entregado':
        return 'Entregado';
      default:
        return 'Pendiente';
    }
  }

  ({String texto, String siguiente})? _siguientePaso(String estado) {
    switch (estado) {
      case 'pendiente':
        return (texto: 'Iniciar preparación', siguiente: 'en_preparacion');
      case 'en_preparacion':
        return (texto: 'Marcar listo', siguiente: 'listo');
      case 'listo':
        return (texto: 'Marcar entregado', siguiente: 'entregado');
      default:
        return null;
    }
  }

  Future<void> _registrarInsumos(
    PedidoLine linea,
    List<CartaInsumo> pendientes,
  ) async {
    final registrado = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _RegistrarInsumoDialog(linea: linea, pendientes: pendientes),
    );
    if (registrado == true) setState(() {});
  }

  String _descripcionLinea(PedidoLine linea) {
    final partes = <String>[
      if (linea.presentacion != null)
        '${linea.presentacion!.unidad.unidadPresentacion} ${linea.presentacion!.volumenMl}ml',
      ...linea.modificadores.map((m) => m.nombre),
      if (linea.comentario != null) linea.comentario!,
    ];
    return partes.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final activos = _pedidosActivos;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: activos.isEmpty
          ? const Center(child: Text('Sin pedidos pendientes'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: activos.length,
              itemBuilder: (context, index) {
                final pedido = activos[index];
                final detalles = detallesPorPedido[pedido.id] ?? [];
                final siguiente = _siguientePaso(pedido.estado);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Mesa ${pedido.mesaNumero}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Chip(
                              label: Text(_etiquetaDeEstado(pedido.estado)),
                              backgroundColor: _colorDeEstado(
                                pedido.estado,
                                colorScheme,
                              ).withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: _colorDeEstado(
                                  pedido.estado,
                                  colorScheme,
                                ),
                              ),
                              side: BorderSide.none,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...detalles.map((linea) {
                          final pendientes = insumosPendientesDe(linea);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _descripcionLinea(linea).isEmpty
                                        ? '${linea.cantidad}x ${linea.nombrePlato}'
                                        : '${linea.cantidad}x ${linea.nombrePlato} — ${_descripcionLinea(linea)}',
                                  ),
                                ),
                                if (pendientes.isNotEmpty)
                                  TextButton(
                                    onPressed: () =>
                                        _registrarInsumos(linea, pendientes),
                                    child: const Text('Registrar insumo'),
                                  ),
                              ],
                            ),
                          );
                        }),
                        if (siguiente != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: () => setState(
                                () => actualizarEstadoPedido(
                                  pedido.id,
                                  siguiente.siguiente,
                                ),
                              ),
                              child: Text(siguiente.texto),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// Registra la cantidad real usada de cada insumo variable (ej. la bebida
// según la presentación elegida) de una línea de pedido ya confirmada.
class _RegistrarInsumoDialog extends StatefulWidget {
  final PedidoLine linea;
  final List<CartaInsumo> pendientes;

  const _RegistrarInsumoDialog({required this.linea, required this.pendientes});

  @override
  State<_RegistrarInsumoDialog> createState() => _RegistrarInsumoDialogState();
}

class _RegistrarInsumoDialogState extends State<_RegistrarInsumoDialog> {
  late final _controladores = {
    for (final r in widget.pendientes) r.id: TextEditingController(),
  };

  @override
  void dispose() {
    for (final c in _controladores.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _nombreProducto(String id) =>
      productosInventario.firstWhere((p) => p.id == id).nombre;

  String _unidadProducto(String id) {
    final unidadId = productosInventario
        .firstWhere((p) => p.id == id)
        .unidadProductoId;
    return mockUnidadesProducto.firstWhere((u) => u.id == unidadId).unidad;
  }

  void _confirmar() {
    for (final receta in widget.pendientes) {
      final cantidad = double.tryParse(_controladores[receta.id]!.text.trim());
      if (cantidad != null && cantidad > 0) {
        registrarConsumoInsumo(widget.linea, receta, cantidad: cantidad);
      }
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Insumos · ${widget.linea.nombrePlato}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.pendientes
            .map(
              (receta) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _controladores[receta.id],
                  decoration: InputDecoration(
                    labelText:
                        '${_nombreProducto(receta.productoInventarioId)} (${_unidadProducto(receta.productoInventarioId)})',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            )
            .toList(),
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

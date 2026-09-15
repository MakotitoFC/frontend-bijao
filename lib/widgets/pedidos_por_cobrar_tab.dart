import 'package:flutter/material.dart';

import '../data/pagos_store.dart';
import '../models/pedido.dart';

// Lista de pedidos listos/entregados pendientes de cobro (total o parcial).
// Usada en PagosScreen.
class PedidosPorCobrarTab extends StatelessWidget {
  final List<Pedido> pedidos;
  final void Function(Pedido pedido) onCobrar;

  const PedidosPorCobrarTab({
    super.key,
    required this.pedidos,
    required this.onCobrar,
  });

  @override
  Widget build(BuildContext context) {
    if (pedidos.isEmpty) {
      return const Center(child: Text('No hay pedidos listos para cobrar'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pedidos.length,
      itemBuilder: (context, index) {
        final pedido = pedidos[index];
        final total = totalDePedido(pedido.id);
        final saldo = saldoPendienteDePedido(pedido.id);
        final esParcial = saldo < total - 0.01;
        return Card(
          child: ListTile(
            title: Text('Mesa ${pedido.mesaNumero}'),
            subtitle: Text(
              esParcial
                  ? '${pedido.estado == 'listo' ? 'Listo' : 'Entregado'} · Pagado S/ ${(total - saldo).toStringAsFixed(2)} de S/ ${total.toStringAsFixed(2)}'
                  : (pedido.estado == 'listo' ? 'Listo' : 'Entregado'),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('S/ ${saldo.toStringAsFixed(2)}'),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => onCobrar(pedido),
                  child: const Text('Cobrar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

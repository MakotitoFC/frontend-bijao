import 'package:flutter/material.dart';

import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../models/pago.dart';
import '../models/pedido.dart';
import '../widgets/cobrar_pedido_dialog.dart';
import '../widgets/pedidos_por_cobrar_tab.dart';

// Cobrar pedidos listos/entregados (ítem "Pagos" del sidebar de escritorio).
class PagosScreen extends StatefulWidget {
  const PagosScreen({super.key});

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen> {
  List<Pedido> get _pedidosPorCobrar => pedidos
      .where((p) => p.estado == 'listo' || p.estado == 'entregado')
      .toList();

  Future<void> _cobrar(Pedido pedido) async {
    final saldo = saldoPendienteDePedido(pedido.id);
    final pago = await showDialog<Pago>(
      context: context,
      builder: (_) => CobrarPedidoDialog(pedido: pedido, saldoPendiente: saldo),
    );
    if (pago != null) {
      setState(() {});
      if (!mounted) return;
      final saldoRestante = saldoPendienteDePedido(pedido.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saldoRestante <= 0.01
                ? 'Cobro registrado · Mesa ${pedido.mesaNumero} · S/ ${pago.montoAbonado.toStringAsFixed(2)}'
                : 'Pago parcial registrado · Mesa ${pedido.mesaNumero} · Saldo restante S/ ${saldoRestante.toStringAsFixed(2)}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PedidosPorCobrarTab(pedidos: _pedidosPorCobrar, onCobrar: _cobrar),
    );
  }
}

import 'package:flutter/material.dart';

import '../data/pagos_store.dart';

// Resumen de caja del día: totales por medio de pago, propinas e historial
// de cobros. Usado en CajaScreen.
class CajaResumenTab extends StatelessWidget {
  const CajaResumenTab({super.key});

  @override
  Widget build(BuildContext context) {
    if (pagos.isEmpty) {
      return const Center(child: Text('Aún no hay cobros registrados'));
    }

    final totalPorMedio = <String, double>{};
    double totalPropinas = 0;
    for (final pago in pagos) {
      totalPorMedio.update(
        pago.medioPago.medioPago,
        (v) => v + pago.montoCobrado,
        ifAbsent: () => pago.montoCobrado,
      );
      totalPropinas += pago.propina;
    }
    final totalCaja = totalPorMedio.values.fold(0.0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen del día',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...totalPorMedio.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key),
                        Text('S/ ${e.value.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Propinas'),
                    Text('S/ ${totalPropinas.toStringAsFixed(2)}'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total caja (neto)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      'S/ ${totalCaja.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Cobros', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...pagos.map(
          (pago) => Card(
            child: ListTile(
              title: Text(
                'Mesa ${pago.mesaNumero} · ${pago.medioPago.medioPago}',
              ),
              subtitle: Text(_formatearHora(pago.fechaPago)),
              trailing: Text('S/ ${pago.montoAbonado.toStringAsFixed(2)}'),
            ),
          ),
        ),
      ],
    );
  }

  String _formatearHora(DateTime fecha) =>
      '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
}

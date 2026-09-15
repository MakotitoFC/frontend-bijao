import 'package:flutter/material.dart';

import '../data/compras_store.dart';
import '../data/inventario_store.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';

// Dashboard de solo lectura que agrega datos de Pagos, Compras, Inventario
// y Pedidos ya registrados en la sesión actual (sin persistencia real aún).
class ReportesScreen extends StatelessWidget {
  const ReportesScreen({super.key});

  static const _umbralStockBajo = 5.0;

  @override
  Widget build(BuildContext context) {
    final totalVentas = pagos.fold(0.0, (sum, p) => sum + p.montoAbonado);
    final totalNeto = pagos.fold(0.0, (sum, p) => sum + p.montoCobrado);
    final totalPropinas = pagos.fold(0.0, (sum, p) => sum + p.propina);
    final totalCompras = compras.fold(0.0, (sum, c) => sum + c.total);

    final ventasPorPlato = <String, int>{};
    for (final lineas in detallesPorPedido.values) {
      for (final linea in lineas) {
        ventasPorPlato.update(
          linea.nombrePlato,
          (v) => v + linea.cantidad,
          ifAbsent: () => linea.cantidad,
        );
      }
    }
    final topPlatos = ventasPorPlato.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final stockBajo = productosInventario
        .where((p) => p.stockActual <= _umbralStockBajo)
        .toList();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReporteCard(
            titulo: 'Ventas',
            filas: [
              ('Pedidos cobrados', '${pagos.length}'),
              ('Total cobrado', 'S/ ${totalVentas.toStringAsFixed(2)}'),
              (
                'Total neto (con comisiones)',
                'S/ ${totalNeto.toStringAsFixed(2)}',
              ),
              ('Propinas', 'S/ ${totalPropinas.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 16),
          _ReporteCard(
            titulo: 'Compras',
            filas: [
              ('Compras registradas', '${compras.length}'),
              ('Total gastado', 'S/ ${totalCompras.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Platos más pedidos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (topPlatos.isEmpty)
                    const Text('Aún no hay pedidos registrados')
                  else
                    ...topPlatos
                        .take(5)
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [Text(e.key), Text('${e.value}x')],
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stock bajo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (stockBajo.isEmpty)
                    const Text('Todo el inventario está en niveles normales')
                  else
                    ...stockBajo.map(
                      (p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(p.nombre),
                            Text(
                              '${p.stockActual}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReporteCard extends StatelessWidget {
  final String titulo;
  final List<(String, String)> filas;

  const _ReporteCard({required this.titulo, required this.filas});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...filas.map(
              (fila) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(fila.$1), Text(fila.$2)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

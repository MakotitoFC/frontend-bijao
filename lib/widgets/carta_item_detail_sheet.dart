import 'package:flutter/material.dart';

import '../data/mock_modificadores.dart';
import '../data/mock_presentaciones.dart';
import '../data/promociones_store.dart';
import '../data/mock_tapers.dart';
import '../models/carta_item.dart';

// Vista de solo consulta de un ítem de la carta (sin agregar al pedido).
class CartaItemDetailSheet extends StatelessWidget {
  final CartaItem item;

  const CartaItemDetailSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final modificadores = mockModificadores
        .where((m) => m.cartaId == item.id)
        .toList();
    final presentaciones = mockPresentaciones
        .where((p) => p.cartaId == item.id)
        .toList();
    final promocion = promocionDeCarta(item.id);
    final taper = item.taperId == null
        ? null
        : mockTapers.where((t) => t.id == item.taperId).firstOrNull;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: ListView(
          controller: scrollController,
          children: [
            Text(
              item.nombrePlato,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              item.descripcion,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (promocion != null) ...[
              const SizedBox(height: 12),
              Chip(
                avatar: const Icon(Icons.local_offer_outlined, size: 18),
                label: Text('${promocion.nombre} (${promocion.etiqueta})'),
              ),
            ],
            const SizedBox(height: 16),
            if (presentaciones.isNotEmpty) ...[
              Text(
                'Presentaciones',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              ...presentaciones.map(
                (p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.local_bar_outlined),
                  title: Text(
                    '${p.unidad.unidadPresentacion} · ${p.volumenMl} ml',
                  ),
                  trailing: Text('S/ ${p.precioCliente.toStringAsFixed(2)}'),
                ),
              ),
            ] else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sell_outlined),
                title: const Text('Precio'),
                trailing: Text('S/ ${item.precioCliente!.toStringAsFixed(2)}'),
              ),
            if (modificadores.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Modificadores disponibles',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              ...modificadores.map(
                (m) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tune),
                  title: Text(m.nombre),
                  trailing: Text(
                    m.precioAjuste > 0
                        ? '+S/ ${m.precioAjuste.toStringAsFixed(2)}'
                        : 'Sin costo',
                  ),
                ),
              ),
            ],
            if (taper != null) ...[
              const SizedBox(height: 8),
              Text(
                'Para llevar',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.takeout_dining_outlined),
                title: Text(taper.nombre),
                trailing: Text('+S/ ${taper.precio.toStringAsFixed(2)}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

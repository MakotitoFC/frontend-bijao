import 'package:flutter/material.dart';

import '../data/presentaciones_store.dart';
import '../data/promociones_store.dart';
import '../data/variantes_store.dart';
import '../models/carta_item.dart';

// Vista de solo consulta de un ítem de la carta (sin agregar al pedido).
class CartaItemDetailSheet extends StatelessWidget {
  final CartaItem item;

  const CartaItemDetailSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final delProducto = presentaciones
        .where((p) => p.cartaId == item.id)
        .toList();
    final tamanos = variantesDeCarta(item.id, soloActivas: true);
    final promocion = promocionDeCarta(item.id);

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
            if (tamanos.isNotEmpty) ...[
              Text('Tamaños', style: Theme.of(context).textTheme.titleSmall),
              ...tamanos.map(
                (v) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.straighten_outlined),
                  title: Text(v.nombre),
                  trailing: Text('S/ ${v.precioCliente.toStringAsFixed(2)}'),
                ),
              ),
            ] else if (delProducto.isNotEmpty) ...[
              Text(
                'Presentaciones',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              ...delProducto.map(
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
                trailing: Text(
                  'S/ ${(item.precioCliente ?? 0).toStringAsFixed(2)}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

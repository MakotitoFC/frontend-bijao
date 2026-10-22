import 'package:flutter/material.dart';

import '../data/presentaciones_store.dart';
import '../data/promociones_store.dart';
import '../data/variantes_store.dart';
import '../models/carta_item.dart';
import 'dialogo_app.dart';
import 'imagen_plato.dart';

// Vista de solo consulta de un ítem de la carta (sin agregar al pedido). Se
// abre con `showBlurDialog`.
class CartaItemDetailSheet extends StatelessWidget {
  final CartaItem item;

  const CartaItemDetailSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final delProducto = presentacionesDeCarta(item.id, soloActivas: true);
    final tamanos = variantesDeCarta(item.id, soloActivas: true);
    final promocion = promocionDeCarta(item.id);

    return DialogoApp(
      titulo: item.nombrePlato,
      children: [
        if (item.urlImagen != null || item.imagenBytes != null) ...[
          AspectRatio(
            aspectRatio: 16 / 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ImagenPlato(item: item, tamanoIcono: 36),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (item.descripcion.isNotEmpty)
          Text(item.descripcion, style: Theme.of(context).textTheme.bodyMedium),
        if (promocion != null) ...[
          const SizedBox(height: 12),
          Chip(
            avatar: const Icon(Icons.local_offer_outlined, size: 18),
            label: Text('${promocion.nombre} (${promocion.etiqueta})'),
          ),
        ],
        const SizedBox(height: 16),
        if (tamanos.isNotEmpty) ...[
          Text('Variantes', style: Theme.of(context).textTheme.titleSmall),
          ...tamanos.map(
            (v) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.straighten_outlined),
              title: Text(v.nombre),
              trailing: Text('S/ ${v.precioCliente.toStringAsFixed(2)}'),
            ),
          ),
        ] else if (delProducto.isNotEmpty) ...[
          Text('Presentaciones', style: Theme.of(context).textTheme.titleSmall),
          ...delProducto.map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_bar_outlined),
              title: Text(
                p.volumenMl > 0
                    ? '${p.unidad.unidadPresentacion} · ${p.volumenMl} ml'
                    : p.unidad.unidadPresentacion,
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
        const SizedBox(height: 16),
      ],
    );
  }
}

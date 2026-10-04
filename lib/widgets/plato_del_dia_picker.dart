import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/cartas_store.dart';
import '../models/carta_item.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'app_toast.dart';

// Elige el plato del día registrado en Productos: si hay uno solo lo devuelve
// directo; si hay varios pide elegir; si no hay ninguno avisa cómo crearlo.
Future<CartaItem?> elegirPlatoDelDia(BuildContext context) async {
  final platos = platosDelDia();
  if (platos.isEmpty) {
    showAppToast(
      context,
      'No hay un plato del día. Márcalo con la estrella "Plato del día" al '
      'crear o editar un producto.',
      type: ToastType.info,
      titulo: 'Plato del día',
    );
    return null;
  }
  if (platos.length == 1) return platos.first;
  return showBlurDialog<CartaItem>(
    context: context,
    builder: (_) => _ElegirPlatoDialog(platos: platos),
  );
}

class _ElegirPlatoDialog extends StatelessWidget {
  final List<CartaItem> platos;

  const _ElegirPlatoDialog({required this.platos});

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final ancho = MediaQuery.sizeOf(context).width;
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: esMobile ? ancho : 420,
          maxWidth: esMobile ? ancho : 420,
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: AppColors.platoDelDia,
              padding: EdgeInsets.fromLTRB(24, esMobile ? 30 : 14, 8, 14),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.chefHat,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Plato del día',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                children: [
                  for (final p in platos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).pop(p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.nombrePlato,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                p.precioCliente == null
                                    ? 'Según tamaño'
                                    : 'S/ ${p.precioCliente!.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.platoDelDia,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/carta_item.dart';
import '../screens/carta_form_screen.dart';
import '../services/catalog_service.dart';
import '../utils/blur_dialog.dart';
import 'app_toast.dart';

// Alta de un producto nuevo (formulario modal) persistiendo en backend con UUID v7.
Future<void> crearPlato(BuildContext context, {String? categoriaId}) async {
  final nuevo = await showBlurDialog<CartaItem>(
    context: context,
    builder: (_) => CartaFormScreen(categoriaInicialId: categoriaId),
  );
  if (nuevo == null) return;

  try {
    await CatalogService.instance.crearPlato(nuevo);
    if (!context.mounted) return;
    showAppToast(
      context,
      '${nuevo.nombrePlato} se guardó en la base de datos.',
      type: ToastType.success,
      titulo: 'Plato creado',
    );
  } catch (e) {
    if (!context.mounted) return;
    showAppToast(
      context,
      'Error al guardar plato: $e',
      type: ToastType.error,
      titulo: 'Error',
    );
  }
}

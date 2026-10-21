import 'package:flutter/material.dart';

import '../screens/carta_form_screen.dart';
import '../services/catalog_service.dart';
import '../utils/blur_dialog.dart';
import 'app_toast.dart';

// Alta de un producto nuevo (formulario modal) persistiendo en backend con UUID v7.
Future<void> crearPlato(BuildContext context, {String? categoriaId}) async {
  final r = await showBlurDialog<ResultadoPlato>(
    context: context,
    builder: (_) => CartaFormScreen(categoriaInicialId: categoriaId),
  );
  if (r == null) return;
  final nuevo = r.item;

  try {
    final creado = await CatalogService.instance.crearPlato(
      nuevo,
      variantes: r.variantes,
      presentacionesPlato: r.presentaciones,
    );
    if (r.foto != null) {
      try {
        final subida = await CatalogService.instance.subirImagenPlato(
          creado,
          r.foto!,
          r.nombreFoto ?? 'plato.jpg',
        );
        if (subida.advertencia != null && context.mounted) {
          showAppToast(
            context,
            'La foto quedó solo en el servidor y no en la nube: '
            '${subida.advertencia}',
            type: ToastType.warning,
            titulo: 'Foto sin copia en la nube',
            duration: const Duration(seconds: 6),
          );
        }
      } catch (e) {
        if (context.mounted) {
          showAppToast(
            context,
            'El plato se creó, pero la foto no se pudo subir. Súbela desde '
            'la carta con el ícono de cámara.',
            type: ToastType.info,
            titulo: 'Foto pendiente',
          );
        }
      }
    }
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

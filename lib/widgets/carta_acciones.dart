import 'package:flutter/material.dart';

import '../data/cartas_store.dart';
import '../models/carta_item.dart';
import '../screens/carta_form_screen.dart';
import '../utils/blur_dialog.dart';
import 'app_toast.dart';

// Alta de un producto nuevo (formulario modal). Compartido entre el botón de
// la cabecera de Productos y cualquier otro punto de entrada.
Future<void> crearPlato(BuildContext context, {String? categoriaId}) async {
  final nuevo = await showBlurDialog<CartaItem>(
    context: context,
    builder: (_) => CartaFormScreen(categoriaInicialId: categoriaId),
  );
  if (nuevo == null) return;
  cartasNotifier.value = [...cartasNotifier.value, nuevo];
  if (!context.mounted) return;
  showAppToast(
    context,
    '${nuevo.nombrePlato} se agregó a la carta.',
    type: ToastType.success,
    titulo: 'Plato creado',
  );
}

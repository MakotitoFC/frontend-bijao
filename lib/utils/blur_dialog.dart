import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Diálogo reutilizado por cualquier modal de la app.
// - Escritorio: centrado con transición suave (blur + fade + escala) en vez
//   del corte brusco del showDialog/showGeneralDialog por defecto.
// - Mobile: hoja inferior (sale desde abajo) con una barra de agarre (handle
//   bar) arriba para deslizar y cerrar, en vez del diálogo centrado.
Future<T?> showBlurDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  if (AppBreakpoints.esMobile(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      isDismissible: barrierDismissible,
      builder: (sheetContext) => Stack(
        alignment: Alignment.topCenter,
        children: [
          builder(sheetContext),
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: _ManijaModal(),
          ),
        ],
      ),
    );
  }

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        builder(dialogContext),
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curva = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 6 * curva.value,
          sigmaY: 6 * curva.value,
        ),
        child: FadeTransition(
          opacity: curva,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curva),
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(24),
              child: Center(child: child),
            ),
          ),
        ),
      );
    },
  );
}

// Barrita gris para deslizar y cerrar la hoja inferior en mobile.
class _ManijaModal extends StatelessWidget {
  const _ManijaModal();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade400,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

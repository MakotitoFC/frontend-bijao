import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/actualizacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'dialogo_app.dart';

// Si el servidor tiene un APK más nuevo, avisa y deja descargarlo: el
// navegador lo baja y Android abre el instalador encima de la versión actual.
Future<void> avisarActualizacion(BuildContext context) async {
  final servicio = ActualizacionService.instance;
  final nueva = await servicio.buscar();
  if (nueva == null || !context.mounted) return;
  servicio.marcarAvisado();
  await showBlurDialog<void>(
    context: context,
    barrierDismissible: !nueva.obligatoria,
    builder: (dialogContext) => PopScope(
      canPop: !nueva.obligatoria,
      child: AlertaApp(
        title: const Text('Nueva versión disponible'),
        content: Text(
          [
            if (nueva.nombre.isNotEmpty)
              'Ya está la versión ${nueva.nombre} de la app.'
            else
              'Ya hay una versión más nueva de la app.',
            if (nueva.notas.isNotEmpty) nueva.notas,
            'Se instala encima de la actual, sin desinstalar.',
          ].join('\n\n'),
        ),
        actions: [
          if (!nueva.obligatoria)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Más tarde'),
            ),
          FilledButton(
            onPressed: () async {
              await launchUrl(
                ActualizacionService.urlDescarga(nueva),
                mode: LaunchMode.externalApplication,
              );
              if (!nueva.obligatoria && dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            child: const Text('Actualizar'),
          ),
        ],
      ),
    ),
  );
}

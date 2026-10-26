import 'package:flutter/material.dart';

import '../data/cierres_store.dart';
import '../services/caja_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'dialogo_app.dart';

// ¿La caja está cerrada? Solo es true si el servidor lo confirma: si no se puede
// leer el estado (por ejemplo, el rol no tiene permiso), no se bloquea nada.
Future<bool> cajaCerrada() async {
  if (!CajaService.instance.enServidor) return false;
  try {
    final estado = await CajaService.instance.cargarEstado();
    return !estado.abierta;
  } catch (_) {
    final e = estadoCajaServidor;
    return e != null && !e.abierta;
  }
}

// Aviso de caja cerrada. Con [irAAbrir] (cajero y administrador) lleva el botón
// "Ir a abrir", que abre la vista de Caja; sin él (mozo) solo avisa.
Future<void> mostrarAvisoCajaCerrada(
  BuildContext context, {
  VoidCallback? irAAbrir,
}) {
  return showBlurDialog<void>(
    context: context,
    builder: (dialogContext) => AlertaApp(
      title: const Text('Caja cerrada'),
      content: Text(
        irAAbrir != null
            ? 'Para registrar pedidos primero se debe abrir la caja.'
            : 'La caja está cerrada. Avisa a caja para que la abra antes de '
                  'registrar pedidos.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(irAAbrir != null ? 'Más tarde' : 'Entendido'),
        ),
        if (irAAbrir != null)
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              irAAbrir();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            child: const Text('Ir a abrir'),
          ),
      ],
    ),
  );
}

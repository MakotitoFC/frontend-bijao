import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/notificaciones_store.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';

// Campana del header: cuenta lo que no se ha leído y abre las notificaciones del
// día (avisos de éxito, error, actualización e información).
class CampanaNotificaciones extends StatefulWidget {
  const CampanaNotificaciones({super.key});

  @override
  State<CampanaNotificaciones> createState() => _CampanaNotificacionesState();
}

class _CampanaNotificacionesState extends State<CampanaNotificaciones> {
  @override
  void initState() {
    super.initState();
    NotificacionesStore.instance.cargar();
  }

  void _abrir() {
    showBlurDialog<void>(
      context: context,
      builder: (_) => const PanelNotificaciones(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Notificacion>>(
      valueListenable: NotificacionesStore.instance.lista,
      builder: (context, lista, _) {
        final sinLeer = lista.where((n) => !n.leida).length;
        return Tooltip(
          message: 'Notificaciones',
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _abrir,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Center(
                      child: Icon(
                        LucideIcons.bell,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ),
              if (sinLeer > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      sinLeer > 9 ? '9+' : '$sinLeer',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Lista de las notificaciones de hoy. Al abrirla se marcan como leídas.
class PanelNotificaciones extends StatefulWidget {
  const PanelNotificaciones({super.key});

  @override
  State<PanelNotificaciones> createState() => _PanelNotificacionesState();
}

class _PanelNotificacionesState extends State<PanelNotificaciones> {
  // Las que estaban sin leer al abrir: se resaltan aunque ya se marquen.
  late final Set<String> _nuevas = {
    for (final n in NotificacionesStore.instance.lista.value)
      if (!n.leida) n.id,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => NotificacionesStore.instance.marcarLeidas(),
    );
  }

  (IconData, Color) _estilo(TipoNotificacion t) => switch (t) {
    TipoNotificacion.exito => (Icons.check_circle, AppColors.success),
    TipoNotificacion.error => (Icons.error, AppColors.error),
    TipoNotificacion.aviso => (Icons.warning_amber_rounded, AppColors.warning),
    TipoNotificacion.info => (Icons.info, AppColors.info),
  };

  String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.sizeOf(context).height;
    return Dialog(
      alignment: Alignment.topRight,
      insetPadding: const EdgeInsets.fromLTRB(16, 70, 16, 16),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: alto * 0.7),
        child: ValueListenableBuilder<List<Notificacion>>(
          valueListenable: NotificacionesStore.instance.lista,
          builder: (context, lista, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Notificaciones de hoy',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (lista.isNotEmpty)
                      TextButton(
                        onPressed: NotificacionesStore.instance.limpiar,
                        child: const Text('Limpiar'),
                      ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (lista.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Text(
                      'Sin notificaciones hoy',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: lista.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 56),
                    itemBuilder: (context, i) {
                      final n = lista[i];
                      final (icono, color) = _estilo(n.tipo);
                      return Container(
                        color: _nuevas.contains(n.id)
                            ? color.withValues(alpha: 0.06)
                            : null,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icono, size: 22, color: color),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.titulo,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    n.mensaje,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _hora(n.fecha),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

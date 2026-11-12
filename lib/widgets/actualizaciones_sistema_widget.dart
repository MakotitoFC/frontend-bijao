import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/config_widgets.dart';

class ActualizacionesSistemaWidget extends StatefulWidget {
  const ActualizacionesSistemaWidget({super.key});

  @override
  State<ActualizacionesSistemaWidget> createState() =>
      _ActualizacionesSistemaWidgetState();
}

class _ActualizacionesSistemaWidgetState
    extends State<ActualizacionesSistemaWidget> {
  bool _verificando = false;
  bool _aplicando = false;
  Map<String, dynamic>? _infoUpdate;
  String? _errorMensaje;

  Future<void> _buscarActualizaciones() async {
    setState(() {
      _verificando = true;
      _errorMensaje = null;
      _infoUpdate = null;
    });

    try {
      final res = await ApiClient.instance.get(
        '/api/v1/sistema/actualizacion/verificar',
      );
      if (res is Map<String, dynamic>) {
        setState(() => _infoUpdate = res);
      }
    } catch (e) {
      setState(() => _errorMensaje = 'No se pudo verificar: $e');
      if (mounted) {
        showAppToast(
          context,
          'Error verificando actualizaciones',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  Future<void> _aplicarActualizacion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.download, color: AppColors.primaryGreen),
            SizedBox(width: 8),
            Text('Confirmar Actualización'),
          ],
        ),
        content: const Text(
          'Se descargarán los paquetes oficiales verificados y se actualizará el sistema.\n\n'
          'Este proceso toma pocos segundos y es seguro contra cortes de energía.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Actualizar ahora'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _aplicando = true);
    try {
      await ApiClient.instance.post(
        '/api/v1/sistema/actualizacion/aplicar',
      );
      if (mounted) {
        showAppToast(
          context,
          'Actualización aplicada. Reiniciando servicio...',
          type: ToastType.success,
        );
      }
      // Esperar 4 segundos y recargar la página en navegador
      await Future.delayed(const Duration(seconds: 4));
      if (mounted) {
        // En web se refresca la ventana
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'Error aplicando actualización: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _aplicando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Actualizaciones del Sistema',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Consulta y aplica nuevas versiones oficiales alojadas en la nube.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: _verificando || _aplicando ? null : _buscarActualizaciones,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              icon: _verificando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(LucideIcons.refreshCw, size: 16),
              label: Text(
                _verificando ? 'Buscando...' : 'Buscar Actualizaciones',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (_errorMensaje != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.alertTriangle,
                  color: Colors.red.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMensaje!,
                    style: TextStyle(fontSize: 13, color: Colors.red.shade800),
                  ),
                ),
              ],
            ),
          ),

        if (_infoUpdate != null) ...[
          if (_infoUpdate!['hay_actualizacion'] == true) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          LucideIcons.sparkles,
                          color: AppColors.primaryGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nueva versión disponible: v${_infoUpdate!['version_disponible']}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F5132),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Versión instalada actual: v${_infoUpdate!['version_actual']}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _aplicando ? null : _aplicarActualizacion,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        icon: _aplicando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(LucideIcons.download, size: 16),
                        label: Text(
                          _aplicando ? 'Actualizando...' : 'Actualizar ahora',
                        ),
                      ),
                    ],
                  ),
                  if (_infoUpdate!['notas'] != null &&
                      _infoUpdate!['notas'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Novedades de esta versión:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _infoUpdate!['notas'].toString(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.checkCircle2,
                    color: Colors.green,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'El sistema está actualizado',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tienes instalada la versión más reciente (v${_infoUpdate!['version_actual']}).',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ] else if (!_verificando && _errorMensaje == null) ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.shieldCheck, color: Colors.grey.shade400, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Actualizaciones Seguras por Demanda',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Las descargas se validan con firmas criptográficas SHA256 antes de instalarse. '
                        'Si se interrumpe la conexión o la laptop se apaga, tus archivos actuales permanecen intactos.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

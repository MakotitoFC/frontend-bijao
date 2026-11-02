import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../services/caja_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'dialogo_app.dart';

/// Modal que avisa al usuario receptor cuando le han traspasado la caja en vivo o al iniciar sesión.
class AvisoTraspasoCajaDialog extends StatelessWidget {
  final Map<String, dynamic> traspaso;
  final VoidCallback? onIrACaja;

  const AvisoTraspasoCajaDialog({
    super.key,
    required this.traspaso,
    this.onIrACaja,
  });

  static Future<void> mostrar(
    BuildContext context, {
    required Map<String, dynamic> traspaso,
    VoidCallback? onIrACaja,
  }) async {
    final traspasoId = traspaso['id']?.toString();
    if (traspasoId != null && traspasoId.isNotEmpty) {
      CajaService.instance.marcarTraspasoVisto(traspasoId).catchError((_) {});
    }

    await showBlurDialog(
      context: context,
      builder: (ctx) => AvisoTraspasoCajaDialog(
        traspaso: traspaso,
        onIrACaja: onIrACaja,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final origen = traspaso['usuario_origen_nombre'] ?? 'Administración';
    final fechaRaw = traspaso['fecha_hora']?.toString() ?? '';
    DateTime? dt = DateTime.tryParse(fechaRaw)?.toLocal();
    final hora = dt != null
        ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}'
        : 'Reciente';

    final motivo = (traspaso['motivo'] ?? '').toString().trim();
    final efectivo = (traspaso['efectivo_esperado'] ?? 0).toString();

    return DialogoApp(
      titulo: '¡Te traspasaron la caja!',
      ancho: 440,
      mostrarCerrar: true,
      acciones: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            onIrACaja?.call();
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
          ),
          icon: Icon(LucideIcons.arrowRight, size: 16),
          label: const Text('Ir a Caja'),
        ),
      ],
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primaryGreen.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.userCheck,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Has sido asignado como responsable de la caja activa.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Todos los cobros y operaciones que realices quedarán registrados a tu nombre.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _filaInfo('Entregado por:', origen, negrita: true),
              const Divider(height: 16),
              _filaInfo('Hora del traspaso:', hora),
              const Divider(height: 16),
              _filaInfo(
                'Efectivo al entregar:',
                'S/ $efectivo',
                colorValor: AppColors.primaryGreen,
                negrita: true,
              ),
              if (motivo.isNotEmpty) ...[
                const Divider(height: 16),
                _filaInfo('Motivo / Nota:', motivo),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _filaInfo(
    String etiqueta,
    String valor, {
    bool negrita = false,
    Color? colorValor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            etiqueta,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: negrita ? FontWeight.w700 : FontWeight.normal,
              color: colorValor ?? Colors.grey.shade900,
            ),
          ),
        ),
      ],
    );
  }
}

/// Modal para consultar el historial de traspasos del turno o día.
class HistorialTraspasosCajaDialog extends StatefulWidget {
  final String? aperturaId;

  const HistorialTraspasosCajaDialog({super.key, this.aperturaId});

  static Future<void> mostrar(BuildContext context, {String? aperturaId}) {
    return showBlurDialog(
      context: context,
      builder: (ctx) => HistorialTraspasosCajaDialog(aperturaId: aperturaId),
    );
  }

  @override
  State<HistorialTraspasosCajaDialog> createState() =>
      _HistorialTraspasosCajaDialogState();
}

class _HistorialTraspasosCajaDialogState
    extends State<HistorialTraspasosCajaDialog> {
  bool _cargando = true;
  String? _error;
  List<Map<String, dynamic>> _traspasos = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final list = await CajaService.instance.cargarTraspasos(
        aperturaId: widget.aperturaId,
      );
      if (mounted) {
        setState(() {
          _traspasos = list;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DialogoApp(
      titulo: 'Historial de Traspasos de Caja',
      ancho: 560,
      mostrarCerrar: true,
      acciones: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
      children: [
        if (_cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          )
        else if (_traspasos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    LucideIcons.users,
                    size: 36,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No se registraron traspasos de caja para este turno.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _traspasos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final t = _traspasos[i];
              final orig = t['usuario_origen_nombre'] ?? 'Usuario';
              final dest = t['usuario_destino_nombre'] ?? 'Usuario';
              final motivo = (t['motivo'] ?? '').toString().trim();
              final efectivo = (t['efectivo_esperado'] ?? 0).toString();
              final visto = t['visto_por_destino'] == true;

              final fechaRaw = t['fecha_hora']?.toString() ?? '';
              DateTime? dt = DateTime.tryParse(fechaRaw)?.toLocal();
              final hora = dt != null
                  ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}'
                  : '';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          hora,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: visto
                                ? Colors.green.shade50
                                : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: visto
                                  ? Colors.green.shade200
                                  : Colors.amber.shade200,
                            ),
                          ),
                          child: Text(
                            visto ? 'Visto' : 'Pendiente aviso',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: visto
                                  ? Colors.green.shade800
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade900,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'De: ',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                TextSpan(
                                  text: orig,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const TextSpan(text: '  ➔  '),
                                const TextSpan(
                                  text: 'A: ',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                TextSpan(
                                  text: dest,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          'S/ $efectivo',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (motivo.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Motivo: $motivo',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

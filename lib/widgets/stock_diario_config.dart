import 'package:flutter/material.dart';

import '../data/disponibilidad_store.dart';
import '../models/disponibilidad.dart';
import '../services/disponibilidad_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'apertura_diaria_dialog.dart';
import 'app_toast.dart';
import 'config_widgets.dart';
import 'stock_base_dialog.dart';

// Pestaña "Stock diario" de Configuración: cómo maneja la sede las cantidades
// de platos y la apertura del día (`sede_config_stock`).
class StockDiarioConfig extends StatefulWidget {
  const StockDiarioConfig({super.key});

  @override
  State<StockDiarioConfig> createState() => _StockDiarioConfigState();
}

class _StockDiarioConfigState extends State<StockDiarioConfig> {
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    DisponibilidadService.instance.cargarHoy();
  }

  Future<void> _guardar({
    bool? requiereAperturaDiaria,
    bool? permiteSobreventa,
    bool? autoAgotar,
  }) async {
    setState(() => _guardando = true);
    try {
      await DisponibilidadService.instance.guardarConfig(
        requiereAperturaDiaria: requiereAperturaDiaria,
        permiteSobreventa: permiteSobreventa,
        autoAgotar: autoAgotar,
      );
      if (!mounted) return;
      showAppToast(context, 'Configuración guardada.', type: ToastType.success);
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'No se pudo guardar: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppBreakpoints.esMobile(context) ? 16 : 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: ValueListenableBuilder<SedeConfigStock?>(
            valueListenable: configStockNotifier,
            builder: (context, cfg, _) {
              if (cfg == null) return _sinDatos();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SeccionConfig(
                    titulo: 'Cantidades diarias de platos',
                    descripcion: 'Cómo se controla cuántas porciones se pueden vender cada día.',
                    filas: [
                      FilaSwitch(
                        titulo: 'Exigir apertura diaria',
                        descripcion:
                            'Un plato sin cantidad registrada hoy no se puede vender. '
                            'Desactivado: se vende libre hasta que lo marquen agotado.',
                        valor: cfg.requiereAperturaDiaria,
                        onChanged: _guardando
                            ? null
                            : (v) => _guardar(requiereAperturaDiaria: v),
                      ),
                      FilaSwitch(
                        titulo: 'Permitir sobreventa',
                        descripcion:
                            'Seguir vendiendo aunque la cantidad llegue a 0.',
                        valor: cfg.permiteSobreventa,
                        onChanged: _guardando
                            ? null
                            : (v) => _guardar(permiteSobreventa: v),
                      ),
                      FilaSwitch(
                        titulo: 'Marcar agotado automáticamente',
                        descripcion:
                            'Al llegar a 0 el plato queda como agotado solo.',
                        valor: cfg.autoAgotar,
                        onChanged: _guardando
                            ? null
                            : (v) => _guardar(autoAgotar: v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SeccionConfig(
                    titulo: 'Apertura del día',
                    descripcion:
                        'Cada mañana indica cuántas porciones tendrás de cada '
                        'plato. Así el sistema te avisa cuando se acaban.',
                    filas: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ayudaApertura(
                          pasos: const [
                            (
                              'Cantidades base (una sola vez):',
                              'define cuántas porciones sueles preparar de '
                                  'cada plato.',
                            ),
                            (
                              'Abrir el día (cada día):',
                              'revisa o ajusta las porciones de hoy y guarda. '
                                  'Con "Usar cantidades base" se llenan solas.',
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => showBlurDialog<bool>(
                                  context: context,
                                  builder: (_) => const StockBaseDialog(),
                                ),
                                icon: const Icon(Icons.tune, size: 18),
                                label: const Text('1. Definir cantidades base'),
                              ),
                              FilledButton.icon(
                                onPressed: () => showBlurDialog<bool>(
                                  context: context,
                                  builder: (_) => const AperturaDiariaDialog(),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                ),
                                icon: const Icon(
                                  Icons.event_available,
                                  size: 18,
                                ),
                                label: const Text('2. Abrir el día de hoy'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sinDatos() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Text(
            'No se pudo leer la configuración de stock.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: DisponibilidadService.instance.cargarHoy,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

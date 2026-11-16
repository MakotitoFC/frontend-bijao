import 'package:flutter/material.dart';

import '../data/disponibilidad_store.dart';
import '../models/disponibilidad.dart';
import '../services/disponibilidad_service.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';
import 'config_widgets.dart';

// Pestaña "Stock" de Configuración: qué pasa cuando un producto del inventario
// se agota (`sede_config_stock`). Por defecto se sigue vendiendo: el stock del
// inventario no limita los pedidos, solo se avisa con la etiqueta "Agotado".
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

  Future<void> _guardar({required bool bloquearAgotadoInventario}) async {
    setState(() => _guardando = true);
    try {
      await DisponibilidadService.instance.guardarConfig(
        bloquearAgotadoInventario: bloquearAgotadoInventario,
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
              return SeccionConfig(
                titulo: 'Inventario agotado',
                descripcion:
                    'Qué pasa al pedir un plato cuyo producto de inventario '
                    'está en 0. En la carta siempre se ve la etiqueta "Agotado".',
                filas: [
                  FilaSwitch(
                    titulo: 'Seguir vendiendo cuando el inventario se agote',
                    descripcion:
                        'Activado: el plato agotado se puede pedir (el mozo '
                        'recibe un aviso). Desactivado: no se puede pedir.',
                    valor: !cfg.bloquearAgotadoInventario,
                    onChanged: _guardando
                        ? null
                        : (v) => _guardar(bloquearAgotadoInventario: !v),
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

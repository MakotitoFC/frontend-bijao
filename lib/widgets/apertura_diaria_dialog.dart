import 'package:flutter/material.dart';

import '../data/cartas_store.dart';
import '../data/disponibilidad_store.dart';
import '../models/carta_item.dart';
import '../services/disponibilidad_service.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';
import 'pago_dialogs.dart';
import 'app_switch.dart';
import 'campo_texto.dart';

// Apertura del día: cuántas porciones hay hoy de cada plato. Vacío = sin
// límite (se vende hasta que el administrador lo marque agotado). Puede
// precargar las cantidades base de cada plato (`carta_stock_base`).
class AperturaDiariaDialog extends StatefulWidget {
  const AperturaDiariaDialog({super.key});

  @override
  State<AperturaDiariaDialog> createState() => _AperturaDiariaDialogState();
}

class _FilaApertura {
  final CartaItem plato;
  final TextEditingController cantidad = TextEditingController();
  bool agotado = false;
  // Valores con los que se abrió la fila, para enviar solo lo que cambió.
  String cantidadOriginal = '';
  bool agotadoOriginal = false;

  _FilaApertura(this.plato);

  void cargarDesdeStore() {
    final f = filaGeneralDe(plato.id);
    final texto = f?.cantidadInicial?.toString() ?? '';
    cantidad.text = texto;
    cantidadOriginal = texto;
    agotado = f?.agotado ?? false;
    agotadoOriginal = agotado;
  }

  int? get cantidadValor => int.tryParse(cantidad.text.trim());
  bool get cambio =>
      cantidad.text.trim() != cantidadOriginal || agotado != agotadoOriginal;
}

class _AperturaDiariaDialogState extends State<AperturaDiariaDialog> {
  late final List<_FilaApertura> _filas;
  String _busqueda = '';
  bool _trabajando = false;

  @override
  void initState() {
    super.initState();
    final platos = [...cartasNotifier.value]
      ..sort((a, b) => a.nombrePlato.compareTo(b.nombrePlato));
    _filas = [for (final p in platos) _FilaApertura(p)..cargarDesdeStore()];
  }

  @override
  void dispose() {
    for (final f in _filas) {
      f.cantidad.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarBase() async {
    setState(() => _trabajando = true);
    try {
      await DisponibilidadService.instance.aperturaDiaria(usarBase: true);
      if (!mounted) return;
      setState(() {
        for (final f in _filas) {
          f.cargarDesdeStore();
        }
      });
      showAppToast(
        context,
        'Se cargaron las cantidades base.',
        type: ToastType.success,
      );
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'No se pudo cargar: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _guardar() async {
    final items = [
      for (final f in _filas)
        if (f.cambio)
          AperturaItem(
            cartaId: f.plato.id,
            cantidadInicial: f.cantidadValor,
            agotado: f.agotado != f.agotadoOriginal ? f.agotado : null,
          ),
    ];
    if (items.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _trabajando = true);
    try {
      await DisponibilidadService.instance.aperturaDiaria(items: items);
      if (!mounted) return;
      showAppToast(
        context,
        'Apertura del día guardada (${items.length} plato(s)).',
        type: ToastType.success,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'No se pudo guardar: $e', type: ToastType.error);
        setState(() => _trabajando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final termino = _busqueda.trim().toLowerCase();
    final visibles = [
      for (final f in _filas)
        if (termino.isEmpty || f.plato.nombrePlato.toLowerCase().contains(termino))
          f,
    ];
    return ModalPago(
      titulo: 'Apertura del día',
      subtitulo: 'Porciones disponibles hoy. Vacío = sin límite.',
      anchoEscritorio: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: CampoTexto(
                  onChanged: (v) => setState(() => _busqueda = v),
                  decoration: const InputDecoration(
                    hintText: 'Buscar plato...',
                    prefixIcon: Icon(Icons.search, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _trabajando ? null : _cargarBase,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Cantidades base'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (visibles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Sin platos',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            ),
          for (final f in visibles) _fila(f),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _trabajando ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _trabajando ? null : _guardar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
                child: _trabajando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar apertura'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fila(_FilaApertura f) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              f.plato.nombrePlato,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: f.agotado ? Colors.grey : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: CampoTexto(
              controller: f.cantidad,
              enabled: !f.agotado,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Sin límite',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Agotado hoy',
            child: AppSwitch(
              value: f.agotado,
              onChanged: (v) => setState(() => f.agotado = v),
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

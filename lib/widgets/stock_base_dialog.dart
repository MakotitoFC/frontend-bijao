import 'package:flutter/material.dart';

import '../data/cartas_store.dart';
import '../models/carta_item.dart';
import '../services/disponibilidad_service.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';
import 'pago_dialogs.dart';
import 'campo_texto.dart';

// Cantidades base: cuántas porciones se precargan de cada plato al abrir el
// día (el botón "Cantidades base" de la apertura). Vacío = sin cantidad base.
class StockBaseDialog extends StatefulWidget {
  const StockBaseDialog({super.key});

  @override
  State<StockBaseDialog> createState() => _StockBaseDialogState();
}

class _FilaBase {
  final CartaItem plato;
  final TextEditingController cantidad = TextEditingController();
  String? idExistente; // fila general ya guardada en el backend
  String original = '';

  _FilaBase(this.plato);

  bool get cambio => cantidad.text.trim() != original;
  int? get valor => int.tryParse(cantidad.text.trim());
}

class _StockBaseDialogState extends State<StockBaseDialog> {
  late final List<_FilaBase> _filas;
  bool _cargando = true;
  bool _guardando = false;
  String _busqueda = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    final platos = [...cartasNotifier.value]
      ..sort((a, b) => a.nombrePlato.compareTo(b.nombrePlato));
    _filas = [for (final p in platos) _FilaBase(p)];
    _cargar();
  }

  @override
  void dispose() {
    for (final f in _filas) {
      f.cantidad.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final bases = await DisponibilidadService.instance.cargarStockBase();
      if (!mounted) return;
      setState(() {
        for (final f in _filas) {
          final b = bases
              .where((x) => x.cartaId == f.plato.id && x.esGeneral)
              .firstOrNull;
          f.idExistente = b?.id;
          f.original = b?.cantidadPredeterminada.toString() ?? '';
          f.cantidad.text = f.original;
        }
        _cargando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = 'No se pudieron leer las cantidades base: $e';
        });
      }
    }
  }

  Future<void> _guardar() async {
    for (final f in _filas) {
      if (f.cambio &&
          f.cantidad.text.trim().isNotEmpty &&
          (f.valor ?? 0) <= 0) {
        showAppToast(
          context,
          'La cantidad de "${f.plato.nombrePlato}" debe ser mayor que 0.',
          type: ToastType.error,
        );
        return;
      }
    }
    setState(() => _guardando = true);
    var guardados = 0;
    try {
      for (final f in _filas.where((f) => f.cambio)) {
        if (f.cantidad.text.trim().isEmpty) {
          if (f.idExistente != null) {
            await DisponibilidadService.instance.eliminarStockBase(
              f.idExistente!,
            );
          }
        } else {
          await DisponibilidadService.instance.guardarStockBase(
            f.plato.id,
            f.valor!,
          );
        }
        guardados++;
      }
      if (!mounted) return;
      showAppToast(
        context,
        'Cantidades base guardadas ($guardados).',
        type: ToastType.success,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'No se pudo guardar: $e', type: ToastType.error);
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final termino = _busqueda.trim().toLowerCase();
    final visibles = [
      for (final f in _filas)
        if (termino.isEmpty ||
            f.plato.nombrePlato.toLowerCase().contains(termino))
          f,
    ];
    return ModalPago(
      titulo: 'Cantidades base',
      subtitulo: 'Porciones que se precargan cada día al abrir.',
      anchoEscritorio: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CampoTexto(
            onChanged: (v) => setState(() => _busqueda = v),
            decoration: const InputDecoration(
              hintText: 'Buscar plato...',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            )
          else
            for (final f in visibles) _fila(f),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _guardando
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: (_guardando || _cargando || _error != null)
                    ? null
                    : _guardar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fila(_FilaBase f) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              f.plato.nombrePlato,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: CampoTexto(
              controller: f.cantidad,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'Sin base',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

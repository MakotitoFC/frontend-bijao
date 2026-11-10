import 'package:flutter/material.dart';

import '../data/inventario_store.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import 'campo_texto.dart';
import 'dialogo_app.dart';
import 'inventario/inventario_comun.dart';

// Anular una compra guardada. Pide el motivo (obligatorio), avisa cuánto stock
// se descontará de cada producto y, al confirmar, revierte ese stock. La compra
// no se borra: queda visible como anulada con su motivo. Devuelve true si se
// anuló.
class AnularCompraDialog extends StatefulWidget {
  final String compraId;

  const AnularCompraDialog({super.key, required this.compraId});

  @override
  State<AnularCompraDialog> createState() => _AnularCompraDialogState();
}

class _AnularCompraDialogState extends State<AnularCompraDialog> {
  final _motivo = TextEditingController();
  Map<String, double>? _descuento;
  bool _anulando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    CatalogService.instance.stockQueSeDescontaria(widget.compraId).then((m) {
      if (mounted) setState(() => _descuento = m);
    });
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  String _nombre(String id) =>
      productosInventario.where((p) => p.id == id).firstOrNull?.nombre ??
      'Producto';

  String _unidad(String id) {
    final p = productosInventario.where((x) => x.id == id).firstOrNull;
    return p == null ? '' : unidadDe(p.unidadProductoId);
  }

  Future<void> _anular() async {
    if (_motivo.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el motivo de la anulación.');
      return;
    }
    setState(() {
      _anulando = true;
      _error = null;
    });
    try {
      await CatalogService.instance.anularCompra(widget.compraId, _motivo.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _anulando = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _descuento;
    return DialogoApp(
      titulo: 'Anular compra',
      ancho: 440,
      acciones: [
        OutlinedButton(
          onPressed: _anulando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: _anulando ? null : _anular,
          child: const Text('Anular compra'),
        ),
      ],
      children: [
        Text(
          d == null
              ? 'Calculando el stock que se descontará…'
              : d.isEmpty
              ? 'Esta compra ya no tiene stock por descontar.'
              : 'Se descontará del almacén:',
          style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700),
        ),
        if (d != null)
          for (final e in d.entries)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '• ${_nombre(e.key)}: ${cantidadTexto(e.value)} ${_unidad(e.key)}',
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
        const SizedBox(height: 14),
        CampoTexto(
          controller: _motivo,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Motivo de la anulación',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(fontSize: 12.5, color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

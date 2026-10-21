import 'package:flutter/material.dart';

import '../data/pagos_store.dart';
import '../models/comprobante.dart';
import '../models/pedido.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'comprobante_en_cobro.dart';
import 'dialogo_app.dart';

// Emite el comprobante de un pedido ya cobrado (o un ticket de venta): lo usa
// el historial cuando el cliente pide su boleta o factura después de pagar.
// Devuelve el comprobante emitido, o null si se cancela.
class EmitirComprobanteDialog extends StatefulWidget {
  final Pedido pedido;

  const EmitirComprobanteDialog({super.key, required this.pedido});

  @override
  State<EmitirComprobanteDialog> createState() =>
      _EmitirComprobanteDialogState();
}

class _EmitirComprobanteDialogState extends State<EmitirComprobanteDialog> {
  late final ComprobanteEnCobro _eleccion =
      ComprobanteEnCobro(
        totalDePedido(widget.pedido.id),
        tipoInicial: 'ticket_venta',
      )..addListener(() {
        if (mounted) setState(() {});
      });

  bool _emitiendo = false;
  String? _error;

  @override
  void dispose() {
    _eleccion.dispose();
    super.dispose();
  }

  // El servidor no deja facturar (boleta o factura) un pedido sin cobros: el
  // ticket de venta interno sí.
  bool get _tieneCobro =>
      pagos.any((p) => p.pedidoId == widget.pedido.id && !p.esReembolso);
  bool get _bloqueadoPorCobro =>
      _eleccion.tipo != 'ticket_venta' && !_tieneCobro;
  bool get _puedeEmitir =>
      !_emitiendo && !_bloqueadoPorCobro && _eleccion.completo;

  Future<void> _emitir() async {
    if (!_puedeEmitir) return;
    setState(() {
      _emitiendo = true;
      _error = null;
    });
    try {
      final c = await _eleccion.emitir(widget.pedido);
      if (mounted) Navigator.of(context).pop<Comprobante>(c);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _emitiendo = false;
        _error = e is ApiException
            ? e.message
            : e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DialogoApp(
      titulo: 'Emitir comprobante · Pedido #${widget.pedido.numeroPedido}',
      ancho: 460,
      acciones: [
        OutlinedButton(
          onPressed: _emitiendo ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _puedeEmitir ? _emitir : null,
          child: _emitiendo
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Emitir comprobante'),
        ),
      ],
      children: [
        Text(
          'Total del pedido: S/ ${_eleccion.total.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SelectorComprobante(control: _eleccion, permiteNinguno: false),
        if (_bloqueadoPorCobro)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Para emitir una boleta o factura el pedido debe tener un cobro '
              'registrado. Cóbralo primero, o emite un ticket de venta.',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

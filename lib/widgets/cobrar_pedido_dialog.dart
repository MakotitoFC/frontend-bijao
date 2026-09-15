import 'package:flutter/material.dart';

import '../data/mock_medios_pago.dart';
import '../data/pagos_store.dart';
import '../models/medio_pago.dart';
import '../models/pedido.dart';

// Registra el cobro (total o parcial) de un pedido: elige medio de pago,
// cuánto se cobra ahora (por defecto el saldo pendiente) y propina opcional.
// Ese monto se reparte automáticamente entre las líneas del pedido con
// saldo pendiente (ver pagos_store.registrarPago). Devuelve el Pago
// resultante via Navigator.pop, o null si se cancela.
class CobrarPedidoDialog extends StatefulWidget {
  final Pedido pedido;
  final double saldoPendiente;

  const CobrarPedidoDialog({
    super.key,
    required this.pedido,
    required this.saldoPendiente,
  });

  @override
  State<CobrarPedidoDialog> createState() => _CobrarPedidoDialogState();
}

class _CobrarPedidoDialogState extends State<CobrarPedidoDialog> {
  MedioPago _medioPago = medioEfectivo;
  late final _montoController = TextEditingController(
    text: widget.saldoPendiente.toStringAsFixed(2),
  );
  final _propinaController = TextEditingController();

  @override
  void dispose() {
    _montoController.dispose();
    _propinaController.dispose();
    super.dispose();
  }

  double get _monto => double.tryParse(_montoController.text.trim()) ?? 0;

  double get _comision => _medioPago.aplicaComision
      ? _monto * (_medioPago.porcentajeComision / 100)
      : 0;

  void _confirmar() {
    if (_monto <= 0 || _monto > widget.saldoPendiente + 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El monto debe ser mayor a 0 y no superar el saldo pendiente',
          ),
        ),
      );
      return;
    }
    final propina = double.tryParse(_propinaController.text.trim()) ?? 0;
    final pago = registrarPago(
      pedido: widget.pedido,
      medioPago: _medioPago,
      montoAbonado: _monto,
      propina: propina,
    );
    Navigator.of(context).pop(pago);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cobrar · Mesa ${widget.pedido.mesaNumero}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Saldo pendiente: S/ ${widget.saldoPendiente.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _montoController,
            decoration: const InputDecoration(
              labelText: 'Monto a cobrar ahora (S/)',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<MedioPago>(
            initialValue: _medioPago,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Medio de pago'),
            items: mockMediosPago
                .map(
                  (m) => DropdownMenuItem(value: m, child: Text(m.medioPago)),
                )
                .toList(),
            onChanged: (value) => setState(() => _medioPago = value!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _propinaController,
            decoration: const InputDecoration(
              labelText: 'Propina (opcional, S/)',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          if (_medioPago.aplicaComision) ...[
            const SizedBox(height: 12),
            Text(
              'Comisión (${_medioPago.porcentajeComision.toStringAsFixed(1)}%): '
              '-S/ ${_comision.toStringAsFixed(2)}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_monto > 0 && _monto < widget.saldoPendiente - 0.01) ...[
            const SizedBox(height: 12),
            Text(
              'Quedará un saldo pendiente de S/ ${(widget.saldoPendiente - _monto).toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirmar,
          child: const Text('Confirmar cobro'),
        ),
      ],
    );
  }
}

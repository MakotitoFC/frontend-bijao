import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/configuracion_store.dart';
import '../data/pagos_store.dart';
import '../models/medio_pago.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';
import 'app_toast.dart';

const naranjaPago = Color(0xFFF07F13);

double leerMonto(String texto) =>
    double.tryParse(texto.trim().replaceAll(',', '.')) ?? 0;

// Contenedor común de los modales de pago (hoja en mobile, tarjeta en escritorio).
class ModalPago extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Widget child;
  final double anchoEscritorio;

  const ModalPago({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.child,
    this.anchoEscritorio = 440,
  });

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final ancho = MediaQuery.sizeOf(context).width;
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: esMobile ? ancho : anchoEscritorio,
          maxWidth: esMobile ? ancho : anchoEscritorio,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, esMobile ? 28 : 22, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitulo,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(child: SingleChildScrollView(child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

Widget tarjetaSaldo(String etiqueta, double monto) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          'S/ ${monto.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryGreen,
          ),
        ),
      ],
    ),
  );
}

// Cobra de una vez todo el saldo pendiente con un solo método de pago.
// Devuelve true si el cobro se registró.
class PagarPedidoDialog extends StatefulWidget {
  final Pedido pedido;
  final String titulo;

  const PagarPedidoDialog({
    super.key,
    required this.pedido,
    required this.titulo,
  });

  @override
  State<PagarPedidoDialog> createState() => _PagarPedidoDialogState();
}

class _PagarPedidoDialogState extends State<PagarPedidoDialog> {
  late MedioPago _medio = mediosPagoActivos.first;
  double get _saldo => saldoPendienteDePedido(widget.pedido.id);
  double get _comision =>
      _medio.aplicaComision ? _saldo * _medio.porcentajeComision / 100 : 0;

  void _pagar() {
    final saldo = _saldo;
    if (saldo <= 0.01) return;
    registrarPago(
      pedido: widget.pedido,
      medioPago: _medio,
      montoAbonado: saldo,
      propina: 0,
    );
    showAppToast(
      context,
      'Cobro registrado · ${widget.titulo} · S/ ${saldo.toStringAsFixed(2)}',
      type: ToastType.success,
      titulo: 'Pago registrado',
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final saldo = _saldo;
    return ModalPago(
      titulo: 'Pagar pedido #${widget.pedido.numeroPedido}',
      subtitulo: widget.titulo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tarjetaSaldo('Total a pagar', saldo),
          const SizedBox(height: 16),
          AppSelect<String>(
            label: 'Método de pago',
            value: _medio.id,
            items: [
              for (final m in mediosPagoActivos)
                AppSelectItem(
                  value: m.id,
                  label: m.aplicaComision
                      ? '${m.medioPago} (+${m.porcentajeComision.toStringAsFixed(1)}%)'
                      : m.medioPago,
                ),
            ],
            onChanged: (v) => setState(() {
              if (v != null) {
                _medio = mediosPagoActivos.firstWhere((m) => m.id == v);
              }
            }),
          ),
          if (_medio.aplicaComision)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Comisión (${_medio.porcentajeComision.toStringAsFixed(1)}%): '
                '-S/ ${_comision.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: saldo > 0.01 ? _pagar : null,
            icon: const Icon(LucideIcons.banknote, size: 18),
            label: Text(
              'Pagar · S/ ${saldo.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(backgroundColor: naranjaPago),
          ),
        ],
      ),
    );
  }
}

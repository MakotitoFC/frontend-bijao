import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/pedido.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';
import 'pago_compartido_dialog.dart';

// Una boleta por pagador, para cuando cada uno pide la suya tras un pago
// compartido.
class BoletasPagadoresDialog extends StatelessWidget {
  final Pedido pedido;
  final List<BoletaPagador> boletas;

  const BoletasPagadoresDialog({
    super.key,
    required this.pedido,
    required this.boletas,
  });

  String _soles(double v) => 'S/ ${v.toStringAsFixed(2)}';

  Widget _fila(String a, String b, {bool fuerte = false}) {
    final estilo = TextStyle(
      fontSize: fuerte ? 14 : 12,
      fontWeight: fuerte ? FontWeight.w800 : FontWeight.w500,
      color: fuerte ? Colors.black87 : Colors.grey.shade700,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(a, style: estilo)),
          Text(b, style: estilo),
        ],
      ),
    );
  }

  Widget _boleta(BuildContext context, int i, BoletaPagador b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Boleta ${i + 1} · ${b.nombre}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Pedido #${pedido.numeroPedido}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          for (final it in b.items) _fila(it.descripcion, _soles(it.monto)),
          const SizedBox(height: 6),
          Divider(height: 1, color: Colors.grey.shade300),
          const SizedBox(height: 6),
          _fila('Total', _soles(b.total), fuerte: true),
          const SizedBox(height: 6),
          for (final p in b.pagos)
            _fila('Pago · ${p.medio.medioPago}', _soles(p.monto)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => showAppToast(
                context,
                'Boleta de ${b.nombre} enviada a imprimir.',
                type: ToastType.success,
              ),
              style: FilledButton.styleFrom(backgroundColor: AppColors.navbar),
              icon: const Icon(LucideIcons.printer, size: 16),
              label: const Text('Imprimir'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final ancho = MediaQuery.sizeOf(context).width;
    return Material(
      color: const Color(0xFFF7F8FA),
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: esMobile ? ancho : 460,
          maxWidth: esMobile ? ancho : 460,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, esMobile ? 28 : 22, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Boletas por pagador',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (var i = 0; i < boletas.length; i++)
                      _boleta(context, i, boletas[i]),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

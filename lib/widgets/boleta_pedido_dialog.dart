import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';

// Boleta imprimible del pedido (`pedidos`, `pedidos_detalle`, `usuarios`, `pagos`).
class BoletaPedidoDialog extends StatelessWidget {
  final Pedido pedido;
  final String mesero;
  final String titulo;
  final String metodoPago;
  final VoidCallback onImprimir;
  final VoidCallback onCerrar;

  const BoletaPedidoDialog({
    super.key,
    required this.pedido,
    required this.mesero,
    required this.titulo,
    required this.metodoPago,
    required this.onImprimir,
    required this.onCerrar,
  });

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final ancho = MediaQuery.sizeOf(context).width;
    final lineas = detallesPorPedido[pedido.id] ?? [];
    final total = totalDePedido(pedido.id);
    const gris = TextStyle(fontSize: 12, color: Color(0xFF6B7280));
    Widget fila(String a, String b, {TextStyle? estilo}) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(a, style: estilo ?? gris),
        Flexible(
          child: Text(
            b,
            textAlign: TextAlign.end,
            style: (estilo ?? gris).copyWith(color: Colors.black87),
          ),
        ),
      ],
    );
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: esMobile
            ? BoxConstraints(minWidth: ancho, maxWidth: ancho)
            : const BoxConstraints(minWidth: 380, maxWidth: 380),
        child: Padding(
          padding: EdgeInsets.fromLTRB(28, esMobile ? 32 : 24, 28, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/logo_bijao.png',
                    height: 44,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Boleta',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Center(
                  child: Text('Pedido #${pedido.numeroPedido}', style: gris),
                ),
                const SizedBox(height: 14),
                fila('Fecha', _fecha(pedido.fechaPedido)),
                const SizedBox(height: 4),
                fila('Cliente', pedido.clienteNombre ?? '—'),
                const SizedBox(height: 4),
                fila('Atendido por', mesero),
                const SizedBox(height: 4),
                fila('Tipo', titulo),
                const SizedBox(height: 14),
                Divider(height: 1, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                for (final l in lineas) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${l.cantidad}x',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.nombrePlato,
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (l.modificadores.isNotEmpty)
                              Text(
                                l.modificadores.map((m) => m.nombre).join(', '),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        'S/ ${l.precioTotalLinea.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Divider(height: 1, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                fila(
                  'Total',
                  'S/ ${total.toStringAsFixed(2)}',
                  estilo: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                fila('Pago', metodoPago),
                const SizedBox(height: 16),
                const Center(
                  child: Text('¡Gracias por su visita!', style: gris),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCerrar,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          foregroundColor: Colors.black87,
                        ),
                        child: const Text('Cerrar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onImprimir,
                        icon: const Icon(LucideIcons.printer, size: 16),
                        label: const Text('Imprimir'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.navbar,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

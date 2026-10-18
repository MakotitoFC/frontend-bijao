import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/logo_ticket_store.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';
import '../utils/datos_sede.dart';
import '../utils/ticket_texto.dart';
import 'app_tag.dart';
import 'dialogo_app.dart';
import 'ticket_papel.dart';

// Tickets del pedido, tal como salen en la ticketera (80 mm, blanco y negro):
//  - Comanda de cocina: lo que se prepara, sin precios. Es la que el servidor
//    manda a la impresora de cocina y la que se puede reimprimir desde aquí.
//  - Cuenta: lo consumido con sus precios y el total.
class BoletaPedidoDialog extends StatefulWidget {
  final Pedido pedido;
  final String mesero;
  final String titulo;
  final String metodoPago;
  // Reimprime la comanda en la impresora de cocina.
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

  @override
  State<BoletaPedidoDialog> createState() => _BoletaPedidoDialogState();
}

class _BoletaPedidoDialogState extends State<BoletaPedidoDialog> {
  // 'comanda' o 'cuenta'.
  String _tab = 'comanda';

  @override
  void initState() {
    super.initState();
    cargarLogoTicketLocal();
  }

  @override
  Widget build(BuildContext context) {
    final pedido = widget.pedido;
    final lineas = detallesPorPedido[pedido.id] ?? const [];
    final total = totalDePedido(pedido.id);
    final pagado = total - saldoPendienteDePedido(pedido.id);
    final ticket = _tab == 'comanda'
        ? ticketComanda(pedido: pedido, lineas: lineas, mozo: widget.mesero)
        : ticketBoleta(
            pedido: pedido,
            lineas: lineas,
            mozo: widget.mesero,
            sede: datosDeLaSede(),
            metodoPago: widget.metodoPago == 'Sin pago'
                ? ''
                : widget.metodoPago,
            pagado: pagado > 0.001 ? pagado : 0,
          );
    return DialogoApp(
      titulo: 'Ticket · Pedido #${pedido.numeroPedido}',
      ancho: 480,
      acciones: [
        OutlinedButton(onPressed: widget.onCerrar, child: const Text('Cerrar')),
        if (_tab == 'comanda')
          FilledButton.icon(
            onPressed: widget.onImprimir,
            icon: const Icon(LucideIcons.printer, size: 16),
            label: const Text('Reimprimir comanda'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.navbar),
          ),
      ],
      children: [
        Wrap(
          spacing: 0,
          runSpacing: 8,
          children: [
            AppTag(
              etiqueta: 'Comanda de cocina',
              activo: _tab == 'comanda',
              onTap: () => setState(() => _tab = 'comanda'),
            ),
            AppTag(
              etiqueta: 'Boleta',
              activo: _tab == 'cuenta',
              onTap: () => setState(() => _tab = 'cuenta'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _tab == 'comanda'
              ? 'Así sale en la impresora de cocina (sin precios). Al '
                    'reimprimirla, el papel lleva el rótulo REIMPRESION.'
              : 'Boleta de venta electrónica. Todavía no se imprime desde el sistema.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(12),
          ),
          // La boleta lleva logo; la comanda de cocina no.
          child: TicketConLogo(lineas: ticket, conLogo: _tab == 'cuenta'),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

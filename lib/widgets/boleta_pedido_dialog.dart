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
//  - Cuenta: lo consumido con sus precios y el total (impresora de caja / USB).
//  - Comanda de cocina: lo que se prepara, sin precios (impresora de cocina / LAN).
// Nota: Comprobantes de pago (Ticket de venta, Boleta y Factura) se emiten exclusivamente al cobrar.
class BoletaPedidoDialog extends StatefulWidget {
  final Pedido pedido;
  final String mesero;
  final String titulo;
  final String metodoPago;
  // Reimprime la comanda en la impresora de cocina.
  final VoidCallback onImprimir;
  // Imprime la cuenta en la impresora de caja (solo con el servidor).
  final VoidCallback? onImprimirCuenta;
  final VoidCallback onCerrar;

  const BoletaPedidoDialog({
    super.key,
    required this.pedido,
    required this.mesero,
    required this.titulo,
    required this.metodoPago,
    required this.onImprimir,
    this.onImprimirCuenta,
    required this.onCerrar,
  });

  @override
  State<BoletaPedidoDialog> createState() => _BoletaPedidoDialogState();
}

class _BoletaPedidoDialogState extends State<BoletaPedidoDialog> {
  // Solo se visualiza en este orden: 'cuenta' y luego 'comanda'.
  String _tab = 'cuenta';

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
    final efectivo = efectivoRecibidoPorPedido[pedido.id];
    final metodo = widget.metodoPago == 'Sin pago' ? '' : widget.metodoPago;
    final ticket = switch (_tab) {
      'comanda' => ticketComanda(
        pedido: pedido,
        lineas: lineas,
        mozo: widget.mesero,
      ),
      _ => ticketBoleta(
        pedido: pedido,
        lineas: lineas,
        mozo: widget.mesero,
        sede: datosDeLaSede(),
        pagos: pagosPorMedioDe(pedido.id),
        metodoPago: metodo,
        pagado: pagado > 0.001 ? pagado : 0,
        recargo: recargoCobradoDePedido(pedido.id),
        recibido: efectivo?.recibido ?? 0,
        vuelto: efectivo?.vuelto ?? 0,
      ),
    };
    return DialogoApp(
      titulo: 'Ticket · Pedido #${pedido.numeroPedido}',
      ancho: 480,
      acciones: [
        OutlinedButton(onPressed: widget.onCerrar, child: const Text('Cerrar')),
        if (_tab == 'cuenta' && widget.onImprimirCuenta != null)
          FilledButton.icon(
            onPressed: widget.onImprimirCuenta,
            icon: const Icon(LucideIcons.printer, size: 16),
            label: const Text('Imprimir cuenta'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.navbar),
          ),
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
          spacing: 8,
          runSpacing: 8,
          children: [
            AppTag(
              etiqueta: 'Cuenta',
              activo: _tab == 'cuenta',
              onTap: () => setState(() => _tab = 'cuenta'),
            ),
            AppTag(
              etiqueta: 'Comanda de cocina',
              activo: _tab == 'comanda',
              onTap: () => setState(() => _tab = 'comanda'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _tab == 'cuenta'
              ? 'Detalle de lo consumido, sin validez tributaria. Se imprime en la impresora de caja (USB).'
              : 'Así sale en la impresora de cocina (sin precios). Al reimprimirla lleva el rótulo de REIMPRESIÓN.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(12),
          ),
          // La cuenta lleva logo; la comanda de cocina no.
          child: TicketConLogo(lineas: ticket, conLogo: _tab != 'comanda'),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

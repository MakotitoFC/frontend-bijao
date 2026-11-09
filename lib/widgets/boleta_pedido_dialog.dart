import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/logo_ticket_store.dart';
import '../data/pagos_store.dart';
import '../services/pago_service.dart';
import '../data/pedidos_store.dart';
import '../models/pedido.dart';
import '../services/impresion_service.dart';
import '../services/preview_ticket_service.dart';
import '../utils/uuid_helper.dart';
import '../theme/app_theme.dart';
import '../utils/datos_sede.dart';
import '../utils/ticket_texto.dart';
import 'app_tag.dart';
import 'app_toast.dart';
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

  // La cuenta tal como la imprime el servidor (con su plantilla). Mientras llega,
  // o si el servidor no la ofrece, se ve la versión aproximada de la app.
  PreviewTicket? _cuentaServidor;
  bool _cargandoCuenta = false;

  Future<void> _cargarCuentaServidor() async {
    if (!UuidHelper.isValid(widget.pedido.id)) return;
    setState(() => _cargandoCuenta = true);
    final p = await PreviewTicketService.instance.cuenta(widget.pedido.id);
    if (!mounted) return;
    setState(() {
      _cuentaServidor = p;
      _cargandoCuenta = false;
    });
  }

  @override
  void initState() {
    super.initState();
    cargarLogoTicketLocal();
    _cargarCuentaServidor();
    // Todos los abonos del pedido (también los de otros días) para listarlos.
    PagoService.instance
        .cargarDePedido(widget.pedido)
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final pedido = widget.pedido;
    final lineas = detallesPorPedido[pedido.id] ?? const [];
    // Lo abonado de verdad (sus pagos), más la propina que viajó con ellos.
    final pagado =
        abonadoDePedido(pedido.id) + propinaCobradaDePedido(pedido.id);
    final efectivo = efectivoRecibidoPorPedido[pedido.id];
    final metodo = widget.metodoPago == 'Sin pago' ? '' : widget.metodoPago;
    final ticket = switch (_tab) {
      'cuenta' when _cuentaServidor != null => _cuentaServidor!.lineas,
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
        abonos: abonosDePedido(pedido.id),
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
        if (_tab == 'cuenta')
          FilledButton.icon(
            onPressed: () {
              if (widget.onImprimirCuenta != null) {
                widget.onImprimirCuenta!();
              } else {
                ImpresionService.instance
                    .reimprimirPedido(pedido.id, tipo: 'cuenta')
                    .then((_) {
                      if (context.mounted) {
                        showAppToast(
                          context,
                          'Cuenta del pedido #${pedido.numeroPedido} enviada a la impresora de caja.',
                          type: ToastType.success,
                        );
                      }
                    })
                    .catchError((e) {
                      if (context.mounted) {
                        showAppToast(
                          context,
                          'No se pudo imprimir la cuenta: $e',
                          type: ToastType.error,
                        );
                      }
                    });
                Navigator.of(context).pop();
              }
            },
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
        // Qué versión se ve: la que imprime el servidor o la aproximada.
        if (_tab == 'cuenta' && _cargandoCuenta) ...[
          const SizedBox(height: 8),
          Text(
            'Cargando la cuenta tal como se imprime…',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ] else if (_tab == 'cuenta' && _cuentaServidor == null) ...[
          const SizedBox(height: 8),
          Text(
            'Vista aproximada: no se pudo leer cómo la imprime el servidor.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(12),
          ),
          // La cuenta lleva logo; la comanda de cocina no.
          child: TicketConLogo(
            lineas: ticket,
            // La cuenta del servidor dice si lleva logo (según su plantilla).
            conLogo:
                _tab != 'comanda' &&
                (_tab != 'cuenta' ||
                    _cuentaServidor == null ||
                    _cuentaServidor!.conLogo),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

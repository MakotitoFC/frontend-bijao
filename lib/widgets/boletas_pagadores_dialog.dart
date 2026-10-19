import 'package:flutter/material.dart';

import '../models/pedido.dart';
import '../utils/datos_sede.dart';
import '../utils/ticket_texto.dart';
import 'dialogo_app.dart';
import 'pago_compartido_dialog.dart';
import 'ticket_papel.dart';

// Una cuenta por pagador, para cuando cada uno pide la suya tras un pago
// compartido. Se ven como el ticket de la ticketera (blanco y negro).
class BoletasPagadoresDialog extends StatelessWidget {
  final Pedido pedido;
  final List<BoletaPagador> boletas;

  const BoletasPagadoresDialog({
    super.key,
    required this.pedido,
    required this.boletas,
  });

  @override
  Widget build(BuildContext context) {
    return DialogoApp(
      titulo: 'Cuentas por pagador',
      ancho: 480,
      acciones: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
      children: [
        Text(
          'Una cuenta para cada pagador.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        for (final b in boletas) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TicketConLogo(
              lineas: ticketPagador(
                pedido: pedido,
                pagador: b.nombre,
                items: b.items,
                total: b.total,
                // Cada pago incluye su recargo (p. ej. tarjeta): es lo que
                // pagó de verdad con ese método.
                pagos: [
                  for (final p in b.pagos)
                    (
                      medio: p.medio.medioPago,
                      monto: p.monto + p.medio.recargoSobre(p.monto),
                    ),
                ],
                recargo: b.pagos.fold(
                  0.0,
                  (s, p) => s + p.medio.recargoSobre(p.monto),
                ),
                sede: datosDeLaSede(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

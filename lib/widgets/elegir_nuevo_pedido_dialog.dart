import 'package:flutter/material.dart';

import 'elegir_destinatario_dialog.dart';
import 'elegir_tipo_pedido_dialog.dart';

// Para quién es el pedido y de qué tipo.
typedef EleccionNuevoPedido = ({String destinatario, String tipo});

// "Nuevo pedido" en un solo modal con dos pasos: para quién es (cliente,
// familia o empleado) y el tipo (mesa, para llevar o delivery). Pasar de uno a
// otro desliza el contenido y ajusta la altura sin saltos. Sin
// [conDestinatario] (el mozo) empieza directo en el tipo.
class ElegirNuevoPedidoDialog extends StatefulWidget {
  final bool conDestinatario;

  const ElegirNuevoPedidoDialog({super.key, required this.conDestinatario});

  @override
  State<ElegirNuevoPedidoDialog> createState() =>
      _ElegirNuevoPedidoDialogState();
}

class _ElegirNuevoPedidoDialogState extends State<ElegirNuevoPedidoDialog> {
  late int _paso = widget.conDestinatario ? 0 : 1;
  String _destinatario = 'cliente';
  bool _haciaAdelante = true;

  @override
  Widget build(BuildContext context) {
    final contenido = _paso == 0
        ? ElegirDestinatarioDialog(
            onElegir: (d) => setState(() {
              _destinatario = d;
              _haciaAdelante = true;
              _paso = 1;
            }),
          )
        : ElegirTipoPedidoDialog(
            conAtras: widget.conDestinatario,
            onAtras: () => setState(() {
              _haciaAdelante = false;
              _paso = 0;
            }),
            onElegir: (t) => Navigator.of(
              context,
            ).pop<EleccionNuevoPedido>((destinatario: _destinatario, tipo: t)),
          );
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (actual, anteriores) => Stack(
          alignment: Alignment.topCenter,
          children: [...anteriores, ?actual],
        ),
        transitionBuilder: (child, animacion) {
          final entra = child.key == ValueKey(_paso);
          final inicio = entra
              ? Offset(_haciaAdelante ? 0.12 : -0.12, 0)
              : Offset(_haciaAdelante ? -0.12 : 0.12, 0);
          return FadeTransition(
            opacity: animacion,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: inicio,
                end: Offset.zero,
              ).animate(animacion),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(key: ValueKey(_paso), child: contenido),
      ),
    );
  }
}

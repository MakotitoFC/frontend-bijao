import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../theme/app_theme.dart';

// Modal de "Nuevo Pedido": elige tipo (Mesa, Para llevar o Delivery) y retorna
// 'mesa'/'llevar'/'delivery'.
class ElegirTipoPedidoDialog extends StatefulWidget {
  const ElegirTipoPedidoDialog({super.key});

  @override
  State<ElegirTipoPedidoDialog> createState() => _ElegirTipoPedidoDialogState();
}

class _ElegirTipoPedidoDialogState extends State<ElegirTipoPedidoDialog> {
  bool _esMobile = false;

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    _esMobile = esMobile;
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: esMobile ? anchoPantalla : 600,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Nuevo pedido',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '¿Dónde va este pedido?',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              IntrinsicHeight(
                child: Flex(
                  direction: esMobile ? Axis.vertical : Axis.horizontal,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _tarjetaTipo(
                      icono: LucideIcons.utensils,
                      titulo: 'Mesa',
                      descripcion:
                          'Pedido para consumir en una mesa del local.',
                      onTap: () => Navigator.of(context).pop('mesa'),
                    ),
                    SizedBox(
                      width: esMobile ? 0 : 14,
                      height: esMobile ? 16 : 0,
                    ),
                    _tarjetaTipo(
                      icono: LucideIcons.packageCheck,
                      titulo: 'Para llevar',
                      descripcion: 'El cliente recoge su pedido en el local.',
                      onTap: () => Navigator.of(context).pop('llevar'),
                    ),
                    SizedBox(
                      width: esMobile ? 0 : 14,
                      height: esMobile ? 16 : 0,
                    ),
                    _tarjetaTipo(
                      icono: LucideIcons.bike,
                      titulo: 'Delivery',
                      descripcion: 'Pedido para entregar a domicilio.',
                      onTap: () => Navigator.of(context).pop('delivery'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjetaTipo({
    required IconData icono,
    required String titulo,
    required String descripcion,
    required VoidCallback onTap,
  }) {
    final tarjeta = _TarjetaHover(
      onTap: onTap,
      builder: (hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hover
              ? AppColors.primaryGreen.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hover ? AppColors.primaryGreen : Colors.grey.shade300,
            width: hover ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 26,
              color: hover ? AppColors.primaryGreenDark : Colors.grey.shade700,
            ),
            const SizedBox(height: 12),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: hover ? AppColors.primaryGreenDark : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              descripcion,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
    // En escritorio las tres tarjetas se reparten el ancho por igual: el
    // espacio a los costados es el mismo en todas.
    return _esMobile ? tarjeta : Expanded(child: tarjeta);
  }
}

// Tarjeta que se sombrea de verde al pasar el cursor por encima.
class _TarjetaHover extends StatefulWidget {
  final VoidCallback onTap;
  final Widget Function(bool hover) builder;

  const _TarjetaHover({required this.onTap, required this.builder});

  @override
  State<_TarjetaHover> createState() => _TarjetaHoverState();
}

class _TarjetaHoverState extends State<_TarjetaHover> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.builder(_hover),
      ),
    );
  }
}

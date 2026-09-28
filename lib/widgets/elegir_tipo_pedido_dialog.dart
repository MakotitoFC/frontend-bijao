import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

// Modal de "Nuevo Pedido": elige tipo (Mesa, Delivery o Rápido) y retorna
// 'mesa'/'delivery'/'llevar'.
class ElegirTipoPedidoDialog extends StatefulWidget {
  const ElegirTipoPedidoDialog({super.key});

  @override
  State<ElegirTipoPedidoDialog> createState() =>
      _ElegirTipoPedidoDialogState();
}

class _ElegirTipoPedidoDialogState extends State<ElegirTipoPedidoDialog> {
  String? _tipoSeleccion;

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: esMobile ? anchoPantalla : 640,
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
                      child: Icon(Icons.close, size: 16, color: Colors.grey.shade700),
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
                    descripcion: 'Pedido para consumir en una mesa del local.',
                    seleccionado: _tipoSeleccion == 'mesa',
                    onTap: () => setState(() => _tipoSeleccion = 'mesa'),
                  ),
                  SizedBox(width: esMobile ? 0 : 14, height: esMobile ? 16 : 0),
                  _tarjetaTipo(
                    icono: LucideIcons.bike,
                    titulo: 'Delivery',
                    descripcion: 'Pedido para entregar a domicilio.',
                    seleccionado: _tipoSeleccion == 'delivery',
                    onTap: () => setState(() => _tipoSeleccion = 'delivery'),
                  ),
                  SizedBox(width: esMobile ? 0 : 14, height: esMobile ? 16 : 0),
                  _tarjetaTipo(
                    icono: LucideIcons.zap,
                    titulo: 'Rápido',
                    descripcion: 'Venta directa para llevar, sin mesa.',
                    seleccionado: _tipoSeleccion == 'llevar',
                    onTap: () => setState(() => _tipoSeleccion = 'llevar'),
                  ),
                ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: FilledButton(
                  onPressed: _tipoSeleccion == null
                      ? null
                      : () => Navigator.of(context).pop(_tipoSeleccion),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Continuar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
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
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 180,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppColors.primaryGreen.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: seleccionado ? AppColors.primaryGreen : Colors.grey.shade300,
            width: seleccionado ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 26,
              color: seleccionado ? AppColors.primaryGreenDark : Colors.grey.shade700,
            ),
            const SizedBox(height: 12),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: seleccionado ? AppColors.primaryGreenDark : Colors.black87,
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
  }
}

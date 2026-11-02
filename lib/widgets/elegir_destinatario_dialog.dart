import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../theme/app_theme.dart';
import 'dialogo_app.dart';

// Primer paso de "Nuevo pedido": para quién es. Devuelve 'cliente', 'familia'
// (cuenta cero: hijos y familia de los dueños) o 'empleado' (consumo del
// personal); null si se cierra.
class ElegirDestinatarioDialog extends StatelessWidget {
  // Dentro del flujo de un solo modal: avisa la elección en vez de cerrar.
  final ValueChanged<String>? onElegir;

  const ElegirDestinatarioDialog({super.key, this.onElegir});

  void _elegir(BuildContext context, String valor) =>
      onElegir != null ? onElegir!(valor) : Navigator.of(context).pop(valor);

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
      child: SizedBox(
        width: esMobile ? ancho : 640,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  BotonCerrarCircular(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '¿Para quién es este pedido?',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 18),
              _TarjetaDestinatario(
                icono: LucideIcons.userRound,
                color: AppColors.primaryGreen,
                titulo: 'Cliente',
                descripcion: 'Un cliente del local: se cobra la cuenta normal.',
                onTap: () => _elegir(context, 'cliente'),
              ),
              const SizedBox(height: 12),
              _TarjetaDestinatario(
                icono: LucideIcons.house,
                color: AppColors.primaryGreen,
                titulo: 'Familia',
                descripcion:
                    'Hijos y familia de los dueños: cuenta cero (descuento del '
                    '100 %), sin cobro.',
                onTap: () => _elegir(context, 'familia'),
              ),
              const SizedBox(height: 12),
              _TarjetaDestinatario(
                icono: LucideIcons.users,
                color: AppColors.primaryGreen,
                titulo: 'Empleado',
                descripcion:
                    'Consumo del personal: cada plato con su precio de '
                    'empleado, pagado por abonos.',
                onTap: () => _elegir(context, 'empleado'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaDestinatario extends StatefulWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;

  const _TarjetaDestinatario({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.descripcion,
    required this.onTap,
  });

  @override
  State<_TarjetaDestinatario> createState() => _TarjetaDestinatarioState();
}

class _TarjetaDestinatarioState extends State<_TarjetaDestinatario> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: widget.onTap,
      onHover: (v) => setState(() => _encima = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _encima ? widget.color : Colors.grey.shade200,
            width: _encima ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _encima ? 0.10 : 0.05),
              blurRadius: _encima ? 16 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(widget.icono, size: 26, color: widget.color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.descripcion,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

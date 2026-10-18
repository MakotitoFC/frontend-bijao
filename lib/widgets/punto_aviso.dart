import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Círculo de aviso (mostaza, como el estado Pendiente) con ondas que se expanden y un latido suave, para llamar
// la atención sin tapar nada (por ejemplo, junto a un ícono del menú).
class PuntoAviso extends StatefulWidget {
  final double tamano;

  const PuntoAviso({super.key, this.tamano = 9});

  @override
  State<PuntoAviso> createState() => _PuntoAvisoState();
}

class _PuntoAvisoState extends State<PuntoAviso>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tamano;
    return IgnorePointer(
      child: SizedBox(
        width: t * 3,
        height: t * 3,
        child: AnimatedBuilder(
          animation: _controlador,
          builder: (context, _) {
            final v = _controlador.value;
            // Dos ondas desfasadas.
            Widget onda(double fase) {
              final p = (v + fase) % 1.0;
              return Transform.scale(
                scale: 1 + p * 1.9,
                child: Opacity(
                  opacity: (1 - p) * 0.55,
                  child: Container(
                    width: t,
                    height: t,
                    decoration: const BoxDecoration(
                      color: AppColors.pendiente,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }

            // Latido: el punto crece un poco al inicio de cada ciclo.
            final latido = 1 + 0.18 * (1 - (v * 2 - 1).abs());
            return Stack(
              alignment: Alignment.center,
              children: [
                onda(0),
                onda(0.5),
                Transform.scale(
                  scale: latido,
                  child: Container(
                    width: t,
                    height: t,
                    decoration: BoxDecoration(
                      color: AppColors.pendiente,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/pedido.dart';
import '../theme/app_theme.dart';

// Cronómetro del pedido: corre desde `fecha_pedido` hasta `fecha_finalizacion`.
class CronometroPedido extends StatefulWidget {
  final Pedido pedido;
  // Sobre las tarjetas verdes el cronómetro va en blanco.
  final bool sobreVerde;

  const CronometroPedido({
    super.key,
    required this.pedido,
    this.sobreVerde = false,
  });

  @override
  State<CronometroPedido> createState() => CronometroPedidoState();
}

class CronometroPedidoState extends State<CronometroPedido> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.pedido.fechaFinalizacion == null) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formato(Duration d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${dos(h)}:${dos(m)}:${dos(s)}' : '${dos(m)}:${dos(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    final fin = p.fechaFinalizacion ?? DateTime.now();
    final terminado = p.fechaFinalizacion != null;
    final duracion = fin.difference(p.fechaPedido);
    final color = widget.sobreVerde
        ? (terminado ? Colors.white70 : Colors.white)
        : (terminado ? Colors.grey.shade600 : AppColors.primaryGreen);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.timer, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          _formato(duracion.isNegative ? Duration.zero : duracion),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: color,
          ),
        ),
      ],
    );
  }
}

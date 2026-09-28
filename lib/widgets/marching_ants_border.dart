import 'package:flutter/material.dart';

// Borde punteado animado ("marching ants"), usado para resaltar una mesa
// elegida para unir.
class MarchingAntsBorder extends StatefulWidget {
  final Widget child;
  final double radius;
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double gapWidth;

  const MarchingAntsBorder({
    super.key,
    required this.child,
    this.radius = 16,
    this.color = const Color(0xFF9CA3AF),
    this.strokeWidth = 2,
    this.dashWidth = 6,
    this.gapWidth = 5,
  });

  @override
  State<MarchingAntsBorder> createState() => _MarchingAntsBorderState();
}

class _MarchingAntsBorderState extends State<MarchingAntsBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patron = widget.dashWidth + widget.gapWidth;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => CustomPaint(
        foregroundPainter: _MarchingAntsPainter(
          radius: widget.radius,
          color: widget.color,
          strokeWidth: widget.strokeWidth,
          dashWidth: widget.dashWidth,
          gapWidth: widget.gapWidth,
          phase: _controller.value * patron,
        ),
        child: child,
      ),
    );
  }
}

class _MarchingAntsPainter extends CustomPainter {
  final double radius;
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double gapWidth;
  final double phase;

  _MarchingAntsPainter({
    required this.radius,
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.gapWidth,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final patron = dashWidth + gapWidth;
    for (final metric in path.computeMetrics()) {
      var distancia = -phase;
      while (distancia < metric.length) {
        final inicio = distancia.clamp(0, metric.length);
        final fin = (distancia + dashWidth).clamp(0, metric.length);
        if (fin > inicio) {
          canvas.drawPath(
            metric.extractPath(inicio.toDouble(), fin.toDouble()),
            paint,
          );
        }
        distancia += patron;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MarchingAntsPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.color != color ||
      oldDelegate.radius != radius;
}

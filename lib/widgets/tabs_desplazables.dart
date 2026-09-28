import 'package:flutter/material.dart';

// Fila que se desplaza en horizontal, con flechas "<"/">" si no caben todos.
class TabsDesplazables extends StatefulWidget {
  final Widget child;

  const TabsDesplazables({super.key, required this.child});

  @override
  State<TabsDesplazables> createState() => TabsDesplazablesState();
}

class TabsDesplazablesState extends State<TabsDesplazables> {
  final _controller = ScrollController();
  bool _izquierda = false;
  bool _derecha = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_actualizar);
    WidgetsBinding.instance.addPostFrameCallback((_) => _actualizar());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _actualizar() {
    if (!mounted || !_controller.hasClients) return;
    final p = _controller.position;
    final izq = p.pixels > 1;
    final der = p.pixels < p.maxScrollExtent - 1;
    if (izq != _izquierda || der != _derecha) {
      setState(() {
        _izquierda = izq;
        _derecha = der;
      });
    }
  }

  void _mover(double delta) {
    final p = _controller.position;
    _controller.animateTo(
      (p.pixels + delta).clamp(0.0, p.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Widget _flecha(IconData icono, double delta, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _mover(delta),
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Icon(icono, size: 20, color: Colors.grey.shade800),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _actualizar());
        return false;
      },
      child: Row(
        children: [
          if (_izquierda) _flecha(Icons.chevron_left, -240, 'Ver anteriores'),
          Expanded(
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              child: widget.child,
            ),
          ),
          if (_derecha) _flecha(Icons.chevron_right, 240, 'Ver más'),
        ],
      ),
    );
  }
}

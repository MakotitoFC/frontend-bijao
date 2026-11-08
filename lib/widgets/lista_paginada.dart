import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../theme/app_theme.dart';

// Lista que se muestra por páginas: [porPagina] filas y, debajo, "Mostrando
// 1-5 de 23" con las flechas para pasar de página. Si todo cabe en una página,
// no dibuja los controles. [reiniciarCon] vuelve a la primera página cuando
// cambia (ej. al cambiar un filtro).
class ListaPaginada<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(T item) itemBuilder;
  final int porPagina;
  final Object? reiniciarCon;
  // Línea fina entre una fila y otra.
  final bool divisores;

  const ListaPaginada({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.porPagina = 8,
    this.reiniciarCon,
    this.divisores = false,
  });

  @override
  State<ListaPaginada<T>> createState() => _ListaPaginadaState<T>();
}

class _ListaPaginadaState<T> extends State<ListaPaginada<T>> {
  int _pagina = 0;

  int get _paginas => widget.items.isEmpty
      ? 1
      : (widget.items.length / widget.porPagina).ceil();

  @override
  void didUpdateWidget(ListaPaginada<T> old) {
    super.didUpdateWidget(old);
    if (old.reiniciarCon != widget.reiniciarCon) _pagina = 0;
    if (_pagina >= _paginas) _pagina = _paginas - 1;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    final pagina = _pagina.clamp(0, _paginas - 1);
    final desde = pagina * widget.porPagina;
    final hasta = (desde + widget.porPagina).clamp(0, total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = desde; i < hasta; i++) ...[
          if (widget.divisores && i > desde)
            Divider(height: 1, color: Colors.grey.shade200),
          widget.itemBuilder(widget.items[i]),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: PaginadorApp(
            total: total,
            porPagina: widget.porPagina,
            pagina: pagina,
            onPagina: (p) => setState(() => _pagina = p),
          ),
        ),
      ],
    );
  }
}

// Paginador de la app: "Mostrando 1-5 de 23" a la izquierda y, a la derecha, las
// flechas con la página ("2 / 5"). Es el mismo en ingresos y salidas, en las
// tablas y en toda lista con páginas. [flota]: lleva fondo blanco y borde, para
// ir sobre el contenido. No se dibuja si todo cabe en una página.
class PaginadorApp extends StatelessWidget {
  final int total;
  final int porPagina;
  final int pagina;
  final ValueChanged<int> onPagina;
  final bool flota;

  const PaginadorApp({
    super.key,
    required this.total,
    required this.porPagina,
    required this.pagina,
    required this.onPagina,
    this.flota = false,
  });

  Widget _flecha(IconData icono, String tooltip, VoidCallback? onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: AppSizes.boton,
          height: AppSizes.boton,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Icon(
            icono,
            size: 18,
            color: onTap == null ? Colors.grey.shade400 : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (porPagina <= 0) return const SizedBox.shrink();
    final paginas = total == 0 ? 1 : (total / porPagina).ceil();
    final actual = pagina.clamp(0, paginas - 1);
    final desde = actual * porPagina;
    final hasta = (desde + porPagina).clamp(0, total);
    final fila = Row(
      children: [
        Expanded(
          child: Text(
            total == 0
                ? 'Mostrando 0 de 0'
                : 'Mostrando ${desde + 1}-$hasta de $total',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
        ),
        _flecha(
          LucideIcons.chevronLeft,
          'Página anterior',
          actual == 0 ? null : () => onPagina(actual - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '${actual + 1} / $paginas',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
        _flecha(
          LucideIcons.chevronRight,
          'Página siguiente',
          actual >= paginas - 1 ? null : () => onPagina(actual + 1),
        ),
      ],
    );
    if (!flota) return fila;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.boton / 2 + 4),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: fila,
    );
  }
}

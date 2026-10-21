import 'package:flutter/material.dart';

// Una columna de [TablaApp]. Si tiene [ordenarPor], el encabezado se puede tocar
// para ordenar las filas por ese valor (ascendente y, al tocar otra vez,
// descendente).
class ColumnaTabla<T> {
  final String titulo;
  final Widget Function(T fila) celda;
  // Ancho fijo; sin él la columna reparte el espacio sobrante según [flex].
  final double? ancho;
  final double flex;
  // Ancho mínimo de una columna con [flex] (la tabla se desplaza hacia el lado
  // si no cabe).
  final double anchoMin;
  final Comparable<Object?> Function(T fila)? ordenarPor;
  final Alignment alineacion;

  const ColumnaTabla({
    required this.titulo,
    required this.celda,
    this.ancho,
    this.flex = 1,
    this.anchoMin = 110,
    this.ordenarPor,
    this.alineacion = Alignment.centerLeft,
  });

  double get minimo => ancho ?? anchoMin;
}

// Tabla de toda la app: marco de borde suave y esquinas redondeadas, encabezado
// de fondo claro con indicador de orden, filas altas separadas por una línea
// fina y texto alineado a la izquierda.
class TablaApp<T> extends StatefulWidget {
  final List<ColumnaTabla<T>> columnas;
  final List<T> filas;
  final double altoFila;
  final ValueChanged<T>? onFila;

  const TablaApp({
    super.key,
    required this.columnas,
    required this.filas,
    this.altoFila = 52,
    this.onFila,
  });

  static const colorBorde = Color(0xFFE5E7EB);
  static const colorEncabezado = Color(0xFFF9FAFB);
  static const estiloTexto = TextStyle(
    fontSize: 13.5,
    color: Color(0xFF111827),
    fontWeight: FontWeight.w500,
  );

  // Texto de una celda común.
  static Widget texto(String t, {bool fuerte = false, Color? color}) => Text(
    t,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: estiloTexto.copyWith(
      fontWeight: fuerte ? FontWeight.w700 : FontWeight.w500,
      color: color,
    ),
  );

  @override
  State<TablaApp<T>> createState() => _TablaAppState<T>();
}

class _TablaAppState<T> extends State<TablaApp<T>> {
  int? _orden;
  bool _asc = true;

  List<T> get _filas {
    final i = _orden;
    if (i == null) return widget.filas;
    final f = widget.columnas[i].ordenarPor;
    if (f == null) return widget.filas;
    final copia = List<T>.of(widget.filas)
      ..sort((a, b) => Comparable.compare(f(a), f(b)));
    return _asc ? copia : copia.reversed.toList();
  }

  void _ordenar(int i) => setState(() {
    if (_orden == i) {
      _asc = !_asc;
    } else {
      _orden = i;
      _asc = true;
    }
  });

  Widget _casilla(ColumnaTabla<T> c, Widget hijo, {bool ultima = false}) {
    final padding = EdgeInsets.fromLTRB(16, 0, ultima ? 16 : 8, 0);
    final contenido = Align(
      alignment: c.alineacion,
      child: Padding(padding: padding, child: hijo),
    );
    return c.ancho != null
        ? SizedBox(width: c.ancho, child: contenido)
        : Expanded(flex: (c.flex * 10).round(), child: contenido);
  }

  Widget _encabezado() {
    return Container(
      height: 46,
      decoration: const BoxDecoration(
        color: TablaApp.colorEncabezado,
        border: Border(bottom: BorderSide(color: TablaApp.colorBorde)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < widget.columnas.length; i++)
            _casilla(
              widget.columnas[i],
              _tituloColumna(i),
              ultima: i == widget.columnas.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _tituloColumna(int i) {
    final c = widget.columnas[i];
    final activa = _orden == i;
    final texto = Text(
      c.titulo,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF4B5563),
      ),
    );
    if (c.ordenarPor == null) return texto;
    return InkWell(
      onTap: () => _ordenar(i),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: texto),
          const SizedBox(width: 4),
          Icon(
            activa
                ? (_asc ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 14,
            color: activa ? const Color(0xFF111827) : Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  Widget _fila(T fila, bool ultima) {
    final contenido = Container(
      height: widget.altoFila,
      decoration: BoxDecoration(
        border: ultima
            ? null
            : const Border(bottom: BorderSide(color: TablaApp.colorBorde)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < widget.columnas.length; i++)
            _casilla(
              widget.columnas[i],
              widget.columnas[i].celda(fila),
              ultima: i == widget.columnas.length - 1,
            ),
        ],
      ),
    );
    final onFila = widget.onFila;
    return onFila == null
        ? contenido
        : InkWell(onTap: () => onFila(fila), child: contenido);
  }

  @override
  Widget build(BuildContext context) {
    final minimo = widget.columnas.fold<double>(0, (s, c) => s + c.minimo);
    final filas = _filas;
    final cuerpo = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _encabezado(),
        for (var i = 0; i < filas.length; i++)
          _fila(filas[i], i == filas.length - 1),
      ],
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TablaApp.colorBorde),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= minimo) return cuerpo;
          // No cabe: se desplaza hacia el lado conservando el ancho mínimo.
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: minimo, child: cuerpo),
          );
        },
      ),
    );
  }
}

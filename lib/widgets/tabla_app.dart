import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Papel de una columna cuando la tabla se muestra como tarjetas.
enum RolTarjeta {
  // Va como "ETIQUETA ..... valor" al pie de la tarjeta.
  dato,
  // Título de la tarjeta, bajo la cabecera.
  titulo,
  // Va a la derecha del título (estado, etiqueta de color).
  estado,
  // Va a la derecha de la cabecera (botones de la fila).
  acciones,
  // No aparece en la tarjeta (sí en la tabla y en el detalle).
  oculta,
}

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
  // Cómo se ubica en la vista de tarjetas (menos de tablet).
  final RolTarjeta rol;

  const ColumnaTabla({
    required this.titulo,
    required this.celda,
    this.ancho,
    this.flex = 1,
    this.anchoMin = 110,
    this.ordenarPor,
    this.alineacion = Alignment.centerLeft,
    this.rol = RolTarjeta.dato,
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
  // Filas por página; null = todas en una sola página.
  final int? porPagina;
  // Se avisa al tocar una tarjeta (solo en la vista de tarjetas).
  final ValueChanged<T>? onTarjeta;

  const TablaApp({
    super.key,
    required this.columnas,
    required this.filas,
    this.altoFila = 52,
    this.onFila,
    this.porPagina,
    this.onTarjeta,
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
  int _pagina = 0;

  int get _paginas {
    final n = widget.porPagina;
    if (n == null || widget.filas.isEmpty) return 1;
    return (widget.filas.length / n).ceil();
  }

  // Las filas de la página actual, ya ordenadas.
  List<T> get _filasPagina {
    final todas = _filas;
    final n = widget.porPagina;
    if (n == null) return todas;
    final pagina = _pagina.clamp(0, _paginas - 1);
    final ini = pagina * n;
    return todas.sublist(ini, (ini + n).clamp(0, todas.length));
  }

  // Selector de páginas: píldora flotante como en las demás listas.
  Widget _paginador() {
    final paginas = _paginas;
    if (paginas <= 1) return const SizedBox.shrink();
    final actual = _pagina.clamp(0, paginas - 1);
    Widget flecha(IconData i, bool activa, VoidCallback f) => IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: activa ? f : null,
      icon: Icon(i, size: 18),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: TablaApp.colorBorde),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              flecha(
                Icons.chevron_left,
                actual > 0,
                () => setState(() => _pagina = actual - 1),
              ),
              for (var i = 0; i < paginas; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _pagina = i),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == actual ? AppColors.primaryGreen : null,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: i == actual
                              ? Colors.white
                              : const Color(0xFF111827),
                        ),
                      ),
                    ),
                  ),
                ),
              flecha(
                Icons.chevron_right,
                actual < paginas - 1,
                () => setState(() => _pagina = actual + 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

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

  // Una fila como tarjeta: la primera columna arriba a la izquierda (con las
  // acciones a la derecha), la columna `titulo` (con el estado a la derecha)
  // y las demás como "ETIQUETA ..... valor". Solo muestra lo que ya tiene la
  // tabla: no agrega datos ni acciones.
  Widget _tarjeta(T fila) {
    final cols = widget.columnas;
    final acciones = cols
        .where((c) => c.rol == RolTarjeta.acciones)
        .firstOrNull;
    final estado = cols.where((c) => c.rol == RolTarjeta.estado).firstOrNull;
    final titulo = cols.where((c) => c.rol == RolTarjeta.titulo).firstOrNull;
    final datos = [
      for (final c in cols)
        if (c.rol == RolTarjeta.dato) c,
    ];
    if (datos.isEmpty) return const SizedBox.shrink();
    final cabecera = datos.first;
    final resto = datos.skip(1).toList();
    const linea = Divider(height: 1, color: TablaApp.colorBorde);
    final accionesFila = acciones?.celda(fila);
    final onFila = widget.onTarjeta ?? widget.onFila;
    final tarjeta = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TablaApp.colorBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(color: Color(0xFF6B7280)),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: cabecera.celda(fila),
                    ),
                  ),
                ),
                if (accionesFila != null) ...[
                  const SizedBox(width: 8),
                  accionesFila,
                ],
              ],
            ),
          ),
          linea,
          if (titulo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: titulo.celda(fila),
                    ),
                  ),
                  if (estado != null) ...[
                    const SizedBox(width: 8),
                    estado.celda(fila),
                  ],
                ],
              ),
            ),
          if (resto.isNotEmpty) ...[
            if (titulo != null) linea,
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                children: [
                  for (final c in resto)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            c.titulo.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: c.celda(fila),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
    return onFila == null
        ? tarjeta
        : InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onFila(fila),
            child: tarjeta,
          );
  }

  @override
  Widget build(BuildContext context) {
    final minimo = widget.columnas.fold<double>(0, (s, c) => s + c.minimo);
    final filas = _filasPagina;
    if (AppBreakpoints.esMenorATablet(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < filas.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _tarjeta(filas[i]),
          ],
          _paginador(),
        ],
      );
    }
    final cuerpo = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _encabezado(),
        for (var i = 0; i < filas.length; i++)
          _fila(filas[i], i == filas.length - 1),
      ],
    );
    final marco = Container(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [marco, _paginador()],
    );
  }
}

import 'package:flutter/material.dart';

import '../../data/catalogos_store.dart';
import '../../theme/app_theme.dart';
import '../../utils/blur_dialog.dart';
import '../dialogo_app.dart';
import '../indice_subvistas.dart';
import '../lista_paginada.dart';

// Piezas comunes de las páginas de Inventario. Siguen el diseño de
// Configuración: título arriba, una sola acción principal y una tarjeta blanca
// con las filas separadas por líneas finas.

String unidadDe(String id) =>
    unidadesProducto
        .where((u) => u.id == id)
        .map((u) => u.unidad)
        .firstOrNull ??
    '—';

String tipoProductoDe(String id) =>
    tiposProducto
        .where((t) => t.id == id)
        .map((t) => t.tipoProducto)
        .firstOrNull ??
    '—';

String fechaCorta(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// Cantidad sin decimales sobrantes (12 en vez de 12.0).
String cantidadTexto(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

// Página con scroll, ancho máximo y contenido centrado, igual que las de
// Configuración.
class PaginaInventario extends StatelessWidget {
  final List<Widget> secciones;

  const PaginaInventario({super.key, required this.secciones});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppBreakpoints.esMobile(context) ? 16 : 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < secciones.length; i++) ...[
                if (i > 0) const SizedBox(height: 32),
                secciones[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Página de una sola lista: la cabecera y la barra de herramientas quedan
// fijas arriba, el paginador fijo abajo y solo se desplazan las filas.
class PaginaListaFija extends StatefulWidget {
  final Widget? cabecera;
  final Widget? barra;
  final List<Widget> filas;
  final String mensajeVacio;
  final int porPagina;
  // Vuelve a la primera página cuando cambia (por ejemplo, al filtrar).
  final Object? reiniciarCon;
  // Filas sueltas (tarjetas) en vez de líneas finas entre una y otra.
  final bool tarjetas;

  const PaginaListaFija({
    super.key,
    this.cabecera,
    this.barra,
    required this.filas,
    this.mensajeVacio = 'No hay registros.',
    this.porPagina = 8,
    this.reiniciarCon,
    this.tarjetas = false,
  });

  @override
  State<PaginaListaFija> createState() => _PaginaListaFijaState();
}

class _PaginaListaFijaState extends State<PaginaListaFija> {
  int _pagina = 0;

  @override
  void didUpdateWidget(PaginaListaFija old) {
    super.didUpdateWidget(old);
    if (old.reiniciarCon != widget.reiniciarCon) _pagina = 0;
  }

  @override
  Widget build(BuildContext context) {
    final margen = AppBreakpoints.esMobile(context) ? 16.0 : 24.0;
    final total = widget.filas.length;
    final paginas = total == 0 ? 1 : (total / widget.porPagina).ceil();
    final pagina = _pagina.clamp(0, paginas - 1);
    final desde = pagina * widget.porPagina;
    final hasta = (desde + widget.porPagina).clamp(0, total);
    final filas = widget.filas.sublist(desde, hasta);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: EdgeInsets.fromLTRB(margen, margen, margen, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?widget.cabecera,
              if (widget.barra != null) ...[
                const SizedBox(height: 14),
                widget.barra!,
              ],
              const SizedBox(height: 14),
              Expanded(
                child: filas.isEmpty
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          child: Text(
                            widget.mensajeVacio,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    : ListView.separated(
                        // Cada página empieza arriba.
                        key: ValueKey('pagina-$pagina'),
                        itemCount: filas.length,
                        separatorBuilder: (_, _) => widget.tarjetas
                            ? const SizedBox(height: 10)
                            : Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (_, i) => filas[i],
                      ),
              ),
              const SizedBox(height: 10),
              PaginadorApp(
                total: total,
                porPagina: widget.porPagina,
                pagina: pagina,
                onPagina: (p) => setState(() => _pagina = p),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Título de sección con su descripción y, a la derecha, la acción principal.
class CabeceraSeccion extends StatelessWidget {
  final String titulo;
  final String? descripcion;
  final Widget? accion;

  const CabeceraSeccion({
    super.key,
    required this.titulo,
    this.descripcion,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    // En celular, si el título repite al de la cabecera de la subvista, se omite
    // (con su descripción) y la acción sube a esa cabecera.
    final ctx = AppBreakpoints.esMobile(context)
        ? ContextoSubvista.de(context)
        : null;
    if (ctx != null && ctx.repite(titulo)) {
      const vacio = SizedBox.shrink();
      return accion == null
          ? vacio
          : RegistroAccionSubvista(
              contexto: ctx,
              accion: accion!,
              child: vacio,
            );
    }
    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        // En celular las descripciones no se muestran.
        if (descripcion != null && !AppBreakpoints.esMobile(context)) ...[
          const SizedBox(height: 4),
          Text(
            descripcion!,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
    if (accion == null) return textos;
    // El botón tiene su propio lugar: a la derecha, centrado con el bloque de
    // título y descripción (que no pasa por debajo de él). En pantallas
    // angostas baja debajo del texto.
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [textos, const SizedBox(height: 12), accion!],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: textos),
            const SizedBox(width: 24),
            accion!,
          ],
        );
      },
    );
  }
}

// Filas separadas por líneas finas, de [porPagina] en [porPagina] con el mismo
// paginador de toda la app.
class TarjetaFilas extends StatefulWidget {
  final List<Widget> filas;
  final int porPagina;
  // Lo que se ve cuando no hay filas (no cuenta para el paginador).
  final Widget? vacio;

  const TarjetaFilas({
    super.key,
    required this.filas,
    this.porPagina = 8,
    this.vacio,
  });

  @override
  State<TarjetaFilas> createState() => _TarjetaFilasState();
}

class _TarjetaFilasState extends State<TarjetaFilas> {
  int _pagina = 0;

  @override
  Widget build(BuildContext context) {
    final total = widget.filas.length;
    final paginas = total == 0 ? 1 : (total / widget.porPagina).ceil();
    final pagina = _pagina.clamp(0, paginas - 1);
    final desde = pagina * widget.porPagina;
    final hasta = (desde + widget.porPagina).clamp(0, total);
    final filas = widget.filas.sublist(desde, hasta);
    final lista = Container(
      // Sin tarjeta: las filas se apoyan sobre el fondo blanco, entre dos
      // líneas finas.
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (filas.isEmpty && widget.vacio != null) widget.vacio!,
          for (var i = 0; i < filas.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
            filas[i],
          ],
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        lista,
        const SizedBox(height: 10),
        PaginadorApp(
          total: total,
          porPagina: widget.porPagina,
          pagina: pagina,
          onPagina: (p) => setState(() => _pagina = p),
        ),
      ],
    );
  }
}

// Sección completa: cabecera + tarjeta de filas (o un mensaje si no hay).
class SeccionInventario extends StatelessWidget {
  final String titulo;
  final String? descripcion;
  final Widget? accion;
  final List<Widget> filas;
  final String mensajeVacio;
  // Controles entre la cabecera y la lista (buscador, filtros).
  final Widget? barra;

  const SeccionInventario({
    super.key,
    required this.titulo,
    this.descripcion,
    this.accion,
    required this.filas,
    this.mensajeVacio = 'No hay registros.',
    this.barra,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabeceraSeccion(
          titulo: titulo,
          descripcion: descripcion,
          accion: accion,
        ),
        if (barra != null) ...[const SizedBox(height: 14), barra!],
        const SizedBox(height: 14),
        TarjetaFilas(
          filas: filas,
          vacio: Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Text(
              mensajeVacio,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      ],
    );
  }
}

// Botón principal de una página ("+ Producto", "+ Táper"…): uno por página.
class BotonNuevo extends StatelessWidget {
  final String etiqueta;
  final VoidCallback? onPressed;

  const BotonNuevo({super.key, required this.etiqueta, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18),
      label: Text(etiqueta),
      style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
    );
  }
}

// Fila de una lista: título y detalle a la izquierda, controles a la derecha.
class FilaInventario extends StatelessWidget {
  final Widget titulo;
  final String? detalle;
  final List<Widget> controles;
  final VoidCallback? onTap;
  final Widget? extra;

  const FilaInventario({
    super.key,
    required this.titulo,
    this.detalle,
    this.controles = const [],
    this.onTap,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titulo,
                      if (detalle != null && detalle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          detalle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ...controles,
              ],
            ),
            ?extra,
          ],
        ),
      ),
    );
  }
}

// Nombre de una fila, atenuado si el elemento está inactivo.
Widget nombreFila(String texto, {bool activo = true}) => Text(
  texto,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
  style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: activo ? Colors.black87 : Colors.grey.shade500,
  ),
);

// Etiqueta pequeña (ej. "Inactivo", "Stock bajo").
class EtiquetaFila extends StatelessWidget {
  final String texto;
  final Color color;

  const EtiquetaFila(this.texto, {super.key, this.color = Colors.grey});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color == Colors.grey ? Colors.grey.shade700 : color,
        ),
      ),
    );
  }
}

// Nombre + etiquetas en una sola línea que salta si no cabe.
Widget tituloConEtiquetas(
  String nombre,
  List<Widget> etiquetas, {
  bool activo = true,
}) => Wrap(
  spacing: 8,
  runSpacing: 4,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    nombreFila(nombre, activo: activo),
    ...etiquetas,
  ],
);

// Tarjeta de cifra (Resumen, Utensilios rotos).
class TarjetaKpi extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String valor;
  final VoidCallback? onTap;

  const TarjetaKpi({
    super.key,
    required this.icono,
    required this.color,
    required this.titulo,
    required this.valor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    valor,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
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

// Fila de tarjetas de cifras: una columna en celular, todas en una fila si caben.
class FilaKpi extends StatelessWidget {
  final List<Widget> tarjetas;

  const FilaKpi({super.key, required this.tarjetas});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = c.maxWidth < 560 ? 1 : tarjetas.length;
        final ancho = (c.maxWidth - 12 * (columnas - 1)) / columnas;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final t in tarjetas) SizedBox(width: ancho, child: t),
          ],
        );
      },
    );
  }
}

// Confirmación con el mismo diseño de ventana que el resto. Devuelve true si
// el usuario confirma.
Future<bool> confirmarAccion(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String etiqueta = 'Eliminar',
  bool peligro = true,
}) async {
  final r = await showBlurDialog<bool>(
    context: context,
    builder: (dialogContext) => DialogoApp(
      titulo: titulo,
      ancho: 400,
      acciones: [
        OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: peligro ? AppColors.error : AppColors.primaryGreen,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(etiqueta),
        ),
      ],
      children: [
        Text(
          mensaje,
          style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700),
        ),
      ],
    ),
  );
  return r == true;
}

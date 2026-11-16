import 'package:flutter/material.dart';

import '../../data/catalogos_store.dart';
import '../../data/compras_store.dart';
import '../../data/inventario_periodo.dart';
import '../../data/inventario_store.dart';
import '../../data/utensilios_store.dart';
import '../../models/compra.dart';
import '../../models/inventario_movimiento.dart';
import '../../models/utensilio_roto.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import '../tabs_texto.dart';
import 'inventario_comun.dart';
import 'pagina_alquileres.dart';
import 'pagina_compras.dart';
import 'pagina_utensilios.dart';

// Inventario > Movimientos: todo lo que entra, sale o se pierde del almacén en
// una sola vista. "Todos" junta compras, mermas y ajustes, y roturas en una
// lista por fecha; cada filtro lleva a su lista con las acciones de ese tipo.
class PaginaMovimientos extends StatefulWidget {
  // 'todos' | 'compras' | 'ajustes' | 'roturas' | 'alquileres'.
  final String filtro;
  final ValueChanged<String> onFiltro;

  const PaginaMovimientos({
    super.key,
    required this.filtro,
    required this.onFiltro,
  });

  @override
  State<PaginaMovimientos> createState() => _PaginaMovimientosState();
}

class _PaginaMovimientosState extends State<PaginaMovimientos> {
  bool _cargando = true;

  static const _filtros = [
    ('todos', 'Todos'),
    ('compras', 'Compras'),
    ('ajustes', 'Mermas y ajustes'),
    ('roturas', 'Roturas'),
    ('alquileres', 'Alquileres'),
  ];

  @override
  void initState() {
    super.initState();
    periodoInventarioNotifier.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    periodoInventarioNotifier.removeListener(_cargar);
    super.dispose();
  }

  // Del libro de inventario se pide solo el periodo elegido.
  Future<void> _cargar() async {
    if (mounted) setState(() => _cargando = true);
    final p = periodoInventarioNotifier.value;
    await Future.wait([
      CatalogService.instance.cargarCompras(),
      CatalogService.instance.cargarProductosInventario(),
      CatalogService.instance.cargarUnidadesProducto(),
      CatalogService.instance.cargarUtensiliosRotos(),
      CatalogService.instance.cargarMovimientosInventario(
        desde: p.start,
        hasta: p.end,
      ),
    ]).whenComplete(() {
      if (mounted) setState(() => _cargando = false);
    });
  }

  String _producto(String id) =>
      productosInventario.where((p) => p.id == id).firstOrNull?.nombre ??
      'Producto';

  String _unidad(String productoId) {
    final p = productosInventario.where((x) => x.id == productoId).firstOrNull;
    return p == null ? '' : unidadDe(p.unidadProductoId);
  }

  // Mermas y ajustes manuales (entrada, salida, merma) del libro. El servidor ya
  // trajo solo el periodo; aquí no se arma ninguna lista aparte.
  Iterable<InventarioMovimiento> get _ajustes => movimientosInventario.values
      .expand((lista) => lista)
      .where(
        (m) =>
            codigosMovimientoManual.contains(m.tipoMovimiento.codigo) &&
            m.revierteId == null,
      );

  // Lo que entra en la lista del periodo, de lo más reciente a lo más antiguo:
  // solo referencias (compra, rotura o movimiento) con su fecha. Las filas se
  // construyen después, solo las de la página que se ve.
  List<({DateTime fecha, Object dato})> _items(String filtro) {
    final periodo = periodoInventarioNotifier.value;
    final items = <({DateTime fecha, Object dato})>[];
    if (filtro == 'todos') {
      for (final c in compras) {
        if (c.guardada && enPeriodo(periodo, c.fechaCompra)) {
          items.add((fecha: c.fechaCompra, dato: c));
        }
      }
      for (final u in utensiliosRotos) {
        if (enPeriodo(periodo, u.fecha)) items.add((fecha: u.fecha, dato: u));
      }
    }
    for (final m in _ajustes) {
      if (enPeriodo(periodo, m.fecha)) items.add((fecha: m.fecha, dato: m));
    }
    items.sort((a, b) => b.fecha.compareTo(a.fecha));
    return items;
  }

  Widget _filaDe(Object dato) {
    if (dato is Compra) return _filaCompra(dato);
    if (dato is UtensilioRoto) return _filaRotura(dato);
    return _filaAjuste(dato as InventarioMovimiento);
  }

  Widget _filaCompra(Compra c) {
    final n = (detallesPorCompra[c.id] ?? const []).length;
    return FilaInventario(
      onTap: () => widget.onFiltro('compras'),
      titulo: tituloConEtiquetas('Compra', [
        if (c.anulada) const EtiquetaFila('Anulada', color: AppColors.error),
      ]),
      detalle:
          '${fechaCorta(c.fechaCompra)} · $n producto(s)'
          '${c.anulada ? ' · ${c.motivoAnulacion ?? ''}' : ''}',
      controles: [
        Text(
          'S/ ${c.total.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: c.anulada ? Colors.grey.shade500 : null,
            decoration: c.anulada ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }

  Widget _filaRotura(UtensilioRoto u) {
    final estado = u.done
        ? const EtiquetaFila('Resuelto', color: AppColors.primaryGreen)
        : u.isPagado
        ? EtiquetaFila('A cuenta de sueldo', color: Colors.amber.shade800)
        : u.isRepuesto
        ? EtiquetaFila('Por reponer', color: Colors.blue.shade700)
        : const SizedBox.shrink();
    return FilaInventario(
      onTap: () => widget.onFiltro('roturas'),
      titulo: tituloConEtiquetas(
        'Rotura · ${u.cantidad}x ${u.productoNombre ?? _producto(u.productoInventarioId)}',
        [estado],
      ),
      detalle:
          '${fechaCorta(u.fecha)}'
          '${(u.empleadoNombre ?? '').isEmpty ? '' : ' · ${u.empleadoNombre}'}',
      controles: [
        Text(
          'S/ ${u.costoTotal.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ],
    );
  }

  Widget _filaAjuste(InventarioMovimiento m) {
    final signo = m.tipoMovimiento.signo >= 0 ? '+' : '−';
    return FilaInventario(
      titulo: nombreFila(
        '${m.tipoMovimiento.tipoMovimiento} · ${m.productoNombre ?? _producto(m.productoInventarioId)}',
      ),
      detalle:
          '${fechaCorta(m.fecha)}'
          '${(m.notas ?? '').isEmpty ? '' : ' · ${m.notas}'}',
      controles: [
        Text(
          '$signo${cantidadTexto(m.cantidad)} ${_unidad(m.productoInventarioId)}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ],
    );
  }

  Widget _lista(String filtro) {
    final periodo = periodoInventarioNotifier.value;
    final items = _items(filtro);
    return PaginaListaFija(
      reiniciarCon: '$filtro|${periodo.start}|${periodo.end}',
      cabecera: CabeceraSeccion(
        titulo: filtro == 'todos'
            ? 'Todos los movimientos'
            : 'Mermas y ajustes',
        descripcion: filtro == 'todos'
            ? 'Compras, mermas, ajustes y roturas de las fechas elegidas, de '
                  'lo más reciente a lo más antiguo. Toca una fila para '
                  'gestionarla.'
            : 'Entradas, salidas y mermas manuales de las fechas elegidas. Se '
                  'registran desde Almacén > Productos > Ajustar stock.',
      ),
      mensajeVacio: _cargando
          ? 'Cargando…'
          : 'No hay movimientos en las fechas elegidas.',
      cantidad: items.length,
      filaEn: (i) => _filaDe(items[i].dato),
    );
  }

  @override
  Widget build(BuildContext context) {
    final margen = AppBreakpoints.esMobile(context) ? 16.0 : 24.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(margen, 8, margen, 4),
          child: TabsTexto(
            tabs: [
              for (final f in _filtros)
                TabTexto(
                  etiqueta: f.$2,
                  activa: f.$1 == widget.filtro,
                  onTap: () => widget.onFiltro(f.$1),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (widget.filtro) {
            'compras' => const PaginaCompras(),
            'roturas' => const PaginaUtensilios(),
            'alquileres' => const PaginaAlquileres(),
            'ajustes' => _lista('ajustes'),
            _ => _lista('todos'),
          },
        ),
      ],
    );
  }
}

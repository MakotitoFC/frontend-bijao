import 'package:flutter/material.dart';

import '../../data/catalogos_store.dart';
import '../../data/compras_store.dart';
import '../../data/inventario_store.dart';
import '../../data/utensilios_store.dart';
import '../../models/inventario_movimiento.dart';
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
    Future.wait([
      CatalogService.instance.cargarCompras(),
      CatalogService.instance.cargarProductosInventario(),
      CatalogService.instance.cargarUnidadesProducto(),
      CatalogService.instance.cargarUtensiliosRotos(),
      CatalogService.instance.cargarMovimientosInventario(),
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

  // Mermas y ajustes manuales (entrada, salida, merma) del libro.
  List<InventarioMovimiento> get _ajustes => [
    for (final lista in movimientosInventario.values)
      for (final m in lista)
        if (codigosMovimientoManual.contains(m.tipoMovimiento.codigo) &&
            m.revierteId == null)
          m,
  ];

  // Filas del "Todos" y de "Mermas y ajustes", de la más reciente a la más
  // antigua. Tocar una fila lleva al filtro donde se gestiona.
  List<Widget> _filas(String filtro) {
    final items = <({DateTime fecha, Widget fila})>[];

    if (filtro == 'todos') {
      for (final c in compras.where((c) => c.guardada)) {
        final n = (detallesPorCompra[c.id] ?? const []).length;
        items.add((
          fecha: c.fechaCompra,
          fila: FilaInventario(
            onTap: () => widget.onFiltro('compras'),
            titulo: tituloConEtiquetas('Compra', [
              if (c.anulada)
                const EtiquetaFila('Anulada', color: AppColors.error),
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
          ),
        ));
      }
      for (final u in utensiliosRotos) {
        final estado = u.done
            ? const EtiquetaFila('Resuelto', color: AppColors.primaryGreen)
            : u.isPagado
            ? EtiquetaFila('A cuenta de sueldo', color: Colors.amber.shade800)
            : u.isRepuesto
            ? EtiquetaFila('Por reponer', color: Colors.blue.shade700)
            : const SizedBox.shrink();
        items.add((
          fecha: u.fecha,
          fila: FilaInventario(
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
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ));
      }
    }

    for (final m in _ajustes) {
      final signo = m.tipoMovimiento.signo >= 0 ? '+' : '−';
      items.add((
        fecha: m.fecha,
        fila: FilaInventario(
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
        ),
      ));
    }

    items.sort((a, b) => b.fecha.compareTo(a.fecha));
    return [for (final i in items) i.fila];
  }

  Widget _lista(String filtro) {
    final filas = _filas(filtro);
    return PaginaListaFija(
      cabecera: CabeceraSeccion(
        titulo: filtro == 'todos'
            ? 'Todos los movimientos'
            : 'Mermas y ajustes',
        descripcion: filtro == 'todos'
            ? 'Compras, mermas, ajustes y roturas, de lo más reciente a lo '
                  'más antiguo. Toca una fila para gestionarla.'
            : 'Entradas, salidas y mermas manuales. Se registran desde '
                  'Almacén > Productos > Ajustar stock.',
      ),
      mensajeVacio: _cargando
          ? 'Cargando…'
          : 'Aún no hay movimientos registrados.',
      filas: filas,
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

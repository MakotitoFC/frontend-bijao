import 'package:flutter/material.dart';

import '../../data/catalogos_store.dart';
import '../../data/inventario_store.dart';
import '../../models/inventario_movimiento.dart';
import '../../models/producto_inventario.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import 'inventario_comun.dart';
import 'pagina_productos.dart' show ajustarStockDeProducto;

// Inventario > Resumen: cómo está el stock de un vistazo y qué hay que hacer.
// Solo consulta: lo que se crea o edita vive en las demás páginas.
class PaginaResumen extends StatefulWidget {
  // Cambia a otra página del módulo (por clave).
  final ValueChanged<String> irA;

  const PaginaResumen({super.key, required this.irA});

  @override
  State<PaginaResumen> createState() => _PaginaResumenState();
}

class _PaginaResumenState extends State<PaginaResumen> {
  static const _maxPorReponer = 8;

  @override
  void initState() {
    super.initState();
    Future.wait([
      CatalogService.instance.cargarTiposProducto(),
      CatalogService.instance.cargarUnidadesProducto(),
      CatalogService.instance.cargarProductosInventario(),
    ]).then((_) {
      if (mounted) setState(() {});
    });
  }

  List<ProductoInventario> get _porReponer {
    final lista = productosInventario
        .where((p) => p.estado && (p.stockActual <= 0 || p.stockBajo))
        .toList();
    // Primero los agotados.
    lista.sort((a, b) {
      final sa = a.stockActual <= 0 ? 0 : 1;
      final sb = b.stockActual <= 0 ? 0 : 1;
      return sa != sb ? sa - sb : a.nombre.compareTo(b.nombre);
    });
    return lista;
  }

  Map<String, double> get _stockPorTipo {
    final mapa = <String, double>{for (final t in tiposProducto) t.id: 0};
    for (final p in productosInventario) {
      mapa[p.tipoProductoId] = (mapa[p.tipoProductoId] ?? 0) + p.stockActual;
    }
    return mapa;
  }

  List<({ProductoInventario producto, InventarioMovimiento movimiento})>
  get _actividadReciente {
    final todos =
        <({ProductoInventario producto, InventarioMovimiento movimiento})>[];
    for (final p in productosInventario) {
      for (final m
          in movimientosInventario[p.id] ?? const <InventarioMovimiento>[]) {
        todos.add((producto: p, movimiento: m));
      }
    }
    todos.sort((a, b) => b.movimiento.fecha.compareTo(a.movimiento.fecha));
    return todos.take(8).toList();
  }

  Future<void> _ajustar(ProductoInventario p) async {
    if (await ajustarStockDeProducto(context, p) && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final porReponer = _porReponer;
    final sinStock = productosInventario
        .where((p) => p.estado && p.stockActual <= 0)
        .length;
    final stockBajo = porReponer.length - sinStock;
    return PaginaInventario(
      secciones: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CabeceraSeccion(
              titulo: 'Resumen',
              descripcion:
                  'Cómo está tu stock. Toca una cifra para ir a los productos.',
            ),
            const SizedBox(height: 14),
            FilaKpi(
              tarjetas: [
                TarjetaKpi(
                  icono: Icons.inventory_2_outlined,
                  color: AppColors.primaryGreen,
                  titulo: 'Productos',
                  valor: '${productosInventario.length}',
                  onTap: () => widget.irA('productos'),
                ),
                TarjetaKpi(
                  icono: Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  titulo: 'Con stock bajo',
                  valor: '$stockBajo',
                  onTap: () => widget.irA('productos'),
                ),
                TarjetaKpi(
                  icono: Icons.remove_shopping_cart_outlined,
                  color: AppColors.error,
                  titulo: 'Sin stock',
                  valor: '$sinStock',
                  onTap: () => widget.irA('productos'),
                ),
              ],
            ),
          ],
        ),
        SeccionInventario(
          titulo: 'Por reponer',
          descripcion: 'Productos agotados o en su stock mínimo.',
          mensajeVacio: 'Todo en orden: ningún producto necesita reposición.',
          filas: [
            for (final p in porReponer.take(_maxPorReponer))
              FilaInventario(
                titulo: tituloConEtiquetas(p.nombre, [
                  if (p.stockActual <= 0)
                    const EtiquetaFila('Sin stock', color: AppColors.error)
                  else
                    const EtiquetaFila('Stock bajo', color: AppColors.warning),
                ]),
                detalle:
                    '${cantidadTexto(p.stockActual)} ${unidadDe(p.unidadProductoId)} · '
                    'mínimo ${cantidadTexto(p.stockMinimo)}',
                controles: [
                  TextButton(
                    onPressed: () => _ajustar(p),
                    child: const Text('Ajustar stock'),
                  ),
                ],
              ),
            if (porReponer.length > _maxPorReponer)
              FilaInventario(
                onTap: () => widget.irA('productos'),
                titulo: Text(
                  'Y ${porReponer.length - _maxPorReponer} más en Productos',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreenDark,
                  ),
                ),
              ),
          ],
        ),
        _stockPorTipoSeccion(),
        SeccionInventario(
          titulo: 'Actividad reciente',
          descripcion: 'Últimas entradas, salidas y mermas.',
          mensajeVacio: 'Sin movimientos registrados aún.',
          filas: [
            for (final a in _actividadReciente)
              _filaActividad(a.producto, a.movimiento),
          ],
        ),
      ],
    );
  }

  Widget _stockPorTipoSeccion() {
    final datos = _stockPorTipo;
    final maximo = datos.values.isEmpty
        ? 1.0
        : datos.values
              .reduce((a, b) => a > b ? a : b)
              .clamp(1.0, double.infinity);
    final conTipos = tiposProducto
        .where((t) => (datos[t.id] ?? 0) > 0)
        .toList();
    return SeccionInventario(
      titulo: 'Stock por tipo',
      descripcion: 'Stock total de cada tipo de producto.',
      mensajeVacio: 'Aún no hay stock registrado.',
      filas: [
        for (final t in conTipos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    t.tipoProducto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (datos[t.id] ?? 0) / maximo,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    cantidadTexto(datos[t.id] ?? 0),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _filaActividad(ProductoInventario p, InventarioMovimiento m) {
    final entrada = m.tipoMovimiento.esEntrada;
    final color = entrada ? AppColors.primaryGreen : AppColors.warning;
    return FilaInventario(
      titulo: Row(
        children: [
          Icon(
            entrada ? Icons.arrow_downward : Icons.arrow_upward,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(child: nombreFila(p.nombre)),
        ],
      ),
      detalle:
          '${m.tipoMovimiento.tipoMovimiento} · ${cantidadTexto(m.cantidad.toDouble())} ${unidadDe(p.unidadProductoId)} · ${fechaCorta(m.fecha)}',
    );
  }
}

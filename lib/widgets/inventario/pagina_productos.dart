import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../data/catalogos_store.dart';
import '../../data/inventario_store.dart';
import '../../models/inventario_movimiento.dart';
import '../../models/producto_inventario.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/blur_dialog.dart';
import '../ajustar_stock_dialog.dart';
import '../app_search_field.dart';
import '../app_tag.dart';
import '../app_toast.dart';
import '../dialogo_app.dart';
import '../menu_flotante.dart';
import '../producto_inventario_form_dialog.dart';
import '../tabs_desplazables.dart';
import 'inventario_comun.dart';

// Abre el ajuste de stock de un producto (entrada, salida o merma) y lo registra
// en el libro de inventario del backend, que es quien actualiza el stock.
// Devuelve true si se registró el movimiento.
Future<bool> ajustarStockDeProducto(
  BuildContext context,
  ProductoInventario producto,
) async {
  final movimiento = await showBlurDialog<InventarioMovimiento>(
    context: context,
    builder: (_) => AjustarStockDialog(producto: producto),
  );
  if (movimiento == null || !context.mounted) return false;
  try {
    await CatalogService.instance.registrarAjusteInventario(
      productoInventarioId: movimiento.productoInventarioId,
      tipoMovimientoId: movimiento.tipoMovimiento.id,
      cantidad: movimiento.cantidad,
      notas: movimiento.notas,
    );
    if (context.mounted) {
      showAppToast(
        context,
        'Stock actualizado: ${movimiento.tipoMovimiento.tipoMovimiento.toLowerCase()} de '
        '${cantidadTexto(movimiento.cantidad)} en "${producto.nombre}".',
        type: ToastType.success,
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      showAppToast(
        context,
        'No se pudo ajustar el stock: ${e.toString().replaceFirst('Exception: ', '')}',
        type: ToastType.error,
      );
    }
    return false;
  }
}

// Inventario > Productos: la lista de todo lo que se lleva en stock. Es el único
// lugar donde se crea, edita, elimina o se ajusta el stock de un producto.
class PaginaProductos extends StatefulWidget {
  const PaginaProductos({super.key});

  @override
  State<PaginaProductos> createState() => _PaginaProductosState();
}

class _PaginaProductosState extends State<PaginaProductos> {
  String? _filtroTipo; // null = Todos
  String _busqueda = '';
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    await Future.wait([
      CatalogService.instance.cargarTiposProducto(),
      CatalogService.instance.cargarUnidadesProducto(),
      CatalogService.instance.cargarProductosInventario(),
    ]);
    if (mounted) setState(() => _cargando = false);
  }

  List<ProductoInventario> get _visibles {
    final q = _busqueda.trim().toLowerCase();
    final lista = productosInventario.where((p) {
      if (_filtroTipo != null && p.tipoProductoId != _filtroTipo) return false;
      return q.isEmpty || p.nombre.toLowerCase().contains(q);
    }).toList();
    lista.sort((a, b) => a.nombre.compareTo(b.nombre));
    return lista;
  }

  Future<void> _crear() async {
    final nuevo = await showBlurDialog<ProductoInventario>(
      context: context,
      builder: (_) => const ProductoInventarioFormDialog(),
    );
    if (nuevo != null && mounted) setState(() {});
  }

  Future<void> _editar(ProductoInventario p) async {
    final editado = await showBlurDialog<ProductoInventario>(
      context: context,
      builder: (_) => ProductoInventarioFormDialog(producto: p),
    );
    if (editado != null && mounted) setState(() {});
  }

  Future<void> _eliminar(ProductoInventario p) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar producto',
      mensaje: '¿Eliminar "${p.nombre}" del inventario?',
    );
    if (!ok) return;
    try {
      await CatalogService.instance.eliminarProductoInventario(p.id);
      if (!mounted) return;
      setState(() {});
      showAppToast(context, 'Producto eliminado', type: ToastType.success);
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'Error al eliminar: $e', type: ToastType.error);
    }
  }

  Future<void> _ajustar(ProductoInventario p) async {
    if (await ajustarStockDeProducto(context, p) && mounted) setState(() {});
  }

  void _verMovimientos(ProductoInventario p) {
    showBlurDialog<void>(
      context: context,
      builder: (_) => _MovimientosDialog(producto: p),
    );
  }

  Widget _fila(ProductoInventario p, bool compacto) {
    final detalle = [
      tipoProductoDe(p.tipoProductoId),
      '${cantidadTexto(p.stockActual)} ${unidadDe(p.unidadProductoId)} en stock',
      if (p.stockMinimo > 0) 'mínimo ${cantidadTexto(p.stockMinimo)}',
      if (p.costoReposicion != null)
        'costo S/ ${p.costoReposicion!.toStringAsFixed(2)}',
      if (p.precioCliente != null)
        'precio S/ ${p.precioCliente!.toStringAsFixed(2)}',
    ].join(' · ');
    return FilaInventario(
      onTap: () => _verMovimientos(p),
      titulo: tituloConEtiquetas(p.nombre, [
        if (!p.estado) const EtiquetaFila('Inactivo'),
        if (p.stockActual <= 0)
          const EtiquetaFila('Sin stock', color: AppColors.error)
        else if (p.stockBajo)
          const EtiquetaFila('Stock bajo', color: AppColors.warning),
      ], activo: p.estado),
      detalle: detalle,
      controles: [
        if (!compacto)
          TextButton(
            onPressed: () => _ajustar(p),
            child: const Text('Ajustar stock'),
          ),
        MenuFlotante<String>(
          tooltip: 'Más acciones',
          anchoMinimo: 190,
          opciones: [
            if (compacto)
              const OpcionMenu(valor: 'ajustar', etiqueta: 'Ajustar stock'),
            const OpcionMenu(valor: 'movimientos', etiqueta: 'Ver movimientos'),
            const OpcionMenu(valor: 'editar', etiqueta: 'Editar'),
            const OpcionMenu(
              valor: 'eliminar',
              etiqueta: 'Eliminar',
              color: AppColors.error,
            ),
          ],
          onSeleccionar: (v) {
            switch (v) {
              case 'ajustar':
                _ajustar(p);
              case 'movimientos':
                _verMovimientos(p);
              case 'editar':
                _editar(p);
              case 'eliminar':
                _eliminar(p);
            }
          },
          disparador: (context, abierto) => Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              LucideIcons.ellipsisVertical,
              size: 18,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _visibles;
    final compacto = MediaQuery.sizeOf(context).width < 760;
    final sinDatos = productosInventario.isEmpty;
    return PaginaInventario(
      secciones: [
        SeccionInventario(
          titulo: 'Productos',
          descripcion:
              'Todo lo que llevas en stock. Toca un producto para ver sus '
              'movimientos.',
          accion: BotonNuevo(etiqueta: 'Producto', onPressed: _crear),
          barra: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: AppSearchField(
                  hint: 'Buscar producto...',
                  onChanged: (v) => setState(() => _busqueda = v),
                ),
              ),
              if (tiposProducto.isNotEmpty) ...[
                const SizedBox(height: 12),
                TabsDesplazables(
                  child: Row(
                    children: [
                      AppTag(
                        etiqueta: 'Todos',
                        activo: _filtroTipo == null,
                        onTap: () => setState(() => _filtroTipo = null),
                      ),
                      for (final t in tiposProducto)
                        AppTag(
                          etiqueta: t.tipoProducto,
                          activo: _filtroTipo == t.id,
                          onTap: () => setState(() => _filtroTipo = t.id),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          mensajeVacio: _cargando && sinDatos
              ? 'Cargando…'
              : (sinDatos
                    ? 'Aún no hay productos. Crea el primero con "Producto".'
                    : 'Ningún producto coincide con la búsqueda.'),
          filas: [for (final p in visibles) _fila(p, compacto)],
        ),
      ],
    );
  }
}

// Movimientos (entradas, salidas y mermas) de un producto, leídos del libro de
// inventario del backend.
class _MovimientosDialog extends StatefulWidget {
  final ProductoInventario producto;

  const _MovimientosDialog({required this.producto});

  @override
  State<_MovimientosDialog> createState() => _MovimientosDialogState();
}

class _MovimientosDialogState extends State<_MovimientosDialog> {
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    CatalogService.instance
        .cargarMovimientosInventario(productoId: widget.producto.id)
        .whenComplete(() {
          if (mounted) setState(() => _cargando = false);
        });
  }

  @override
  Widget build(BuildContext context) {
    final historial = movimientosInventario[widget.producto.id] ?? [];
    return DialogoApp(
      titulo: 'Movimientos · ${widget.producto.nombre}',
      ancho: 480,
      children: [
        if (historial.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                _cargando ? 'Cargando…' : 'Sin movimientos registrados aún',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          )
        else
          for (var i = 0; i < historial.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
            _filaMovimiento(historial[i]),
          ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _filaMovimiento(InventarioMovimiento m) {
    final entrada = m.tipoMovimiento.esEntrada;
    final detalle = [
      if (m.usuarioNombre != null && m.usuarioNombre!.isNotEmpty)
        m.usuarioNombre!,
      if (m.notas != null && m.notas!.isNotEmpty) m.notas!,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            entrada ? Icons.arrow_downward : Icons.arrow_upward,
            size: 18,
            color: entrada ? AppColors.primaryGreen : AppColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${m.tipoMovimiento.tipoMovimiento} · ${entrada ? '+' : '-'}${cantidadTexto(m.cantidad)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (detalle.isNotEmpty)
                  Text(
                    detalle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          Text(
            fechaCorta(m.fecha),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

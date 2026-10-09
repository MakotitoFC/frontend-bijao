import 'package:flutter/material.dart';

import '../data/catalogos_store.dart';
import '../data/compras_store.dart';
import '../data/inventario_store.dart';
import '../data/utensilios_store.dart';
import '../models/compra.dart';
import '../models/compra_detalle.dart';
import '../models/inventario_movimiento.dart';
import '../models/producto_inventario.dart';
import '../models/rbac.dart';
import '../models/taper.dart';
import '../models/utensilio_roto.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../widgets/ajustar_stock_dialog.dart';
import '../widgets/app_search_field.dart';
import '../widgets/app_tag.dart';
import '../widgets/app_toast.dart';
import '../widgets/compra_detalle_form.dart';
import '../widgets/compra_form_dialog.dart';
import '../widgets/pago_cuenta_empleado_dialog.dart';
import '../widgets/pestanas_vista.dart';
import '../widgets/producto_inventario_form_dialog.dart';
import '../widgets/tabs_desplazables.dart';
import '../widgets/taper_form_dialog.dart';
import '../widgets/tipo_producto_form_dialog.dart';
import '../widgets/unidad_producto_form_dialog.dart';
import '../widgets/utensilio_roto_form_dialog.dart';

// Inventario: 4 subvistas (Productos, Tápers, Compras, Utensilios rotos), solo-Administrador.
class InventarioScreen extends StatelessWidget {
  const InventarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PestanasVista(
        pestanas: [
          (etiqueta: 'Productos', contenido: (_) => const _ProductosTab()),
          (etiqueta: 'Tápers', contenido: (_) => const _TapersTab()),
          (etiqueta: 'Compras', contenido: (_) => const _ComprasTab()),
          (
            etiqueta: 'Utensilios rotos',
            contenido: (_) => const _UtensiliosRotosTab(),
          ),
        ],
      ),
    );
  }
}

String _unidadDe(String id) =>
    unidadesProducto
        .where((u) => u.id == id)
        .map((u) => u.unidad)
        .firstOrNull ??
    '—';

String _tipoProductoDe(String id) =>
    tiposProducto
        .where((t) => t.id == id)
        .map((t) => t.tipoProducto)
        .firstOrNull ??
    '—';

String _fecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// ---------------- Productos ----------------

class _ProductosTab extends StatefulWidget {
  const _ProductosTab();

  @override
  State<_ProductosTab> createState() => _ProductosTabState();
}

class _ProductosTabState extends State<_ProductosTab> {
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
    var lista = productosInventario.where((p) {
      if (_filtroTipo != null && p.tipoProductoId != _filtroTipo) return false;
      if (_busqueda.trim().isEmpty) return true;
      return p.nombre.toLowerCase().contains(_busqueda.trim().toLowerCase());
    }).toList();
    lista.sort((a, b) => a.nombre.compareTo(b.nombre));
    return lista;
  }

  Future<void> _crearProducto() async {
    final nuevo = await showDialog<ProductoInventario>(
      context: context,
      builder: (_) => const ProductoInventarioFormDialog(),
    );
    if (nuevo != null) setState(() {});
  }

  Future<void> _editarProducto(ProductoInventario producto) async {
    final editado = await showDialog<ProductoInventario>(
      context: context,
      builder: (_) => ProductoInventarioFormDialog(producto: producto),
    );
    if (editado != null) setState(() {});
  }

  Future<void> _eliminarProducto(ProductoInventario producto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${producto.nombre}" del inventario?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      try {
        await CatalogService.instance.eliminarProductoInventario(producto.id);
        if (mounted) {
          setState(() {});
          showAppToast(context, 'Producto eliminado', type: ToastType.success);
        }
      } catch (e) {
        if (mounted) {
          showAppToast(context, 'Error al eliminar: $e', type: ToastType.error);
        }
      }
    }
  }

  Future<void> _crearTipoProducto() async {
    final nuevo = await showDialog(
      context: context,
      builder: (_) => const TipoProductoFormDialog(),
    );
    if (nuevo != null) setState(() {});
  }

  Future<void> _crearUnidadProducto() async {
    final nuevo = await showDialog(
      context: context,
      builder: (_) => const UnidadProductoFormDialog(),
    );
    if (nuevo != null) setState(() {});
  }

  Future<void> _ajustarStock(ProductoInventario producto) async {
    final movimiento = await showBlurDialog<InventarioMovimiento>(
      context: context,
      builder: (_) => AjustarStockDialog(producto: producto),
    );
    if (movimiento == null) return;
    setState(() => registrarMovimientoInventario(movimiento));
  }

  void _verHistorial(ProductoInventario producto) {
    final historial = movimientosInventario[producto.id] ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Movimientos · ${producto.nombre}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: historial.isEmpty
                      ? Center(
                          child: Text(
                            'Sin movimientos registrados aún',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: historial.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: Colors.grey.shade200),
                          itemBuilder: (context, index) {
                            final m = historial[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    m.tipoMovimiento.esEntrada
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    size: 18,
                                    color: m.tipoMovimiento.esEntrada
                                        ? AppColors.primaryGreen
                                        : AppColors.error,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${m.tipoMovimiento.tipoMovimiento} · ${m.cantidad}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (m.notas != null)
                                          Text(
                                            m.notas!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _fecha(m.fecha),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipTipo(String etiqueta, String? valor) {
    return AppTag(
      etiqueta: etiqueta,
      activo: _filtroTipo == valor,
      onTap: () => setState(() => _filtroTipo = valor),
    );
  }

  // ---- resumen (estilo dashboard) ----

  int get _sinStock =>
      productosInventario.where((p) => p.stockActual <= 0).length;

  Map<String, double> get _stockPorTipo {
    final mapa = <String, double>{for (final t in tiposProducto) t.id: 0};
    for (final p in productosInventario) {
      mapa[p.tipoProductoId] = (mapa[p.tipoProductoId] ?? 0) + p.stockActual;
    }
    return mapa;
  }

  double get _stockPromedio => productosInventario.isEmpty
      ? 0
      : productosInventario.fold(0.0, (s, p) => s + p.stockActual) /
            productosInventario.length;

  double get _stockMaximo => productosInventario.isEmpty
      ? 0
      : productosInventario
            .map((p) => p.stockActual)
            .reduce((a, b) => a > b ? a : b);

  double get _stockMinimoPromedio {
    final conMinimo = productosInventario.where((p) => p.stockMinimo > 0);
    if (conMinimo.isEmpty) return 0;
    return conMinimo.fold(0.0, (s, p) => s + p.stockMinimo) / conMinimo.length;
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

  @override
  Widget build(BuildContext context) {
    final visibles = _visibles;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _resumenStats(),
          const SizedBox(height: 16),
          _resumenOverview(),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final analitica = _tarjetaAnalitica();
              final actividad = _tarjetaActividad();
              if (c.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [analitica, const SizedBox(height: 16), actividad],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: analitica),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: actividad),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Productos',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: AppSearchField(
                  hint: 'Buscar producto...',
                  onChanged: (v) => setState(() => _busqueda = v),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _crearTipoProducto,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade800,
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                icon: const Icon(Icons.category_outlined, size: 16),
                label: const Text('+ Tipo prod.'),
              ),
              OutlinedButton.icon(
                onPressed: _crearUnidadProducto,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade800,
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                icon: const Icon(Icons.straighten_outlined, size: 16),
                label: const Text('+ Unidad'),
              ),
              OutlinedButton.icon(
                onPressed: () => showDialog<Taper>(
                  context: context,
                  builder: (_) => const TaperFormDialog(),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen),
                ),
                icon: const Icon(Icons.takeout_dining_outlined, size: 16),
                label: const Text('+ Táper'),
              ),
              FilledButton.icon(
                onPressed: _crearProducto,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('+ Nuevo producto'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TabsDesplazables(
            child: Row(
              children: [
                _chipTipo('Todos', null),
                for (final t in tiposProducto) _chipTipo(t.tipoProducto, t.id),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (visibles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Sin productos para mostrar',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          else
            for (final p in visibles) ...[
              _tarjetaProducto(p),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  // Fila de 3 tarjetas: total, stock bajo y sin stock.
  Widget _resumenStats() {
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = c.maxWidth < 620 ? 1 : 3;
        final ancho = columnas == 1 ? c.maxWidth : (c.maxWidth - 24) / 3;
        Widget tarjeta(
          IconData icono,
          Color color,
          String titulo,
          String valor,
        ) {
          return SizedBox(
            width: ancho,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
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

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            tarjeta(
              Icons.inventory_2_outlined,
              AppColors.primaryGreen,
              'Productos en inventario',
              '${productosInventario.length}',
            ),
            tarjeta(
              Icons.warning_amber_rounded,
              AppColors.warning,
              'Alertas de stock bajo',
              '${_visiblesBajo.length}',
            ),
            tarjeta(
              Icons.remove_shopping_cart_outlined,
              AppColors.error,
              'Productos sin stock',
              '$_sinStock',
            ),
          ],
        );
      },
    );
  }

  List<ProductoInventario> get _visiblesBajo =>
      productosInventario.where((p) => p.stockBajo).toList();

  // Tarjeta "Resumen de inventario": fecha + acciones (refrescar / nuevo).
  Widget _resumenOverview() {
    final hoy = DateTime.now();
    final titulo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.dashboard_customize_outlined,
            size: 20,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Resumen de inventario',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            Text(
              _fecha(hoy),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
    final aviso = _visiblesBajo.isEmpty
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_visiblesBajo.length} producto(s) necesitan reposición',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          );
    final actualizar = OutlinedButton.icon(
      onPressed: _cargando ? null : _cargar,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.grey.shade300),
      ),
      icon: _cargando
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh, size: 16),
      label: const Text('Actualizar'),
    );
    final nuevo = FilledButton.icon(
      onPressed: _crearProducto,
      style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
      icon: const Icon(Icons.add, size: 16),
      label: const Text('Nuevo producto'),
    );
    final nuevoTaper = OutlinedButton.icon(
      onPressed: () => showDialog<Taper>(
        context: context,
        builder: (_) => const TaperFormDialog(),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
        side: const BorderSide(color: AppColors.primaryGreen),
      ),
      icon: const Icon(Icons.takeout_dining_outlined, size: 16),
      label: const Text('Nuevo táper'),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 720) {
            return Row(
              children: [
                titulo,
                if (aviso != null) ...[const SizedBox(width: 12), aviso],
                const Spacer(),
                actualizar,
                const SizedBox(width: 10),
                nuevoTaper,
                const SizedBox(width: 10),
                nuevo,
              ],
            );
          }
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [titulo, ?aviso, actualizar, nuevoTaper, nuevo],
          );
        },
      ),
    );
  }

  // Barras de stock total por tipo de producto + 3 métricas debajo.
  Widget _tarjetaAnalitica() {
    final datos = _stockPorTipo;
    final maximo = datos.values.isEmpty
        ? 1.0
        : datos.values
              .reduce((a, b) => a > b ? a : b)
              .clamp(1, double.infinity);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stock por tipo de producto',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 155,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final t in tiposProducto)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            (datos[t.id] ?? 0).toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 90 * ((datos[t.id] ?? 0) / maximo),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.75,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t.tipoProducto,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 14),
          Row(
            children: [
              _metrica('Stock mínimo prom.', _stockMinimoPromedio),
              _metrica('Stock promedio', _stockPromedio),
              _metrica('Stock máximo', _stockMaximo),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metrica(String etiqueta, double valor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valor.toStringAsFixed(0),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          Text(
            etiqueta,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // Últimos movimientos de inventario (entradas/salidas/mermas).
  Widget _tarjetaActividad() {
    final actividad = _actividadReciente;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actividad reciente',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 12),
          if (actividad.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Sin movimientos registrados aún',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            )
          else
            for (final a in actividad) ...[
              _filaActividad(a.producto, a.movimiento),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _filaActividad(ProductoInventario p, InventarioMovimiento m) {
    final entrada = m.tipoMovimiento.esEntrada;
    final color = entrada ? AppColors.primaryGreen : AppColors.warning;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            entrada ? Icons.arrow_downward : Icons.arrow_upward,
            size: 14,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              Text(
                '${m.tipoMovimiento.tipoMovimiento} · ${m.cantidad} ${_unidadDe(p.unidadProductoId)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Text(
          _fecha(m.fecha),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _tarjetaProducto(ProductoInventario p) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _verHistorial(p),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: p.stockBajo
                ? AppColors.error.withValues(alpha: 0.4)
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!p.estado) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Inactivo',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _tipoProductoDe(p.tipoProductoId),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${p.stockActual} ${_unidadDe(p.unidadProductoId)} en stock',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.stockBajo
                              ? AppColors.error
                              : Colors.grey.shade800,
                        ),
                      ),
                      if (p.costoReposicion != null)
                        Text(
                          'Costo S/ ${p.costoReposicion!.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      if (p.precioCliente != null)
                        Text(
                          'Precio cliente S/ ${p.precioCliente!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryGreenDark,
                          ),
                        ),
                    ],
                  ),
                  if (p.stockBajo) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Stock bajo (mínimo ${p.stockMinimo})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.swap_vert, size: 20),
                  tooltip: 'Ajustar stock',
                  onPressed: () => _ajustarStock(p),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Editar',
                  onPressed: () => _editarProducto(p),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  tooltip: 'Eliminar',
                  onPressed: () => _eliminarProducto(p),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Compras ----------------

class _ComprasTab extends StatefulWidget {
  const _ComprasTab();

  @override
  State<_ComprasTab> createState() => _ComprasTabState();
}

class _ComprasTabState extends State<_ComprasTab> {
  String _nombreProducto(String id) =>
      productosInventario
          .where((p) => p.id == id)
          .map((p) => p.nombre)
          .firstOrNull ??
      'Producto eliminado';

  // Compras colapsadas por el usuario (por defecto todas están expandidas) y
  // compras con el formulario de detalle abierto.
  final Set<String> _colapsadas = {};
  final Set<String> _conFormulario = {};
  // Compras que se están guardando en el backend.
  final Set<String> _guardando = {};

  // Envía el borrador (compra + detalles) al backend y repone el stock.
  Future<void> _guardarCompra(Compra c) async {
    setState(() => _guardando.add(c.id));
    try {
      await CatalogService.instance.guardarCompra(c.id);
      if (!mounted) return;
      setState(() => _conFormulario.remove(c.id));
      showAppToast(
        context,
        'Compra guardada y stock actualizado.',
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _guardando.remove(c.id));
    }
  }

  // "+ Compra": crea el registro de la compra. Queda expandida en la lista, con
  // el formulario de detalle abierto para ingresar sus productos.
  Future<void> _nuevaCompra() async {
    final creada = await showBlurDialog<Compra>(
      context: context,
      builder: (_) => const CompraFormDialog(),
    );
    if (creada == null || !mounted) return;
    setState(() => _conFormulario.add(creada.id));
  }

  // Compra como acordeón: cabecera (fecha, total) y, al expandir, sus
  // detalles. Un borrador permite agregar productos y se guarda con "Guardar".
  Widget _tarjetaCompra(Compra c) {
    final expandida = !_colapsadas.contains(c.id);
    final detalles = detallesPorCompra[c.id] ?? [];
    final borrador = !c.guardada;
    final conFormulario = borrador && _conFormulario.contains(c.id);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (!_colapsadas.remove(c.id)) _colapsadas.add(c.id);
            }),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Compra del ${_fecha(c.fechaCompra)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            if (borrador) ...[
                              const SizedBox(width: 8),
                              const AppTag(
                                etiqueta: 'Borrador',
                                activo: false,
                                color: AppColors.platoDelDia,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${detalles.length} producto(s)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'S/ ${c.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: expandida ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: !expandida
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(height: 1, color: Colors.grey.shade200),
                        if (c.notas != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              c.notas!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'DETALLES',
                                style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                            if (borrador && !conFormulario)
                              FilledButton.icon(
                                onPressed: () =>
                                    setState(() => _conFormulario.add(c.id)),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Detalle'),
                              ),
                          ],
                        ),
                        if (conFormulario) ...[
                          const SizedBox(height: 8),
                          CompraDetalleForm(
                            key: ValueKey('detalle-${c.id}'),
                            compraId: c.id,
                            onAgregado: () => setState(() {}),
                            onCerrar: () =>
                                setState(() => _conFormulario.remove(c.id)),
                          ),
                        ],
                        if (detalles.isEmpty && !conFormulario)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'Aún no agregaste productos a esta compra',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ),
                          ),
                        for (final d in detalles) _filaDetalleCompra(d, c),
                        if (borrador) ...[
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _guardando.contains(c.id)
                                    ? null
                                    : () => setState(() {
                                        descartarCompra(c.id);
                                        _conFormulario.remove(c.id);
                                      }),
                                child: const Text('Descartar'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed:
                                    detalles.isEmpty || _guardando.contains(c.id)
                                    ? null
                                    : () => _guardarCompra(c),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                ),
                                icon: _guardando.contains(c.id)
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check, size: 18),
                                label: const Text('Guardar compra'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filaDetalleCompra(CompraDetalle d, Compra c) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nombreProducto(d.productoInventarioId),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${d.cantidad} ${_unidadDe(d.unidadProductoId)} × S/ ${d.precioUnitario.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (d.factorABase != 1)
                  Text(
                    '1 ${_unidadDe(d.unidadProductoId)} = ${d.factorABase} · ${d.cantidadBase} en unidad base',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
          Text(
            'S/ ${d.precioTotal.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (!c.guardada)
            IconButton(
              tooltip: 'Quitar',
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  setState(() => quitarDetalleDeCompra(c.id, d.id)),
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Historial de compras',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: _nuevaCompra,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Compra'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: compras.isEmpty
                ? Center(
                    child: Text(
                      'Aún no hay compras registradas',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.separated(
                    itemCount: compras.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _tarjetaCompra(compras[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Utensilios rotos ----------------

class _UtensiliosRotosTab extends StatefulWidget {
  const _UtensiliosRotosTab();

  @override
  State<_UtensiliosRotosTab> createState() => _UtensiliosRotosTabState();
}

class _UtensiliosRotosTabState extends State<_UtensiliosRotosTab> {
  String _busqueda = '';
  String _filtro = 'todos'; // todos, pendientes, cobro, reposicion, resueltos
  bool _cargando = false;
  List<UserRBACModel> _empleados = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final res = await Future.wait([
        CatalogService.instance.cargarUtensiliosRotos(),
        CatalogService.instance.cargarProductosInventario(),
        CatalogService.instance.cargarUsuariosRBAC(),
      ]);
      if (mounted) {
        setState(() {
          _empleados = res[2] as List<UserRBACModel>;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _nombreProducto(UtensilioRoto u) {
    if (u.productoNombre != null && u.productoNombre!.isNotEmpty) {
      return u.productoNombre!;
    }
    return productosInventario
            .where((p) => p.id == u.productoInventarioId)
            .map((p) => p.nombre)
            .firstOrNull ??
        'Producto';
  }

  String _nombreEmpleado(UtensilioRoto u) {
    if (u.empleadoNombre != null && u.empleadoNombre!.isNotEmpty) {
      return u.empleadoNombre!;
    }
    return _empleados
            .where((e) => e.id == u.empleadoId)
            .map((e) => e.usuario)
            .firstOrNull ??
        'Empleado';
  }

  Future<void> _registrar() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => const UtensilioRotoFormDialog(),
    );
    if (res == true) _cargar();
  }

  Future<void> _abonarPago(UtensilioRoto u) async {
    final pagado = await showDialog<bool>(
      context: context,
      builder: (_) => PagoCuentaEmpleadoDialog(rotura: u),
    );
    if (pagado == true) _cargar();
  }

  Future<void> _marcarRepuesto(UtensilioRoto u) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar reposición'),
        content: Text(
          '¿Confirmar que el empleado ya repuso "${_nombreProducto(u)}" en físico?\nEsto marcará el registro como resuelto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await CatalogService.instance.actualizarUtensilioRoto(u.copyWith(done: true));
        if (mounted) {
          showAppToast(context, 'Reposición registrada como completada', type: ToastType.success);
          _cargar();
        }
      } catch (e) {
        if (mounted) {
          showAppToast(context, 'Error: $e', type: ToastType.error);
        }
      }
    }
  }

  Future<void> _eliminar(UtensilioRoto u) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text('¿Eliminar el registro de rotura de "${_nombreProducto(u)}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await CatalogService.instance.eliminarUtensilioRoto(u.id);
        if (mounted) {
          showAppToast(context, 'Registro eliminado', type: ToastType.success);
          _cargar();
        }
      } catch (e) {
        if (mounted) {
          showAppToast(context, 'Error al eliminar: $e', type: ToastType.error);
        }
      }
    }
  }

  List<UtensilioRoto> get _filtrados {
    final query = _busqueda.trim().toLowerCase();
    return utensiliosRotos.where((u) {
      if (query.isNotEmpty) {
        final prod = _nombreProducto(u).toLowerCase();
        final emp = _nombreEmpleado(u).toLowerCase();
        final notas = (u.notas ?? '').toLowerCase();
        if (!prod.contains(query) && !emp.contains(query) && !notas.contains(query)) {
          return false;
        }
      }

      switch (_filtro) {
        case 'pendientes':
          return !u.done;
        case 'cobro':
          return u.isPagado;
        case 'reposicion':
          return u.isRepuesto;
        case 'resueltos':
          return u.done;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalIncidentes = utensiliosRotos.length;
    final totalCosto = utensiliosRotos.fold(0.0, (s, u) => s + u.costoTotal);
    final pendientes = utensiliosRotos.where((u) => !u.done).length;
    final resueltos = utensiliosRotos.where((u) => u.done).length;

    final lista = _filtrados;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tarjetas de métricas
          LayoutBuilder(
            builder: (context, c) {
              final columnas = c.maxWidth < 650 ? 2 : 4;
              final ancho = (c.maxWidth - ((columnas - 1) * 12)) / columnas;
              Widget tarjeta(IconData icon, Color color, String titulo, String valor) {
                return SizedBox(
                  width: ancho,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                              Text(
                                valor,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  tarjeta(Icons.broken_image_outlined, Colors.red.shade400, 'Total incidentes', '$totalIncidentes'),
                  tarjeta(Icons.payments_outlined, Colors.orange.shade600, 'Costo acumulado', 'S/ ${totalCosto.toStringAsFixed(2)}'),
                  tarjeta(Icons.pending_actions, Colors.amber.shade700, 'Pendientes', '$pendientes'),
                  tarjeta(Icons.check_circle_outline, AppColors.primaryGreen, 'Resueltos', '$resueltos'),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Cabecera con Buscador y botón Registrar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: AppSearchField(
                    hint: 'Buscar por producto, empleado o nota...',
                    onChanged: (v) => setState(() => _busqueda = v),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.outlined(
                      tooltip: 'Actualizar',
                      onPressed: _cargando ? null : _cargar,
                      icon: _cargando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _registrar,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Registrar rotura'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Filtros
          TabsDesplazables(
            child: Row(
              children: [
                _filtroChip('Todos', 'todos'),
                _filtroChip('Pendientes', 'pendientes'),
                _filtroChip('Por cobrar (A cuenta)', 'cobro'),
                _filtroChip('Por reponer (Físico)', 'reposicion'),
                _filtroChip('Resueltos', 'resueltos'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Lista de Utensilios
          if (_cargando && utensiliosRotos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (lista.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      utensiliosRotos.isEmpty
                          ? 'Aún no se han registrado roturas de utensilios'
                          : 'No se encontraron registros con los filtros actuales',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      utensiliosRotos.isEmpty
                          ? 'Registra roturas o mermas para descontar de stock y gestionar cobros a empleados.'
                          : 'Prueba cambiando los filtros de búsqueda.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lista.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final u = lista[index];
                return _tarjetaRotura(u);
              },
            ),
        ],
      ),
    );
  }

  Widget _filtroChip(String label, String valor) {
    final activo = _filtro == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AppTag(
        etiqueta: label,
        activo: activo,
        onTap: () => setState(() => _filtro = valor),
      ),
    );
  }

  Widget _tarjetaRotura(UtensilioRoto u) {
    final prodNombre = _nombreProducto(u);
    final empNombre = _nombreEmpleado(u);
    final saldoRestante = (u.costoTotal - u.totalPagado).clamp(0.0, u.costoTotal);
    final progreso = u.costoTotal > 0 ? (u.totalPagado / u.costoTotal).clamp(0.0, 1.0) : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: u.done ? Colors.grey.shade200 : (u.isPagado ? Colors.amber.shade200 : Colors.blue.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (u.done ? AppColors.primaryGreen : Colors.red).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  u.done ? Icons.check_circle_outline : Icons.broken_image_outlined,
                  color: u.done ? AppColors.primaryGreen : Colors.red,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${u.cantidad}x $prodNombre',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        Text(
                          'S/ ${u.costoTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Responsable: $empNombre · ${_fecha(u.fecha)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Eliminar registro',
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                onPressed: () => _eliminar(u),
              ),
            ],
          ),

          if (u.notas != null && u.notas!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Nota: ${u.notas}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
              ),
            ),
          ],

          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 12),

          // Estado y Acciones
          Row(
            children: [
              // Badges de estado
              if (u.done)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 14, color: AppColors.primaryGreen),
                      SizedBox(width: 4),
                      Text(
                        'Resuelto / Liquidado',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                )
              else if (u.isPagado)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.payments_outlined, size: 14, color: Colors.amber.shade900),
                      const SizedBox(width: 4),
                      Text(
                        'A cuenta de sueldo (Pendiente)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                )
              else if (u.isRepuesto)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cached, size: 14, color: Colors.blue.shade900),
                      const SizedBox(width: 4),
                      Text(
                        'A reponer en físico (Pendiente)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              // Botones de acción según el caso
              if (!u.done && u.isPagado)
                FilledButton.icon(
                  onPressed: () => _abonarPago(u),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Abonar pago', style: TextStyle(fontSize: 13)),
                ),

              if (!u.done && u.isRepuesto)
                FilledButton.icon(
                  onPressed: () => _marcarRepuesto(u),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Confirmar reposición', style: TextStyle(fontSize: 13)),
                ),
            ],
          ),

          // Barra de pagos si es a cuenta de empleado
          if (u.isPagado) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                color: u.done ? AppColors.primaryGreen : Colors.amber.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Abonado: S/ ${u.totalPagado.toStringAsFixed(2)} de S/ ${u.costoTotal.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
                Text(
                  saldoRestante > 0 ? 'Saldo: S/ ${saldoRestante.toStringAsFixed(2)}' : 'Saldado ✓',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: saldoRestante > 0 ? Colors.red.shade700 : AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------- Tápers ----------------

class _TapersTab extends StatefulWidget {
  const _TapersTab();

  @override
  State<_TapersTab> createState() => _TapersTabState();
}

class _TapersTabState extends State<_TapersTab> {
  String _busqueda = '';
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    await CatalogService.instance.cargarTapers();
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _crearTaper() async {
    final nuevo = await showDialog<Taper>(
      context: context,
      builder: (_) => const TaperFormDialog(),
    );
    if (nuevo != null) setState(() {});
  }

  Future<void> _editarTaper(Taper taper) async {
    final editado = await showDialog<Taper>(
      context: context,
      builder: (_) => TaperFormDialog(taper: taper),
    );
    if (editado != null) setState(() {});
  }

  Future<void> _eliminarTaper(Taper taper) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar Táper'),
        content: Text('¿Seguro que deseas eliminar "${taper.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await CatalogService.instance.eliminarTaper(taper.id);
        if (!mounted) return;
        setState(() {});
        showAppToast(context, 'Táper eliminado', type: ToastType.success);
      } catch (e) {
        if (!mounted) return;
        showAppToast(context, 'Error al eliminar táper: $e',
            type: ToastType.error);
      }
    }
  }

  Future<void> _alternarEstado(Taper taper) async {
    try {
      await CatalogService.instance.alternarEstadoTaper(taper);
      if (!mounted) return;
      setState(() {});
      showAppToast(
        context,
        taper.estado ? 'Táper desactivado' : 'Táper activado',
        type: ToastType.info,
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'Error: $e', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tapers = CatalogService.instance.tapers;
    final query = _busqueda.trim().toLowerCase();
    final filtrados = tapers.where((t) {
      if (query.isEmpty) return true;
      return t.nombre.toLowerCase().contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tarjeta de cabecera
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.takeout_dining,
                    color: AppColors.primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Catálogo de Tápers',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Configura los recipientes y costos para platos y pedidos para llevar o delivery.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Actualizar lista',
                  onPressed: _cargando ? null : _cargar,
                  icon: _cargando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _crearTaper,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nuevo táper'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Buscador
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppSearchField(
                    hint: 'Buscar táper por nombre...',
                    onChanged: (v) => setState(() => _busqueda = v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Total: ${filtrados.length} táper(s)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Lista de tápers
          if (_cargando && tapers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtrados.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.takeout_dining_outlined,
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tapers.isEmpty
                          ? 'Aún no hay tápers registrados'
                          : 'No se encontraron tápers con "$_busqueda"',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tapers.isEmpty
                          ? 'Crea un táper para poder asociarlo a los platos de la carta.'
                          : 'Prueba con otro término de búsqueda.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    if (tapers.isEmpty) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _crearTaper,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Agregar táper'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final ancho = c.maxWidth;
                final esDosColumnas = ancho >= 700;

                Widget buildCard(Taper t) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: t.estado
                            ? Colors.grey.shade200
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: t.estado
                                ? AppColors.primaryGreen.withValues(alpha: 0.1)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.takeout_dining,
                            color: t.estado
                                ? AppColors.primaryGreen
                                : Colors.grey.shade500,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.nombre,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: t.estado ? Colors.black87 : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreen
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'S/ ${t.precio.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: t.estado
                                          ? AppColors.primaryGreen
                                              .withValues(alpha: 0.12)
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      t.estado ? 'Activo' : 'Inactivo',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: t.estado
                                            ? AppColors.primaryGreen
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: t.estado ? 'Desactivar' : 'Activar',
                          icon: Icon(
                            t.estado
                                ? Icons.toggle_on
                                : Icons.toggle_off_outlined,
                            size: 26,
                            color: t.estado
                                ? AppColors.primaryGreen
                                : Colors.grey,
                          ),
                          onPressed: () => _alternarEstado(t),
                        ),
                        IconButton(
                          tooltip: 'Editar táper',
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _editarTaper(t),
                        ),
                        IconButton(
                          tooltip: 'Eliminar táper',
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.error,
                          ),
                          onPressed: () => _eliminarTaper(t),
                        ),
                      ],
                    ),
                  );
                }

                if (!esDosColumnas) {
                  return Column(
                    children: [for (final t in filtrados) buildCard(t)],
                  );
                }

                return Wrap(
                  spacing: 14,
                  runSpacing: 0,
                  children: [
                    for (final t in filtrados)
                      SizedBox(
                        width: (ancho - 14) / 2,
                        child: buildCard(t),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

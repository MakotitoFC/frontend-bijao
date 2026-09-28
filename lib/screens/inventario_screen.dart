import 'package:flutter/material.dart';

import '../data/catalogos_store.dart';
import '../data/compras_store.dart';
import '../data/inventario_store.dart';
import '../data/usuarios_store.dart';
import '../data/utensilios_store.dart';
import '../models/inventario_movimiento.dart';
import '../models/producto_inventario.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../widgets/ajustar_stock_dialog.dart';
import '../widgets/compra_form_dialog.dart';
import '../widgets/pestanas_vista.dart';
import '../widgets/producto_inventario_form_dialog.dart';
import '../widgets/tabs_desplazables.dart';
import '../widgets/utensilio_roto_form_dialog.dart';

// Inventario: 3 subvistas (Productos, Compras, Utensilios rotos), solo-Administrador.
class InventarioScreen extends StatelessWidget {
  const InventarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PestanasVista(
        pestanas: [
          (etiqueta: 'Productos', contenido: (_) => const _ProductosTab()),
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

String _unidadDe(int id) =>
    mockUnidadesProducto.where((u) => u.id == id).map((u) => u.unidad).firstOrNull ??
    '—';

String _tipoProductoDe(int id) =>
    mockTiposProducto
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
  int? _filtroTipo; // null = Todos
  String _busqueda = '';

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
    final nuevo = await showBlurDialog<ProductoInventario>(
      context: context,
      builder: (_) => const ProductoInventarioFormDialog(),
    );
    if (nuevo != null) setState(() => agregarProductoInventario(nuevo));
  }

  Future<void> _editarProducto(ProductoInventario producto) async {
    final editado = await showBlurDialog<ProductoInventario>(
      context: context,
      builder: (_) => ProductoInventarioFormDialog(producto: producto),
    );
    if (editado != null) setState(() => actualizarProductoInventario(editado));
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
      setState(() => eliminarProductoInventario(producto.id));
    }
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

  Widget _chipTipo(String etiqueta, int? valor) {
    final activo = _filtroTipo == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _filtroTipo = valor),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: activo
                ? AppColors.primaryGreen
                : AppColors.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            etiqueta,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: activo ? Colors.white : AppColors.verdeTexto,
            ),
          ),
        ),
      ),
    );
  }

  // ---- resumen (estilo dashboard) ----

  int get _sinStock => productosInventario.where((p) => p.stockActual <= 0).length;

  Map<int, double> get _stockPorTipo {
    final mapa = <int, double>{for (final t in mockTiposProducto) t.id: 0};
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
      : productosInventario.map((p) => p.stockActual).reduce((a, b) => a > b ? a : b);

  double get _stockMinimoPromedio {
    final conMinimo = productosInventario.where((p) => p.stockMinimo > 0);
    if (conMinimo.isEmpty) return 0;
    return conMinimo.fold(0.0, (s, p) => s + p.stockMinimo) / conMinimo.length;
  }

  List<({ProductoInventario producto, InventarioMovimiento movimiento})>
  get _actividadReciente {
    final todos = <({ProductoInventario producto, InventarioMovimiento movimiento})>[];
    for (final p in productosInventario) {
      for (final m in movimientosInventario[p.id] ?? const <InventarioMovimiento>[]) {
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _busqueda = v),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Buscar producto...',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _crearProducto,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Producto'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TabsDesplazables(
            child: Row(
              children: [
                _chipTipo('Todos', null),
                for (final t in mockTiposProducto)
                  _chipTipo(t.tipoProducto, t.id),
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
        final ancho = columnas == 1
            ? c.maxWidth
            : (c.maxWidth - 24) / 3;
        Widget tarjeta(IconData icono, Color color, String titulo, String valor) {
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
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
          ),
          if (_visiblesBajo.isNotEmpty)
            Container(
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
            ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => setState(() {}),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Actualizar'),
          ),
          FilledButton.icon(
            onPressed: _crearProducto,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Nuevo producto'),
          ),
        ],
      ),
    );
  }

  // Barras de stock total por tipo de producto + 3 métricas debajo.
  Widget _tarjetaAnalitica() {
    final datos = _stockPorTipo;
    final maximo = datos.values.isEmpty
        ? 1.0
        : datos.values.reduce((a, b) => a > b ? a : b).clamp(1, double.infinity);
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
                for (final t in mockTiposProducto)
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
                              color: AppColors.primaryGreen.withValues(alpha: 0.75),
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
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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
            color: p.stockBajo ? AppColors.error.withValues(alpha: 0.4) : Colors.grey.shade200,
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
                      if (p.estado == 'inactivo') ...[
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

  Future<void> _nuevaCompra() async {
    final creada = await showBlurDialog<bool>(
      context: context,
      builder: (_) => const CompraFormDialog(),
    );
    if (creada == true) setState(() {});
  }

  void _verDetalle(String compraId, String proveedor) {
    final detalles = detallesPorCompra[compraId] ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
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
                  'Compra · $proveedor',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: detalles.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final d = detalles[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
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
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'S/ ${d.precioTotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
                    itemBuilder: (context, index) {
                      final c = compras[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _verDetalle(c.id, c.proveedor),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.proveedor,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _fecha(c.fechaCompra),
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
                            ],
                          ),
                        ),
                      );
                    },
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
  String _nombreProducto(String id) =>
      productosInventario
          .where((p) => p.id == id)
          .map((p) => p.nombre)
          .firstOrNull ??
      'Producto eliminado';

  String _nombreEmpleado(String id) =>
      usuarios.where((u) => u.id == id).map((u) => u.nombre).firstOrNull ??
      'Usuario eliminado';

  Future<void> _registrar() async {
    final registrado = await showBlurDialog<bool>(
      context: context,
      builder: (_) => const UtensilioRotoFormDialog(),
    );
    if (registrado == true) setState(() {});
  }

  Widget _chipEstado(String etiqueta, bool activo, ValueChanged<bool> onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => onTap(!activo)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activo
              ? AppColors.primaryGreen.withValues(alpha: 0.12)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activo ? AppColors.primaryGreen : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              activo ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: activo ? AppColors.primaryGreen : Colors.grey.shade500,
            ),
            const SizedBox(width: 6),
            Text(
              etiqueta,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: activo ? AppColors.primaryGreenDark : Colors.grey.shade700,
              ),
            ),
          ],
        ),
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
                  'Utensilios rotos',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: _registrar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Registrar rotura'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: utensiliosRotos.isEmpty
                ? Center(
                    child: Text(
                      'Aún no se han registrado roturas',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.separated(
                    itemCount: utensiliosRotos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final u = utensiliosRotos[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${u.cantidad}x ${_nombreProducto(u.productoInventarioId)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Text(
                                  'S/ ${u.costoTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_nombreEmpleado(u.empleadoId)} · ${_fecha(u.fecha)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (u.notas != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                u.notas!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _chipEstado(
                                  'Pagado',
                                  u.isPagado,
                                  (v) => actualizarUtensilioRoto(
                                    u.copyWith(isPagado: v),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _chipEstado(
                                  'Repuesto',
                                  u.isRespuesto,
                                  (v) => actualizarUtensilioRoto(
                                    u.copyWith(isRespuesto: v),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

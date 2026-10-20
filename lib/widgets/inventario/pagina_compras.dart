import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../data/compras_store.dart';
import '../../data/inventario_store.dart';
import '../../models/compra.dart';
import '../../models/compra_detalle.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/blur_dialog.dart';
import '../app_tag.dart';
import '../app_toast.dart';
import '../compra_detalle_form.dart';
import '../compra_form_dialog.dart';
import 'inventario_comun.dart';

// Inventario > Compras: cada compra repone el stock de los productos que trae.
// Una compra nueva es un borrador: se arma y recién al guardarla entra al stock.
class PaginaCompras extends StatefulWidget {
  const PaginaCompras({super.key});

  @override
  State<PaginaCompras> createState() => _PaginaComprasState();
}

class _PaginaComprasState extends State<PaginaCompras> {
  // Compras plegadas por el usuario (por defecto todas están abiertas) y
  // compras con el formulario de producto abierto.
  final Set<String> _colapsadas = {};
  final Set<String> _conFormulario = {};
  // Compras que se están guardando en el backend.
  final Set<String> _guardando = {};

  @override
  void initState() {
    super.initState();
    Future.wait([
      CatalogService.instance.cargarCompras(),
      CatalogService.instance.cargarProductosInventario(),
      CatalogService.instance.cargarUnidadesProducto(),
    ]).then((_) {
      if (mounted) setState(() {});
    });
  }

  String _nombreProducto(String id) =>
      productosInventario
          .where((p) => p.id == id)
          .map((p) => p.nombre)
          .firstOrNull ??
      'Producto eliminado';

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

  // Crea la compra: queda abierta, con el formulario para agregar productos.
  Future<void> _nuevaCompra() async {
    final creada = await showBlurDialog<Compra>(
      context: context,
      builder: (_) => const CompraFormDialog(),
    );
    if (creada == null || !mounted) return;
    setState(() => _conFormulario.add(creada.id));
  }

  Widget _tarjetaCompra(Compra c) {
    final abierta = !_colapsadas.contains(c.id);
    final detalles = detallesPorCompra[c.id] ?? [];
    final borrador = !c.guardada;
    final conFormulario = borrador && _conFormulario.contains(c.id);
    final guardando = _guardando.contains(c.id);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Compra del ${fechaCorta(c.fechaCompra)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            if (borrador)
                              const AppTag(
                                etiqueta: 'Borrador',
                                activo: false,
                                color: AppColors.naranja,
                              ),
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
                    turns: abierta ? 0.5 : 0,
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
            child: !abierta
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                        if (borrador && !conFormulario)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    setState(() => _conFormulario.add(c.id)),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Agregar producto'),
                              ),
                            ),
                          ),
                        if (conFormulario) ...[
                          const SizedBox(height: 10),
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
                            child: Text(
                              'Aún no agregaste productos a esta compra.',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                        for (final d in detalles) _filaDetalle(d, c),
                        if (borrador) ...[
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: guardando
                                      ? null
                                      : () => setState(() {
                                          descartarCompra(c.id);
                                          _conFormulario.remove(c.id);
                                        }),
                                  child: const Text('Descartar'),
                                ),
                                FilledButton.icon(
                                  onPressed: detalles.isEmpty || guardando
                                      ? null
                                      : () => _guardarCompra(c),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primaryGreen,
                                  ),
                                  icon: guardando
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

  Widget _filaDetalle(CompraDetalle d, Compra c) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
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
                  '${d.cantidad} ${unidadDe(d.unidadProductoId)} × S/ ${d.precioUnitario.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (d.factorABase != 1)
                  Text(
                    '1 ${unidadDe(d.unidadProductoId)} = ${d.factorABase} · ${d.cantidadBase} en unidad base',
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
              icon: Icon(LucideIcons.x, size: 16, color: Colors.grey.shade700),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PaginaInventario(
      secciones: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CabeceraSeccion(
              titulo: 'Compras',
              descripcion:
                  'Cada compra guardada suma al stock los productos que trae.',
              accion: BotonNuevo(etiqueta: 'Compra', onPressed: _nuevaCompra),
            ),
            const SizedBox(height: 14),
            if (compras.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 22,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  'Aún no hay compras. Registra la primera con "Compra".',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              for (var i = 0; i < compras.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _tarjetaCompra(compras[i]),
              ],
          ],
        ),
      ],
    );
  }
}

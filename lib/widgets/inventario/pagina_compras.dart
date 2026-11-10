import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../data/compras_store.dart';
import '../../data/inventario_store.dart';
import '../../models/compra.dart';
import '../../models/compra_detalle.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/blur_dialog.dart';
import '../anular_compra_dialog.dart';
import '../app_toast.dart';
import '../compra_form_dialog.dart';
import 'inventario_comun.dart';

// Inventario > Compras: cada compra guardada suma al stock los productos que
// trae. La compra se arma entera en un solo modal ("Compra"); aquí se listan
// las guardadas, de a [_porPagina] por página. Una compra guardada se edita
// (fecha y notas) o se anula con su motivo; no se borra.
class PaginaCompras extends StatefulWidget {
  const PaginaCompras({super.key});

  @override
  State<PaginaCompras> createState() => _PaginaComprasState();
}

class _PaginaComprasState extends State<PaginaCompras> {
  static const _porPagina = 6;

  // Compras plegadas por el usuario (por defecto todas están abiertas).
  final Set<String> _colapsadas = {};

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

  // Compras guardadas (los borradores viven solo dentro del modal).
  List<Compra> get _guardadas => [
    for (final c in compras)
      if (c.guardada) c,
  ];

  // Abre el modal de una compra nueva: fecha, notas y productos juntos.
  Future<void> _nuevaCompra() async {
    final r = await showBlurDialog<bool>(
      context: context,
      builder: (_) => const CompraFormDialog(),
    );
    if (!mounted) return;
    setState(() {});
    if (r == true) {
      showAppToast(
        context,
        'Compra guardada y stock actualizado.',
        type: ToastType.success,
      );
    }
  }

  // Cambia la fecha y las notas de una compra guardada.
  Future<void> _editarCompra(Compra c) async {
    final r = await showBlurDialog<bool>(
      context: context,
      builder: (_) => CompraFormDialog(compra: c),
    );
    if (r == true && mounted) {
      setState(() {});
      showAppToast(context, 'Compra actualizada.', type: ToastType.success);
    }
  }

  // Anula una compra guardada: pide el motivo y revierte el stock que sumó.
  Future<void> _anularCompra(Compra c) async {
    final r = await showBlurDialog<bool>(
      context: context,
      builder: (_) => AnularCompraDialog(compraId: c.id),
    );
    if (r == true && mounted) {
      setState(() {});
      showAppToast(
        context,
        'Compra anulada y stock revertido.',
        type: ToastType.success,
      );
    }
  }

  Widget _tarjetaCompra(Compra c) {
    final abierta = !_colapsadas.contains(c.id);
    final detalles = detallesPorCompra[c.id] ?? [];
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
                            if (c.anulada)
                              const EtiquetaFila(
                                'Anulada',
                                color: AppColors.error,
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c.anulada
                              ? 'Motivo: ${c.motivoAnulacion ?? ''}'
                              : '${detalles.length} producto(s)',
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
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: c.anulada ? Colors.grey.shade500 : null,
                      decoration: c.anulada ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (!c.anulada) ...[
                    IconButton(
                      tooltip: 'Editar compra',
                      onPressed: () => _editarCompra(c),
                      icon: Icon(
                        LucideIcons.pencil,
                        size: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Anular compra',
                      onPressed: () => _anularCompra(c),
                      icon: const Icon(
                        LucideIcons.ban,
                        size: 16,
                        color: AppColors.error,
                      ),
                    ),
                  ] else
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
                        if (c.notasLimpias != null &&
                            c.notasLimpias!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              c.notasLimpias!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        for (final d in detalles) _filaDetalle(d),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filaDetalle(CompraDetalle d) {
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _guardadas;
    return PaginaListaFija(
      tarjetas: true,
      porPagina: _porPagina,
      reiniciarCon: lista.length,
      cabecera: CabeceraSeccion(
        titulo: 'Compras',
        descripcion:
            'Cada compra guardada suma al stock los productos que trae.',
        accion: BotonNuevo(etiqueta: 'Compra', onPressed: _nuevaCompra),
      ),
      mensajeVacio: 'Aún no hay compras. Registra la primera con "Compra".',
      filas: [for (final c in lista) _tarjetaCompra(c)],
    );
  }
}

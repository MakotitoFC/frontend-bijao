import 'package:flutter/material.dart';

import '../data/cartas_store.dart';
import '../data/insumos_store.dart';
import '../data/pedidos_store.dart';
import '../data/variantes_store.dart';
import '../models/carta_item.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'app_search_field.dart';
import 'producto_opciones_dialog.dart';

// Agrega productos de la carta a un pedido ya registrado. Devuelve true si se
// agregó algo. (El plato del día se agrega con su propio tag.)
class AgregarProductoDialog extends StatefulWidget {
  final Pedido pedido;
  final bool esAdmin;

  const AgregarProductoDialog({
    super.key,
    required this.pedido,
    required this.esAdmin,
  });

  @override
  State<AgregarProductoDialog> createState() => _AgregarProductoDialogState();
}

class _AgregarProductoDialogState extends State<AgregarProductoDialog> {
  final _busqueda = TextEditingController();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  List<CartaItem> get _productos {
    final t = _busqueda.text.trim().toLowerCase();
    return cartasNotifier.value
        .where((c) => c.disponible && c.nombrePlato.toLowerCase().contains(t))
        .toList();
  }

  Future<void> _elegir(CartaItem item) async {
    final r = await showBlurDialog<ProductoConfigurado>(
      context: context,
      builder: (_) =>
          ProductoOpcionesDialog(item: item, esAdmin: widget.esAdmin),
    );
    if (r == null || !mounted) return;
    final linea = PedidoLine(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      cartaId: item.id,
      nombrePlato: item.nombrePlato,
      cantidad: r.cantidad,
      modificadores: r.modificadores,
      presentacion: r.presentacion,
      variante: r.variante,
      promocion: null,
      comentario: r.comentario,
      precioUnitario: r.precioUnitario,
      descuentoAplicado: 0,
      precioTotalLinea: r.precioUnitario * r.cantidad,
    );
    agregarLineaAPedido(widget.pedido.id, linea);
    registrarConsumoAutomaticoDeLinea(linea);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final ancho = MediaQuery.sizeOf(context).width;
    final productos = _productos;
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: esMobile ? ancho : 520,
          maxWidth: esMobile ? ancho : 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            esMobile ? 28 : 22,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Agregar producto · #${widget.pedido.numeroPedido}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: AppSearchField(
                  controller: _busqueda,
                  hint: 'Buscar producto...',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: productos.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Text(
                            cartasNotifier.value.isEmpty
                                ? 'No hay productos en la carta.'
                                : 'Sin resultados',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [for (final p in productos) _fila(p)],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fila(CartaItem p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _elegir(p),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: p.imagenBytes != null
                      ? Image.memory(p.imagenBytes!, fit: BoxFit.cover)
                      : ColoredBox(
                          color: const Color(0xFFF1F3F0),
                          child: Icon(
                            Icons.restaurant_outlined,
                            size: 20,
                            color: Colors.grey.shade400,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p.nombrePlato,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                p.precioCliente != null
                    ? 'S/ ${p.precioCliente!.toStringAsFixed(2)}'
                    : (precioMinimoDeVariantes(p.id) != null
                          ? 'Desde S/ ${precioMinimoDeVariantes(p.id)!.toStringAsFixed(2)}'
                          : 'Según tamaño'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreenDark,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.add_circle_outline, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }
}

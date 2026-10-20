import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../data/cartas_store.dart';
import '../data/disponibilidad_store.dart';
import '../data/insumos_store.dart';
import '../data/pedidos_store.dart';
import '../data/variantes_store.dart';
import '../services/api_client.dart';
import '../services/disponibilidad_service.dart';
import '../services/pedido_mozo_service.dart';
import '../models/carta_item.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'app_search_field.dart';
import 'app_toast.dart';
import 'imagen_plato.dart';
import 'producto_opciones_dialog.dart';
import 'dialogo_app.dart';

// Agrega productos de la carta a un pedido ya registrado. Devuelve true si se
// agregó algo.
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
  void initState() {
    super.initState();
    DisponibilidadService.instance.cargarHoy();
  }

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
      builder: (_) => ProductoOpcionesDialog(
        item: item,
        esAdmin: widget.esAdmin,
        tipoEntregaInicial: widget.pedido.tipoPedido,
      ),
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
      tipoEntrega: r.tipoEntrega,
      aplicaTaper: r.llevaTaper,
      taperId: r.taperId,
      precioTaper: r.precioTaper,
      precioBase: r.variante?.precioCliente ?? item.precioCliente ?? 0.0,
    );
    if (AppConfig.usarApiPedidosMozo &&
        PedidoMozoService.instance.puedeOperar(widget.pedido)) {
      try {
        await PedidoMozoService.instance.agregarProducto(
          widget.pedido.id,
          linea,
        );
      } on PedidoCambioException catch (e) {
        if (mounted) showAppToast(context, e.mensaje, type: ToastType.info);
        return;
      } catch (e) {
        if (!mounted) return;
        DisponibilidadService.instance.cargarHoy();
        showAppToast(
          context,
          e is ApiException ? e.message : e.toString(),
          type: ToastType.error,
        );
        return;
      }
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
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
                  BotonCerrarCircular(
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SeparadorDialogo(),
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
    return ListenableBuilder(
      listenable: Listenable.merge([
        disponibilidadHoyNotifier,
        configStockNotifier,
      ]),
      builder: (context, _) {
        final estado = estadoDisponibilidadDe(p.id);
        return Opacity(
          opacity: estado.vendible ? 1 : 0.55,
          child: _filaContenido(p, estado),
        );
      },
    );
  }

  Widget _filaContenido(CartaItem p, EstadoDisponibilidad estado) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: estado.vendible ? () => _elegir(p) : null,
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
                  child: ImagenPlato(item: p, tamanoIcono: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nombrePlato,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (estado.etiqueta != null)
                      Text(
                        estado.etiqueta!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: estado.vendible
                              ? AppColors.naranja
                              : AppColors.error,
                        ),
                      ),
                  ],
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

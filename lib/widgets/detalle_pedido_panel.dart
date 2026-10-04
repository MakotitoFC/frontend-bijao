import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/incidencias_store.dart';
import '../data/insumos_store.dart';
import '../data/mesas_store.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../data/usuarios_store.dart';
import '../models/incidencia.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'app_toast.dart';
import 'boleta_pedido_dialog.dart';
import 'agregar_producto_dialog.dart';
import 'app_tag.dart';
import 'descuento_dialog.dart';
import 'editar_pedido_dialog.dart';
import 'boletas_pagadores_dialog.dart';
import 'pago_compartido_dialog.dart';
import 'pago_dialogs.dart';
import 'plato_del_dia_picker.dart';
import 'producto_opciones_dialog.dart';
import 'propina_dialog.dart';
import 'reportar_problema_dialog.dart';
import 'tupper_dialog.dart';

const _naranjaPago = Color(0xFFF07F13);
const _prefijoDescuento = 'Descuento: ';

String tituloPedido(Pedido p) {
  if (p.tipoPedido == 'delivery') return 'Delivery';
  return 'Mesa ${p.todasLasMesas.join(' + ')}';
}

String nombreMeseroDe(Pedido p) {
  for (final u in usuarios) {
    if (u.id == p.usuarioId) return u.nombre;
  }
  return '—';
}

// Color por `pedidos.estado`.
({Color color, String texto}) paletaEstadoPedido(String estado) {
  switch (estado) {
    case 'preparando':
      return (color: const Color(0xFFEF6C00), texto: 'Preparando');
    case 'listo':
      return (color: AppColors.primaryGreen, texto: 'Listo');
    case 'entregado':
      return (color: AppColors.primaryGreenDark, texto: 'Entregado');
    default:
      return (color: const Color(0xFFCA8A04), texto: 'Pendiente');
  }
}

// Píldora sólida con el estado del pedido.
class BadgeEstadoPedido extends StatelessWidget {
  final String estado;

  const BadgeEstadoPedido(this.estado, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = paletaEstadoPedido(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: p.color,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        p.texto,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// Sección derecha de Pedidos: detalle del pedido elegido (`pedidos` +
// `pedidos_detalle`) con Imprimir, Devolución, Pagar y Pago compartido.
class DetallePedidoPanel extends StatelessWidget {
  final Pedido pedido;
  final VoidCallback onCambio;
  final VoidCallback? onVolver;
  final bool esAdmin;

  const DetallePedidoPanel({
    super.key,
    required this.pedido,
    required this.onCambio,
    this.onVolver,
    this.esAdmin = false,
  });

  String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _metodoPago() {
    final metodos = <String>{
      for (final pago in pagos.where((x) => x.pedidoId == pedido.id))
        pago.medioPago.medioPago,
    };
    return metodos.isEmpty ? 'Sin pago' : metodos.join(', ');
  }

  String _descripcionLinea(PedidoLine l) {
    final partes = <String>[
      if (l.presentacion != null)
        '${l.presentacion!.unidad.unidadPresentacion} ${l.presentacion!.volumenMl}ml',
      ...l.modificadores.map((m) => m.nombre),
      if (l.promocion != null) l.promocion!.nombre,
    ];
    return partes.join(' · ');
  }

  // ---------- acciones ----------

  void _imprimir(BuildContext context) {
    marcarPedidoImpreso(pedido.id);
    showBlurDialog<void>(
      context: context,
      builder: (dialogContext) => BoletaPedidoDialog(
        pedido: pedido,
        mesero: nombreMeseroDe(pedido),
        titulo: tituloPedido(pedido),
        metodoPago: _metodoPago(),
        onImprimir: () {
          showAppToast(
            dialogContext,
            'Pedido #${pedido.numeroPedido} enviado a imprimir.',
            type: ToastType.success,
          );
          Navigator.of(dialogContext).pop();
        },
        onCerrar: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  Future<void> _devolucion(BuildContext context) async {
    final linea = await showBlurDialog<PedidoLine>(
      context: context,
      builder: (_) => _ElegirLineaDialog(pedido: pedido),
    );
    if (linea == null || !context.mounted) return;
    final resultado = await showBlurDialog<ReporteProblema>(
      context: context,
      builder: (_) => ReportarProblemaDialog(
        nombrePlato: linea.nombrePlato,
        precioLinea: linea.precioTotalLinea,
        pagadoLinea: montoPagadoDeLinea(linea.id),
        medioOriginalId: medioDeUltimoPago(pedido.id),
      ),
    );
    if (resultado == null || !context.mounted) return;
    final efecto = registrarIncidencia(
      pedido: pedido,
      linea: linea,
      reporte: resultado,
    );
    showAppToast(
      context,
      '${linea.nombrePlato}: ${etiquetaDeResolucion(resultado.resolucion)}. ${efecto.resumen}',
      type: resultado.resolucion == 'rechazado'
          ? ToastType.info
          : ToastType.success,
      titulo: 'Devolución',
    );
    onCambio();
  }

  Future<void> _pagar(BuildContext context, {required bool compartido}) async {
    if (compartido) {
      final r = await showBlurDialog<ResultadoPagoCompartido>(
        context: context,
        builder: (_) =>
            PagoCompartidoDialog(pedido: pedido, titulo: tituloPedido(pedido)),
      );
      if (r == null) return;
      // Las boletas se muestran antes de refrescar: si el pedido quedó
      // pagado, este panel deja de existir.
      if (r.boletasIndividuales && context.mounted) {
        await showBlurDialog<void>(
          context: context,
          builder: (_) =>
              BoletasPagadoresDialog(pedido: pedido, boletas: r.boletas),
        );
      }
      onCambio();
      return;
    }
    final pagado = await showBlurDialog<bool>(
      context: context,
      builder: (_) =>
          PagarPedidoDialog(pedido: pedido, titulo: tituloPedido(pedido)),
    );
    if (pagado == true) onCambio();
  }

  Future<void> _cancelar(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cancelar pedido #${pedido.numeroPedido}'),
        content: Text(
          '¿Seguro que deseas cancelar este pedido de ${tituloPedido(pedido)}? '
          'Se liberarán sus mesas y desaparecerá de la cola y de cocina.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;
    actualizarEstadoPedido(pedido.id, 'cancelado');
    for (final n in pedido.todasLasMesas) {
      if (n == 0) continue;
      actualizarEstadoMesa(n, 'libre');
      separarMesas(n);
    }
    onCambio();
    showAppToast(
      context,
      'El pedido #${pedido.numeroPedido} se canceló.',
      type: ToastType.info,
      titulo: 'Pedido cancelado',
    );
  }

  // Un producto con cobros registrados ya no se puede editar ni quitar.
  bool _bloqueadaPorPago(BuildContext context, PedidoLine l) {
    if (montoPagadoDeLinea(l.id).abs() < 0.001) return false;
    showAppToast(
      context,
      'Este producto ya tiene pagos registrados.',
      type: ToastType.error,
    );
    return true;
  }

  void _quitarLinea(BuildContext context, PedidoLine l) {
    if (_bloqueadaPorPago(context, l)) return;
    if (esLineaDeProducto(l)) {
      final productos = (detallesPorPedido[pedido.id] ?? []).where(
        esLineaDeProducto,
      );
      if (productos.length <= 1) {
        showAppToast(
          context,
          'El pedido necesita al menos un producto. Para anularlo, cancélalo.',
          type: ToastType.error,
        );
        return;
      }
    }
    quitarLineaDePedido(pedido.id, l.id);
    onCambio();
    showAppToast(
      context,
      '"${l.nombrePlato}" se quitó del pedido.',
      type: ToastType.info,
    );
  }

  void _cambiarCantidad(BuildContext context, PedidoLine l, int delta) {
    if (_bloqueadaPorPago(context, l)) return;
    cambiarCantidadLineaDePedido(pedido.id, l.id, delta);
    onCambio();
  }

  Future<void> _editarNota(BuildContext context, PedidoLine l) async {
    final nota = await showBlurDialog<String>(
      context: context,
      builder: (_) =>
          _NotaDialog(nombrePlato: l.nombrePlato, inicial: l.comentario),
    );
    if (nota == null) return;
    actualizarNotaLinea(pedido.id, l.id, nota.isEmpty ? null : nota);
    onCambio();
  }

  Future<void> _agregarAjuste(BuildContext context) async {
    final lineas = detallesPorPedido[pedido.id] ?? [];
    final base = lineas
        .where(esLineaDeProducto)
        .fold(0.0, (s, l) => s + l.precioTotalLinea);
    final aplicados = {
      for (final l in lineas)
        if (l.cartaId == cartaIdAjuste &&
            l.nombrePlato.startsWith(_prefijoDescuento))
          l.nombrePlato.substring(_prefijoDescuento.length),
    };
    final r = await showBlurDialog<DescuentoConfigurado>(
      context: context,
      builder: (_) => DescuentoDialog(base: base, aplicados: aplicados),
    );
    if (r == null || !context.mounted) return;
    final nombre = '$_prefijoDescuento${r.nombre}';
    if (r.quitar) {
      lineas.removeWhere(
        (l) => l.cartaId == cartaIdAjuste && l.nombrePlato == nombre,
      );
      onCambio();
      return;
    }
    final monto = r.esPorcentaje ? base * r.monto / 100 : r.monto;
    if (monto > saldoPendienteDePedido(pedido.id) + 0.01) {
      showAppToast(
        context,
        'El descuento no puede superar el saldo del pedido.',
        type: ToastType.error,
      );
      return;
    }
    agregarAjusteAPedido(pedido.id, nombre, monto);
    onCambio();
  }

  Future<void> _editar(BuildContext context) async {
    final guardado = await showBlurDialog<bool>(
      context: context,
      builder: (_) => EditarPedidoDialog(pedido: pedido),
    );
    if (guardado != true) return;
    onCambio();
    if (context.mounted) {
      showAppToast(
        context,
        'Los datos del pedido #${pedido.numeroPedido} se actualizaron.',
        type: ToastType.success,
        titulo: 'Pedido editado',
      );
    }
  }

  Future<void> _agregarProducto(BuildContext context) async {
    final agregado = await showBlurDialog<bool>(
      context: context,
      builder: (_) => AgregarProductoDialog(pedido: pedido, esAdmin: esAdmin),
    );
    if (agregado != true) return;
    onCambio();
    if (context.mounted) {
      showAppToast(
        context,
        'Producto agregado al pedido #${pedido.numeroPedido}.',
        type: ToastType.success,
      );
    }
  }

  // Propina para el mesero: se agrega al card de totales y se puede editar.
  Future<void> _editarPropina(BuildContext context) async {
    final lineas = detallesPorPedido[pedido.id] ?? [];
    if (lineas
        .where(esLineaPropina)
        .any((l) => montoPagadoDeLinea(l.id).abs() > 0.001)) {
      showAppToast(
        context,
        'La propina ya tiene pagos registrados.',
        type: ToastType.error,
      );
      return;
    }
    final base = lineas
        .where(esLineaDeProducto)
        .fold(0.0, (s, l) => s + l.precioTotalLinea);
    final monto = await showBlurDialog<double>(
      context: context,
      builder: (_) =>
          PropinaDialog(base: base, actual: propinaDePedido(pedido.id)),
    );
    if (monto == null) return;
    establecerPropinaPedido(pedido.id, monto);
    onCambio();
  }

  // Tupper para llevar: grande o mediano, con precio editable.
  Future<void> _editarTupper(BuildContext context) async {
    final lineas = detallesPorPedido[pedido.id] ?? [];
    if (lineas
        .where(esLineaTupper)
        .any((l) => montoPagadoDeLinea(l.id).abs() > 0.001)) {
      showAppToast(
        context,
        'El tupper ya tiene pagos registrados.',
        type: ToastType.error,
      );
      return;
    }
    final actual = tupperCantidades(pedido.id);
    final r = await showBlurDialog<TupperConfigurado>(
      context: context,
      builder: (_) =>
          TupperDialog(grande: actual.grande, mediano: actual.mediano),
    );
    if (r == null) return;
    establecerTupperPedido(
      pedido.id,
      grande: r.grande,
      precioGrande: r.precioGrande,
      mediano: r.mediano,
      precioMediano: r.precioMediano,
    );
    onCambio();
  }

  // Tag naranja: agrega al pedido el plato del día registrado en Productos.
  Future<void> _platoDelDia(BuildContext context) async {
    final item = await elegirPlatoDelDia(context);
    if (item == null || !context.mounted) return;
    final r = await showBlurDialog<ProductoConfigurado>(
      context: context,
      builder: (_) => ProductoOpcionesDialog(
        item: item,
        esAdmin: esAdmin,
        acento: AppColors.platoDelDia,
      ),
    );
    if (r == null) return;
    final linea = PedidoLine(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      cartaId: item.id,
      nombrePlato: item.nombrePlato,
      cantidad: r.cantidad,
      modificadores: r.modificadores,
      presentacion: r.presentacion,
      promocion: null,
      comentario: r.comentario,
      precioUnitario: r.precioUnitario,
      descuentoAplicado: 0,
      precioTotalLinea: r.precioUnitario * r.cantidad,
    );
    agregarLineaAPedido(pedido.id, linea);
    registrarConsumoAutomaticoDeLinea(linea);
    onCambio();
    if (context.mounted) {
      showAppToast(
        context,
        '"${item.nombrePlato}" se agregó al pedido #${pedido.numeroPedido}.',
        type: ToastType.success,
        titulo: 'Plato del día',
      );
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final detalles = detallesPorPedido[pedido.id] ?? [];
    final productos = detalles.where(esLineaDeProducto).toList();
    final subtotal = productos.fold(
      0.0,
      (s, l) => s + l.precioTotalLinea + l.descuentoAplicado,
    );
    final descProductos = productos.fold(
      0.0,
      (s, l) => s + l.descuentoAplicado,
    );
    double sumaAjustes(String prefijo) => -detalles
        .where(
          (l) =>
              l.cartaId == cartaIdAjuste && l.nombrePlato.startsWith(prefijo),
        )
        .fold(0.0, (s, l) => s + l.precioTotalLinea);
    final descExtra = sumaAjustes(_prefijoDescuento);
    final tupper = tupperDePedido(pedido.id);
    final propina = propinaDePedido(pedido.id);
    final devoluciones = detalles
        .where(esAjusteDeDevolucion)
        .fold(0.0, (s, l) => s + l.precioTotalLinea);
    final cargo = detalles
        .where((l) => l.cartaId == cartaIdCargoDelivery)
        .fold(0.0, (s, l) => s + l.precioTotalLinea);
    final total = totalDePedido(pedido.id);
    final saldo = saldoPendienteDePedido(pedido.id);
    final pagado = total - saldo;
    final puedePagar = saldo > 0.01;

    // En pantallas bajas (mobile) los totales y botones van dentro del scroll,
    // para que los productos no queden aplastados.
    final pieEnLista = MediaQuery.sizeOf(context).height < 760;
    final pieTotales = Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          _filaTotal('Subtotal', subtotal),
          if (cargo > 0) _filaTotal('Cargo por delivery', cargo),
          if (descProductos > 0)
            _filaTotal('Descuento de productos', -descProductos),
          _filaTotal(
            'Descuento extra',
            -descExtra,
            onEditar: () => _agregarAjuste(context),
          ),
          if (devoluciones.abs() > 0.001)
            _filaTotal('Ajustes por devolución', devoluciones),
          if (propina > 0)
            _filaTotal(
              'Propina',
              propina,
              onEditar: () => _editarPropina(context),
            ),
          if (tupper > 0)
            _filaTotal(
              'Tupper',
              tupper,
              onEditar: () => _editarTupper(context),
            ),
          if (pagado > 0.01) _filaTotal('Pagado', pagado),
          if (pagado > 0.01 && saldo > 0.01)
            _filaTotal('Saldo pendiente', saldo, color: AppColors.mesaOcupada),
          const SizedBox(height: 4),
          _filaTotal('Total', total, fuerte: true),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              runSpacing: 8,
              children: [
                AppTag(
                  etiqueta: 'Plato del día',
                  icono: LucideIcons.chefHat,
                  activo: false,
                  color: AppColors.platoDelDia,
                  onTap: () => _platoDelDia(context),
                ),
                AppTag(
                  etiqueta: 'Propina',
                  icono: LucideIcons.handCoins,
                  activo: false,
                  color: AppColors.platoDelDia,
                  onTap: () => _editarPropina(context),
                ),
                AppTag(
                  etiqueta: 'Tupper',
                  icono: LucideIcons.package,
                  activo: false,
                  color: Colors.black87,
                  colorBorde: Colors.grey.shade300,
                  onTap: () => _editarTupper(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final pieBotones = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: _botones(context, productos.isNotEmpty, puedePagar),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cabecera(context),
          Divider(height: 1, color: Colors.grey.shade200),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              children: [
                if (detalles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Este pedido aún no tiene ítems.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  )
                else
                  for (final l in detalles) _filaLinea(context, l),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _agregarProducto(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Agregar producto'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGreenDark,
                        side: const BorderSide(color: AppColors.primaryGreen),
                      ),
                    ),
                  ),
                ),
                if (pieEnLista) ...[
                  Divider(height: 24, color: Colors.grey.shade200),
                  pieTotales,
                  pieBotones,
                ],
              ],
            ),
          ),
          if (!pieEnLista) ...[
            Divider(height: 1, color: Colors.grey.shade200),
            pieTotales,
            pieBotones,
          ],
        ],
      ),
    );
  }

  Widget _cabecera(BuildContext context) {
    final cliente = pedido.clienteNombre;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onVolver != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onVolver,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Icon(Icons.arrow_back, size: 17),
                ),
              ),
            ),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              LucideIcons.receipt,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pedido #${pedido.numeroPedido}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${tituloPedido(pedido)} · ${_hora(pedido.fechaPedido)} · ${nombreMeseroDe(pedido)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (cliente != null)
                  Text(
                    cliente,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          BadgeEstadoPedido(pedido.estado),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Editar pedido',
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _editar(context),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                ),
                child: Icon(
                  LucideIcons.pencil,
                  size: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _botonCirculoRojo(
            tooltip: 'Cancelar pedido',
            onTap: () => _cancelar(context),
          ),
        ],
      ),
    );
  }

  Widget _botonCirculoRojo({
    required String tooltip,
    required VoidCallback onTap,
    double size = 26,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.error.withValues(alpha: 0.1),
          ),
          child: Icon(
            LucideIcons.trash2,
            size: size * 0.5,
            color: AppColors.error,
          ),
        ),
      ),
    );
  }

  // Línea del pedido: checklist al extremo izquierdo, datos y acciones.
  Widget _filaLinea(BuildContext context, PedidoLine l) {
    final esProducto = esLineaDeProducto(l);
    final esCargo = l.cartaId == cartaIdCargoDelivery;
    final desc = _descripcionLinea(l);
    final pagadoLinea = montoPagadoDeLinea(l.id);
    final incidencia = l.estado == 'incidencia'
        ? incidenciaDeLinea(l.id)
        : null;
    final entregado = esProducto && lineasEntregadas.contains(l.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (esProducto)
            Tooltip(
              message: entregado
                  ? 'Marcar como pendiente de entrega'
                  : 'Marcar como entregado',
              child: SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: entregado,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  onChanged: (_) {
                    alternarLineaEntregada(l.id);
                    onCambio();
                  },
                  activeColor: AppColors.primaryGreen,
                ),
              ),
            )
          else
            const SizedBox(width: 4),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        l.nombrePlato,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: entregado
                              ? TextDecoration.lineThrough
                              : null,
                          color: entregado
                              ? Colors.grey.shade500
                              : Colors.black87,
                        ),
                      ),
                    ),
                    if (esProducto) ...[
                      Tooltip(
                        message: 'Imprimir comanda de este producto',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => showAppToast(
                            context,
                            'Comanda de "${l.nombrePlato}" enviada a imprimir.',
                            type: ToastType.success,
                          ),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Icon(
                              LucideIcons.printer,
                              size: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (!esCargo && !esAjusteDeDevolucion(l))
                      _botonCirculoRojo(
                        tooltip: esProducto
                            ? 'Quitar producto'
                            : (esLineaPropina(l)
                                  ? 'Quitar propina'
                                  : esLineaTupper(l)
                                  ? 'Quitar tupper'
                                  : 'Quitar descuento'),
                        onTap: () => _quitarLinea(context, l),
                      ),
                  ],
                ),
                if (desc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                if (l.comentario != null && esProducto)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l.comentario!,
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                if (esProducto)
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreenDark,
                      ),
                      children: [
                        TextSpan(
                          text:
                              'S/ ${l.precioUnitario.toStringAsFixed(2)} × ${l.cantidad} = ',
                        ),
                        TextSpan(
                          text: 'S/ ${l.precioTotalLinea.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  )
                else if (esLineaTupper(l))
                  Text(
                    'S/ ${l.precioUnitario.toStringAsFixed(2)} × ${l.cantidad} = S/ ${l.precioTotalLinea.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryGreenDark,
                    ),
                  )
                else
                  Text(
                    '${l.precioTotalLinea < 0 ? '-' : ''}S/ ${l.precioTotalLinea.abs().toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryGreenDark,
                    ),
                  ),
                if (pagadoLinea > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Pagado S/ ${pagadoLinea.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                if (incidencia != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _tagIncidencia(incidencia),
                  ),
                if (esProducto)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        _stepper(context, l),
                        const Spacer(),
                        _botonNota(context, l),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // − n + : cambia la cantidad de la línea.
  Widget _stepper(BuildContext context, PedidoLine l) {
    Widget boton(IconData icono, VoidCallback? onTap) => InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap == null
              ? Colors.grey.shade100
              : AppColors.primaryGreen.withValues(alpha: 0.12),
        ),
        child: Icon(
          icono,
          size: 14,
          color: onTap == null
              ? Colors.grey.shade400
              : AppColors.primaryGreenDark,
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        boton(
          Icons.remove,
          l.cantidad > 1 ? () => _cambiarCantidad(context, l, -1) : null,
        ),
        SizedBox(
          width: 28,
          child: Text(
            '${l.cantidad}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
        boton(Icons.add, () => _cambiarCantidad(context, l, 1)),
      ],
    );
  }

  Widget _botonNota(BuildContext context, PedidoLine l) {
    final tieneNota = l.comentario != null;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _editarNota(context, l),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.notebookPen,
              size: 12,
              color: Colors.grey.shade700,
            ),
            const SizedBox(width: 5),
            Text(
              tieneNota ? 'Editar nota' : 'Agregar nota',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagIncidencia(Incidencia i) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE4EC),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Devolución: ${i.etiquetaResolucion}',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFFC2185B),
        ),
      ),
    );
  }

  // Fila de totales; con [onEditar] muestra el lápiz para editar el monto.
  Widget _filaTotal(
    String etiqueta,
    double monto, {
    bool fuerte = false,
    Color? color,
    VoidCallback? onEditar,
  }) {
    final estilo = TextStyle(
      fontSize: fuerte ? 16 : 13,
      fontWeight: fuerte ? FontWeight.w800 : FontWeight.w500,
      color: color ?? (fuerte ? Colors.black87 : Colors.grey.shade700),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: estilo)),
          if (onEditar != null)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onEditar,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  LucideIcons.pencil,
                  size: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          const SizedBox(width: 6),
          Text(
            '${monto < -0.004 ? '-' : ''}S/ ${monto.abs().toStringAsFixed(2)}',
            style: estilo,
          ),
        ],
      ),
    );
  }

  // Imprimir (oscuro) + Devolución, y debajo Pagar (naranja) + Pago compartido (verde).
  Widget _botones(BuildContext context, bool hayProductos, bool puedePagar) {
    const texto = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                onPressed: () => _imprimir(context),
                icon: const Icon(LucideIcons.printer, size: 16),
                label: const Text('Imprimir', style: texto),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navbar,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: hayProductos && pedido.tipoPedido != 'delivery'
                    ? () => _devolucion(context)
                    : null,
                icon: const Icon(LucideIcons.undo2, size: 15),
                label: const Text(
                  'Devolución',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: texto,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: puedePagar
                    ? () => _pagar(context, compartido: false)
                    : null,
                icon: const Icon(LucideIcons.banknote, size: 16),
                label: const Text('Pagar', style: texto),
                style: FilledButton.styleFrom(backgroundColor: _naranjaPago),
              ),
            ),
            // El pago compartido no aplica a delivery: Pagar ocupa todo el ancho.
            if (pedido.tipoPedido != 'delivery') ...[
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: puedePagar
                      ? () => _pagar(context, compartido: true)
                      : null,
                  icon: const Icon(LucideIcons.users, size: 16),
                  label: const Text(
                    'Pago compartido',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: texto,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// Nota de un producto del pedido; devuelve el texto ('' = quitar la nota).
class _NotaDialog extends StatefulWidget {
  final String nombrePlato;
  final String? inicial;

  const _NotaDialog({required this.nombrePlato, this.inicial});

  @override
  State<_NotaDialog> createState() => _NotaDialogState();
}

class _NotaDialogState extends State<_NotaDialog> {
  late final _controller = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final ancho = MediaQuery.sizeOf(context).width;
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: esMobile ? ancho : 400,
          maxWidth: esMobile ? ancho : 400,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nota del producto',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.nombrePlato,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Ej. sin cebolla, poco picante',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_controller.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
                child: const Text(
                  'Guardar nota',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Elige qué producto del pedido se devuelve (los ya devueltos quedan marcados).
class _ElegirLineaDialog extends StatelessWidget {
  final Pedido pedido;

  const _ElegirLineaDialog({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final ancho = MediaQuery.sizeOf(context).width;
    final lineas = (detallesPorPedido[pedido.id] ?? [])
        .where(esLineaDeProducto)
        .toList();
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: esMobile ? ancho : 400,
          maxWidth: esMobile ? ancho : 400,
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, esMobile ? 28 : 22, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '¿Qué producto se devuelve?',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final l in lineas)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: l.estado == 'incidencia'
                              ? null
                              : () => Navigator.of(context).pop(l),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${l.cantidad}x',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryGreenDark,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l.nombrePlato,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: l.estado == 'incidencia'
                                          ? Colors.grey.shade400
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (l.estado == 'incidencia')
                                  Text(
                                    'Ya devuelto',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

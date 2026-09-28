import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/mesas_store.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../data/usuarios_store.dart';
import '../models/mesa.dart';
import '../models/mock_user.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/cronometro_pedido.dart';
import '../widgets/elegir_tipo_pedido_dialog.dart';
import '../widgets/nuevo_pedido_dialog.dart';
import '../widgets/panel_pedido_mesa.dart';
import '../widgets/tabs_desplazables.dart';

// Vista de Pedidos: cola de pedidos activos (`pedidos`, `pedidos_detalle`,
// `usuarios`, `mesas`) filtrable por estado, más "Nuevo Pedido".
class PedidosScreen extends StatefulWidget {
  final MockUser usuario;

  const PedidosScreen({super.key, required this.usuario});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  bool _colaEnLista = false; // false = grilla (tarjetas), true = lista (tabla)
  String? _estadoFiltro; // null = Todos
  bool _armandoPedido = false; // true = la vista muestra "Nuevo pedido"
  String? _tipoNuevoPedido; // 'mesa' | 'delivery', elegido en el modal

  // ---------- datos ----------

  List<Pedido> get _cola {
    final base = pedidos.where(
      (p) =>
          p.estado != 'pagado' &&
          p.estado != 'cancelado' &&
          p.estado != 'anulado',
    );
    if (_estadoFiltro == null) return base.toList();
    return base.where((p) => p.estado == _estadoFiltro).toList();
  }

  String _tituloPedido(Pedido p) {
    if (p.tipoPedido == 'delivery') return 'Delivery';
    if (p.tipoPedido == 'llevar') return 'Para llevar';
    final mesasP = p.todasLasMesas;
    return 'Mesa ${mesasP.join(' + ')}';
  }

  int _itemsDe(Pedido p) => (detallesPorPedido[p.id] ?? [])
      .where((l) => l.cartaId != cartaIdCargoDelivery && l.cartaId != cartaIdAjuste)
      .fold(0, (s, l) => s + l.cantidad);

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}, '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // ---------- acciones ----------

  // "Nuevo Pedido" abre el modal de elegir tipo; luego arma el pedido inline.
  Future<void> _nuevoPedido() async {
    final tipo = await showBlurDialog<String>(
      context: context,
      builder: (_) => const ElegirTipoPedidoDialog(),
    );
    if (tipo == null || !mounted) return;
    setState(() {
      _tipoNuevoPedido = tipo;
      _armandoPedido = true;
    });
  }

  void _terminarNuevoPedido(bool creado) {
    setState(() => _armandoPedido = false);
  }

  Future<void> _abrirPanel(Mesa mesa) async {
    await showBlurDialog<void>(
      context: context,
      builder: (dialogContext) => PanelPedidoMesa(
        key: ValueKey('panel-${mesa.numero}'),
        mesa: mesa,
        usuario: widget.usuario,
        onCerrar: () => Navigator.of(dialogContext).pop(),
        onCambio: () => setState(() {}),
      ),
    );
    if (mounted) setState(() {});
  }

  void _abrirPedido(Pedido p) {
    final mesa = p.mesaNumero == 0
        ? const Mesa(id: 'delivery', numero: 0, estado: 'ocupada')
        : mesas.firstWhere(
            (m) => m.numero == p.mesaNumero,
            orElse: () => Mesa(
              id: 'm${p.mesaNumero}',
              numero: p.mesaNumero,
              estado: 'ocupada',
            ),
          );
    _abrirPanel(mesa);
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _armandoPedido
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: NuevoPedidoDialog(
                  usuario: widget.usuario,
                  tipo: _tipoNuevoPedido!,
                  onTerminar: _terminarNuevoPedido,
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _colaPedidos(),
              ),
      ),
    );
  }

  // --- cola de pedidos ---

  Widget _colaPedidos() {
    final cola = _cola;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _filtroEstado(),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _cabeceraCola(),
              const SizedBox(height: 12),
              if (cola.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      'Sin pedidos activos',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ),
                )
              else if (_colaEnLista)
                _tablaPedidos(cola)
              else
                TabsDesplazables(
                  child: Row(
                    children: [
                      for (final p in cola) ...[
                        _tarjetaPedido(p),
                        const SizedBox(width: 12),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Cantidad de pedidos activos por estado (sin aplicar el filtro actual).
  int _contarEstado(String? estado) {
    final base = pedidos.where(
      (p) =>
          p.estado != 'pagado' &&
          p.estado != 'cancelado' &&
          p.estado != 'anulado',
    );
    if (estado == null) return base.length;
    return base.where((p) => p.estado == estado).length;
  }

  // Tabs de estado (`pedidos.estado`), cada una con su cantidad.
  Widget _filtroEstado() {
    const opciones = <(String?, String)>[
      (null, 'Todos'),
      ('pendiente', 'Pendiente'),
      ('preparando', 'Preparando'),
      ('listo', 'Listo'),
      ('entregado', 'Entregado'),
    ];
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (final o in opciones) _pastillaEstado(o.$1, o.$2)],
        ),
      ),
    );
  }

  Widget _pastillaEstado(String? valor, String etiqueta) {
    final activo = _estadoFiltro == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _estadoFiltro = valor),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: activo ? AppColors.primaryGreen : Colors.grey.shade300,
              width: activo ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: activo
                      ? AppColors.primaryGreenDark
                      : Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: activo ? AppColors.primaryGreen : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_contarEstado(valor)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: activo ? Colors.white : Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botonNuevoPedido() {
    return FilledButton.icon(
      onPressed: _nuevoPedido,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.add, size: 18),
      label: const Text(
        'Nuevo Pedido',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  // Título + cantidad y las acciones (vista/Nuevo Pedido).
  Widget _cabeceraCola() {
    final titulo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Cola de pedidos',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Text(
          '${_cola.length}',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
      ],
    );
    final acciones = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _selectorVista(),
        const SizedBox(width: 10),
        _botonNuevoPedido(),
      ],
    );
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [titulo, const SizedBox(height: 10), acciones],
          );
        }
        return Row(children: [titulo, const Spacer(), acciones]);
      },
    );
  }

  Widget _selectorVista() {
    Widget opcion(IconData icono, String tooltip, bool lista) {
      final activo = _colaEnLista == lista;
      return Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _colaEnLista = lista),
          child: Container(
            width: 32,
            height: 30,
            decoration: BoxDecoration(
              color: activo ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: activo
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icono,
              size: 16,
              color: activo ? AppColors.primaryGreen : Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          opcion(LucideIcons.layoutGrid, 'Vista en grilla', false),
          opcion(LucideIcons.list, 'Vista en lista', true),
        ],
      ),
    );
  }

  String _nombreMesero(Pedido p) {
    for (final u in usuarios) {
      if (u.id == p.usuarioId) return u.nombre;
    }
    return '—';
  }

  // Color por `pedidos.estado`.
  ({Color color, String texto}) _paletaEstado(String estado) {
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

  Widget _tarjetaPedido(Pedido p) {
    final tenue = Colors.grey.shade600;
    final lineas = (detallesPorPedido[p.id] ?? [])
        .where((l) => l.cartaId != cartaIdCargoDelivery && l.cartaId != cartaIdAjuste)
        .toList();
    const maxItems = 3;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _abrirPedido(p),
      child: Container(
        width: 240,
        height: 300,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    LucideIcons.receipt,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '#${p.numeroPedido}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                _badgeEstado(p.estado),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _tituloPedido(p),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _fecha(p.fechaPedido),
              style: TextStyle(fontSize: 11, color: tenue),
            ),
            if (p.notas != null) ...[
              const SizedBox(height: 4),
              Text(
                p.notas!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 8),
            for (final l in lineas.take(maxItems)) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'x${l.cantidad}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreenDark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.nombrePlato,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          if (l.comentario != null)
                            Text(
                              l.comentario!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (lineas.length > maxItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '+${lineas.length - maxItems} productos más',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            const Spacer(),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'S/ ${totalDePedido(p.id).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                CronometroPedido(pedido: p),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tablaPedidos(List<Pedido> cola) {
    const estiloCabecera = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Color(0xFF6B7280),
    );
    const estiloCelda = TextStyle(fontSize: 12, color: Colors.black87);
    DataColumn col(String t) => DataColumn(
      label: Center(child: Text(t, style: estiloCabecera)),
    );
    DataCell celda(Widget w) => DataCell(Center(child: w));
    DataCell texto(String t, {bool fuerte = false}) => celda(
      Text(
        t,
        style: fuerte
            ? estiloCelda.copyWith(fontWeight: FontWeight.w600)
            : estiloCelda,
      ),
    );
    // Tabla centrada, con scroll horizontal si no entra.
    return LayoutBuilder(
      builder: (context, c) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: c.maxWidth),
              child: Center(
                child: DataTable(
                  showCheckboxColumn: false,
                  headingRowHeight: 38,
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 44,
                  columnSpacing: 28,
                  horizontalMargin: 8,
                  dividerThickness: 0.6,
                  columns: [
                    col('Pedido'),
                    col('Cliente'),
                    col('Tipo'),
                    col('Mesero'),
                    col('Productos'),
                    col('Total'),
                    col('Pago'),
                    col('Tiempo'),
                    col('Estado'),
                    col('Acciones'),
                  ],
                  rows: [
                    for (final p in cola)
                      DataRow(
                        onSelectChanged: (_) => _abrirPedido(p),
                        cells: [
                          texto('#${p.numeroPedido}'),
                          texto(p.clienteNombre ?? '—', fuerte: true),
                          texto(_tituloPedido(p)),
                          texto(_nombreMesero(p)),
                          texto('${_itemsDe(p)}'),
                          texto('S/ ${totalDePedido(p.id).toStringAsFixed(2)}'),
                          texto(_metodoPago(p)),
                          celda(CronometroPedido(pedido: p)),
                          celda(_badgeEstado(p.estado)),
                          celda(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _accion(
                                  LucideIcons.receipt,
                                  'Generar boleta',
                                  Colors.grey.shade700,
                                  () => _generarBoleta(p),
                                ),
                                const SizedBox(width: 4),
                                _accion(
                                  LucideIcons.circleX,
                                  'Cancelar pedido',
                                  AppColors.error,
                                  () => _cancelarPedido(p),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Método(s) de pago de los cobros ya registrados del pedido.
  String _metodoPago(Pedido p) {
    final metodos = <String>{
      for (final pago in pagos.where((x) => x.pedidoId == p.id))
        pago.medioPago.medioPago,
    };
    return metodos.isEmpty ? 'Sin pago' : metodos.join(', ');
  }

  Widget _accion(
    IconData icono,
    String tooltip,
    Color color,
    VoidCallback onTap,
  ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Icon(icono, size: 15, color: color),
        ),
      ),
    );
  }

  void _generarBoleta(Pedido p) {
    showBlurDialog<void>(
      context: context,
      builder: (dialogContext) => _BoletaDialog(
        pedido: p,
        mesero: _nombreMesero(p),
        titulo: _tituloPedido(p),
        metodoPago: _metodoPago(p),
        onCerrar: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  Future<void> _cancelarPedido(Pedido p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cancelar pedido #${p.numeroPedido}'),
        content: Text(
          '¿Seguro que deseas cancelar este pedido de ${_tituloPedido(p)}? '
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
    if (confirmar != true || !mounted) return;
    setState(() {
      actualizarEstadoPedido(p.id, 'cancelado');
      for (final n in p.todasLasMesas) {
        if (n == 0) continue;
        actualizarEstadoMesa(n, 'libre');
        separarMesas(n);
      }
    });
    showAppToast(
      context,
      'El pedido #${p.numeroPedido} se canceló.',
      type: ToastType.info,
      titulo: 'Pedido cancelado',
    );
  }

  // Píldora sólida (extremos 100% redondeados) con texto blanco.
  Widget _badgeEstado(String estado) {
    final p = _paletaEstado(estado);
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

// Boleta imprimible del pedido (`pedidos`, `pedidos_detalle`, `usuarios`, `pagos`).
class _BoletaDialog extends StatelessWidget {
  final Pedido pedido;
  final String mesero;
  final String titulo;
  final String metodoPago;
  final VoidCallback onCerrar;

  const _BoletaDialog({
    required this.pedido,
    required this.mesero,
    required this.titulo,
    required this.metodoPago,
    required this.onCerrar,
  });

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final ancho = MediaQuery.sizeOf(context).width;
    final lineas = detallesPorPedido[pedido.id] ?? [];
    final total = totalDePedido(pedido.id);
    const gris = TextStyle(fontSize: 12, color: Color(0xFF6B7280));
    Widget fila(String a, String b, {TextStyle? estilo}) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(a, style: estilo ?? gris),
        Flexible(
          child: Text(
            b,
            textAlign: TextAlign.end,
            style: (estilo ?? gris).copyWith(color: Colors.black87),
          ),
        ),
      ],
    );
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: esMobile
            ? BoxConstraints(minWidth: ancho, maxWidth: ancho)
            : const BoxConstraints(minWidth: 380, maxWidth: 380),
        child: Padding(
          padding: EdgeInsets.fromLTRB(28, esMobile ? 32 : 24, 28, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/logo_bijao.png',
                    height: 44,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Boleta',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Center(
                  child: Text('Pedido #${pedido.numeroPedido}', style: gris),
                ),
                const SizedBox(height: 14),
                fila('Fecha', _fecha(pedido.fechaPedido)),
                const SizedBox(height: 4),
                fila('Cliente', pedido.clienteNombre ?? '—'),
                const SizedBox(height: 4),
                fila('Atendido por', mesero),
                const SizedBox(height: 4),
                fila('Tipo', titulo),
                const SizedBox(height: 14),
                Divider(height: 1, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                for (final l in lineas) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${l.cantidad}x',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.nombrePlato,
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (l.modificadores.isNotEmpty)
                              Text(
                                l.modificadores.map((m) => m.nombre).join(', '),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        'S/ ${l.precioTotalLinea.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Divider(height: 1, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                fila(
                  'Total',
                  'S/ ${total.toStringAsFixed(2)}',
                  estilo: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                fila('Pago', metodoPago),
                const SizedBox(height: 16),
                const Center(
                  child: Text('¡Gracias por su visita!', style: gris),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: onCerrar,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

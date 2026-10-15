import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/mesas_por_liberar_store.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../models/app_role.dart';
import '../models/mesa.dart';
import '../models/usuario.dart';
import '../models/pedido.dart';
import '../services/catalog_service.dart';
import '../services/eventos_service.dart';
import '../services/pedido_mozo_service.dart';
import '../services/pedido_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../widgets/app_tag.dart';
import '../widgets/app_toast.dart';
import '../widgets/cronometro_pedido.dart';
import '../widgets/detalle_pedido_panel.dart';
import '../widgets/elegir_tipo_pedido_dialog.dart';
import '../widgets/nuevo_pedido_dialog.dart';
import '../widgets/tabs_desplazables.dart';

// Vista de Pedidos en dos secciones: cola de pedidos activos (`pedidos`,
// `pedidos_detalle`) a la izquierda y detalle del pedido elegido a la derecha.
class PedidosScreen extends StatefulWidget {
  final Usuario usuario;

  const PedidosScreen({super.key, required this.usuario});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  static const _anchoDetalle = 390.0;
  static const _anchoMinDosSecciones = 900.0;

  String? _estadoFiltro; // null = Todos
  String? _seleccionId; // pedido mostrado en el detalle
  bool _armandoPedido = false; // true = la vista muestra "Nuevo pedido"
  String? _tipoNuevoPedido; // 'mesa' | 'delivery', elegido en el modal
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    cargarMesasPorLiberar().then((_) {
      if (mounted) setState(() {});
    });
    _cargar();
    EventosService.instance.revision.addListener(_alCambiarEnVivo);
    // Con la conexión en vivo activa, la consulta periódica es solo un respaldo
    // (cada 32 s); sin ella, cada 4 s.
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (EventosService.instance.conectado.value && ++_ciclos % 8 != 0) return;
      _cargar();
    });
  }

  int _ciclos = 0;

  void _alCambiarEnVivo() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    EventosService.instance.revision.removeListener(_alCambiarEnVivo);
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    await PedidoService.instance.cargarPedidos();
    // Para saber qué mesas siguen ocupadas (franja "Mesas por liberar").
    if (PedidoMozoService.instance.activo) {
      await CatalogService.instance.cargarMesas();
    }
    if (mounted) setState(() {});
  }

  Future<void> _liberarMesa(Mesa mesa) async {
    try {
      await PedidoService.instance.liberarMesa(mesa.id, mesa.numero);
      quitarMesaPorLiberar(mesa.id);
      if (!mounted) return;
      setState(() {});
      showAppToast(
        context,
        'Mesa ${mesa.numero} liberada.',
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'No se pudo liberar la mesa ${mesa.numero}: '
        '${e.toString().replaceFirst('Exception: ', '')}',
        type: ToastType.error,
      );
    }
  }

  // Mesas que el mozo debe liberar: el pago no las libera, las libera él cuando
  // los clientes se retiran. Dos grupos: las que se vio cobrar y las que están
  // ocupadas sin ningún pedido abierto (por ejemplo, si se cobró con la app
  // cerrada).
  Widget _mesasPorLiberar() {
    if (!PedidoMozoService.instance.activo) return const SizedBox.shrink();
    final cobradas = mesasPorLiberar();
    // Solo el administrador ve todos los pedidos de la sede: el mozo solo ve los
    // suyos y creería libre una mesa que tiene un pedido de otro mozo.
    final sinPedido = _esAdmin ? mesasOcupadasSinPedido() : const <Mesa>[];
    if (cobradas.isEmpty && sinPedido.isEmpty) return const SizedBox.shrink();

    Widget chip(Mesa m) => Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.tag),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Mesa ${m.numero}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () => _liberarMesa(m),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Liberar'),
          ),
        ],
      ),
    );

    Widget grupo(String texto, List<Mesa> lista) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            texto,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final m in lista) chip(m)],
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                LucideIcons.armchair,
                size: 15,
                color: AppColors.primaryGreenDark,
              ),
              SizedBox(width: 8),
              Text(
                'Mesas por liberar',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (cobradas.isNotEmpty)
            grupo('Ya pagaron. Libera la mesa cuando se retiren.', cobradas),
          if (cobradas.isNotEmpty && sinPedido.isNotEmpty)
            const SizedBox(height: 12),
          if (sinPedido.isNotEmpty)
            grupo('Ocupadas sin ningún pedido abierto.', sinPedido),
        ],
      ),
    );
  }

  // ---------- datos ----------

  bool get _esAdmin => widget.usuario.rol == AppRole.administrador;

  // En la cola quedan los pedidos abiertos: pendientes y servidos sin cobrar.
  bool _esActivo(Pedido p) => p.abierto;

  List<Pedido> get _cola {
    final base = pedidos.where(_esActivo);
    if (_estadoFiltro == null) return base.toList();
    if (_estadoFiltro == 'pendiente') {
      return base
          .where((p) => p.estado == 'pendiente' || p.estado == 'pedido')
          .toList();
    }
    return base.where((p) => p.estado == _estadoFiltro).toList();
  }

  // Pedido elegido, o null si ya no está activo (pagado/cancelado/devuelto).
  Pedido? get _seleccionado {
    for (final p in pedidos) {
      if (p.id == _seleccionId && _esActivo(p)) return p;
    }
    return null;
  }

  int _contarEstado(String? estado) {
    final base = pedidos.where(_esActivo);
    if (estado == null) return base.length;
    return base.where((p) {
      if (estado == 'pendiente') {
        return p.estado == 'pendiente' || p.estado == 'pedido';
      }
      return p.estado == estado;
    }).length;
  }

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

  // "Volver" desde el primer paso: regresa a elegir el tipo de pedido.
  void _volverATipo() {
    setState(() => _armandoPedido = false);
    _nuevoPedido();
  }

  void _terminarNuevoPedido(bool creado) {
    setState(() {
      _armandoPedido = false;
      if (creado && pedidos.isNotEmpty) _seleccionId = pedidos.first.id;
    });
  }

  // ---------- UI ----------

  double _margen(BuildContext context) =>
      AppBreakpoints.esMobile(context) ? 12 : 20;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _armandoPedido
            ? Padding(
                // En pantallas angostas el armado ocupa todo el ancho, con su
                // barra de título fija.
                padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 900 ? 0 : _margen(context),
                ),
                child: NuevoPedidoDialog(
                  usuario: widget.usuario,
                  tipo: _tipoNuevoPedido!,
                  onTerminar: _terminarNuevoPedido,
                  onVolver: _volverATipo,
                ),
              )
            : Padding(
                padding: EdgeInsets.all(_margen(context)),
                child: LayoutBuilder(
                  builder: (context, c) => _seccionesPedidos(c),
                ),
              ),
      ),
    );
  }

  Widget _seccionesPedidos(BoxConstraints c) {
    final seleccionado = _seleccionado;
    if (c.maxWidth >= _anchoMinDosSecciones) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _colaPedidos()),
          const SizedBox(width: 16),
          SizedBox(
            width: _anchoDetalle,
            child: seleccionado == null
                ? _detalleVacio()
                : DetallePedidoPanel(
                    key: ValueKey('detalle-${seleccionado.id}'),
                    pedido: seleccionado,
                    onCambio: () => setState(() {}),
                    esAdmin: _esAdmin,
                  ),
          ),
        ],
      );
    }
    if (seleccionado != null) {
      return DetallePedidoPanel(
        key: ValueKey('detalle-${seleccionado.id}'),
        pedido: seleccionado,
        onCambio: () => setState(() {}),
        onVolver: () => setState(() => _seleccionId = null),
        esAdmin: _esAdmin,
      );
    }
    return _colaPedidos();
  }

  Widget _detalleVacio() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.receipt, size: 34, color: Colors.grey.shade400),
              const SizedBox(height: 10),
              Text(
                'Elige un pedido para ver su detalle',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- cola de pedidos ---

  Widget _colaPedidos() {
    final cola = _cola;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cabeceraCola(),
          const SizedBox(height: 12),
          _filtroEstado(),
          const SizedBox(height: 14),
          _mesasPorLiberar(),
          Expanded(
            child: cola.isEmpty
                ? Center(
                    child: Text(
                      'Sin pedidos activos',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, c) {
                      const espacio = 12.0;
                      final columnas =
                          ((c.maxWidth + espacio) / (230 + espacio))
                              .floor()
                              .clamp(1, 4);
                      final ancho =
                          (c.maxWidth - espacio * (columnas - 1)) / columnas;
                      return SingleChildScrollView(
                        child: Wrap(
                          spacing: espacio,
                          runSpacing: espacio,
                          children: [
                            for (final p in cola)
                              SizedBox(width: ancho, child: _tarjetaPedido(p)),
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

  // Título + cantidad y "Nuevo Pedido".
  Widget _cabeceraCola() {
    return Row(
      children: [
        const Flexible(
          child: Text(
            'Cola de pedidos',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${_cola.length}',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _botonNuevoPedido() {
    final estrecho = MediaQuery.sizeOf(context).width < 400;
    return FilledButton.icon(
      onPressed: _nuevoPedido,
      style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
      icon: const Icon(Icons.add, size: 18),
      label: Text(
        estrecho ? 'Nuevo' : 'Nuevo Pedido',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  // Tabs de estado (`pedidos.estado`), cada una con su cantidad.
  Widget _filtroEstado() {
    const opciones = <(String?, String)>[
      (null, 'Todos'),
      ('pendiente', 'Pendiente'),
      ('servido', 'Servido'),
    ];
    // Tabs y "Nuevo Pedido" en la misma fila; si los tabs no caben aparecen las
    // flechas para desplazarlos.
    return Row(
      children: [
        Expanded(
          child: TabsDesplazables(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final o in opciones) _pastillaEstado(o.$1, o.$2)],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _botonNuevoPedido(),
      ],
    );
  }

  Widget _pastillaEstado(String? valor, String etiqueta) {
    return AppTag(
      etiqueta: etiqueta,
      activo: _estadoFiltro == valor,
      cantidad: _contarEstado(valor),
      onTap: () => setState(() => _estadoFiltro = valor),
    );
  }

  Widget _tarjetaPedido(Pedido p) {
    final tenue = Colors.grey.shade600;
    final lineas = (detallesPorPedido[p.id] ?? [])
        .where(esLineaDeProducto)
        .toList();
    final seleccionado = p.id == _seleccionId;
    const maxItems = 3;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _seleccionId = p.id),
      child: Container(
        height: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppColors.primaryGreen.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? AppColors.primaryGreen : Colors.grey.shade200,
            width: seleccionado ? 1.6 : 1,
          ),
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
                BadgeEstadoPedido(p.estado),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: Text(
                    tituloPedido(p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (esPedidoDeEmpleado(p)) ...[
                  const SizedBox(width: 6),
                  const TagEmpleado(),
                ],
              ],
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
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (l.comentario != null)
                            Text(
                              l.comentario!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
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
                  style: const TextStyle(
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
}

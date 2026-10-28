import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/borrador_pedido_store.dart';
import '../data/mesas_por_liberar_store.dart';
import '../data/configuracion_store.dart';
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
import '../services/traspaso_service.dart';
import '../data/traspasos_store.dart';
import '../services/auth_service.dart';
import '../widgets/traspaso_dialogs.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../widgets/app_search_field.dart';
import '../widgets/etiqueta_tipo_pedido.dart';
import '../widgets/app_select.dart';
import '../widgets/aviso_caja_cerrada.dart';
import '../data/cierres_store.dart';
import '../models/turno.dart';
import '../services/caja_service.dart';
import '../widgets/dialogo_app.dart';
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
  // Lleva a la vista de Caja (solo para quien puede abrirla).
  final VoidCallback? onIrACaja;

  const PedidosScreen({super.key, required this.usuario, this.onIrACaja});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  static const _anchoDetalle = 390.0;
  static const _anchoMinDosSecciones = 900.0;

  String? _tipoFiltro; // null = Todos; 'mesa' | 'delivery' | 'llevar'
  final _busqueda = TextEditingController();
  String? _seleccionId; // pedido mostrado en el detalle
  bool _armandoPedido = false; // true = la vista muestra "Nuevo pedido"
  String? _tipoNuevoPedido; // 'mesa' | 'delivery', elegido en el modal
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    // Se salió de aquí con un pedido a medias: se vuelve a él.
    final borrador = borradorDe(widget.usuario.id);
    if (borrador != null) {
      _armandoPedido = true;
      _tipoNuevoPedido = borrador.tipo;
    }
    mesasPorLiberarNotifier.addListener(_alCambiarEnVivo);
    traspasosRevision.addListener(_alCambiarEnVivo);
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

  // Solicitudes que ya se mostraron en el modal: cada una se avisa una vez.
  final Set<String> _traspasosAvisados = {};
  bool _modalTraspasos = false;

  // Al llegar un traspaso nuevo, se abre el modal para aceptarlo o rechazarlo.
  Future<void> _avisarTraspasos() async {
    if (_modalTraspasos || !mounted) return;
    final nuevos = [
      for (final t in traspasosPorResponder(
        AuthService.instance.currentUser?.id ?? '',
      ))
        if (!_traspasosAvisados.contains(t.id)) t,
    ];
    if (nuevos.isEmpty) return;
    _traspasosAvisados.addAll(nuevos.map((t) => t.id));
    _modalTraspasos = true;
    await showBlurDialog<void>(
      context: context,
      builder: (_) => const BandejaTraspasosDialog(),
    );
    _modalTraspasos = false;
    if (mounted) _cargar();
  }

  void _alCambiarEnVivo() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    traspasosRevision.removeListener(_alCambiarEnVivo);
    EventosService.instance.revision.removeListener(_alCambiarEnVivo);
    mesasPorLiberarNotifier.removeListener(_alCambiarEnVivo);
    _pollingTimer?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    await PedidoService.instance.cargarPedidos();
    if (CajaService.instance.enServidor) {
      try {
        await CajaService.instance.cargarEstado();
      } catch (_) {}
    }
    // Para saber qué mesas siguen ocupadas (franja "Mesas por liberar").
    if (PedidoMozoService.instance.activo) {
      await TraspasoService.instance.cargar();
      await CatalogService.instance.cargarMesas();
      // Cobrar no dispara un evento: se consulta también en cada lectura.
      await recargarMesasPorLiberar();
    }
    if (mounted) setState(() {});
    _avisarTraspasos();
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
  // los clientes se retiran. La lista la da el backend: al mozo solo le salen
  // las mesas que atendió; al administrador, todas las de la sede.
  Widget _mesasPorLiberar() {
    if (!PedidoMozoService.instance.activo) return const SizedBox.shrink();
    final cobradas = mesasPorLiberar();
    if (cobradas.isEmpty) return const SizedBox.shrink();

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
          grupo('Ya pagaron. Libera la mesa cuando se retiren.', cobradas),
        ],
      ),
    );
  }

  // ---------- datos ----------

  bool get _esAdmin => widget.usuario.rol == AppRole.administrador;

  // En la cola quedan los pedidos abiertos: pendientes y servidos sin cobrar.
  bool _esActivo(Pedido p) => p.abierto;

  String _medioFiltro = 'todos'; // nombre del medio de pago, o 'todos'

  // Pedidos cobrados (aunque sea en parte) con el medio elegido.
  bool _conMedio(Pedido p) =>
      _medioFiltro == 'todos' || mediosDePagoDe(p.id).contains(_medioFiltro);

  // Texto del buscador: coincide con la mesa, el mozo, el número del pedido o
  // el cliente (sin distinguir mayúsculas ni tildes).
  bool _coincide(Pedido p) {
    final q = _normalizar(_busqueda.text.trim());
    if (q.isEmpty) return true;
    final campos = [
      p.ubicacion,
      if (p.mesaNumero > 0) 'mesa ${p.mesaNumero}',
      nombreMeseroDe(p),
      p.numeroPedido,
      p.clienteNombre ?? '',
    ];
    return campos.any((c) => _normalizar(c).contains(q));
  }

  static String _normalizar(String t) {
    const de = 'áàäâéèëêíìïîóòöôúùüûñ';
    const a = 'aaaaeeeeiiiioooouuuun';
    final b = StringBuffer();
    for (final c in t.toLowerCase().split('')) {
      final i = de.indexOf(c);
      b.write(i >= 0 ? a[i] : c);
    }
    return b.toString();
  }

  List<Pedido> get _cola {
    // "Pagados": los ya cobrados. En "Todos" y en los demás filtros solo están
    // los pedidos abiertos, para que lo cobrado no estorbe.
    if (_tipoFiltro == 'pagados') {
      return pedidos
          .where((p) => p.estado == 'pagado' && _conMedio(p) && _coincide(p))
          .toList();
    }
    final base = pedidos.where((p) => _esActivo(p) && _coincide(p));
    if (_tipoFiltro == null) return base.toList();
    return base.where((p) => p.tipoPedido == _tipoFiltro).toList();
  }

  // Pedido elegido, o null si ya no está activo (pagado/cancelado/devuelto).
  Pedido? get _seleccionado {
    for (final p in pedidos) {
      if (p.id == _seleccionId &&
          (_esActivo(p) ||
              (_tipoFiltro == 'pagados' && p.estado == 'pagado'))) {
        return p;
      }
    }
    return null;
  }

  int _contarTipo(String? tipo) {
    if (tipo == 'pagados') {
      return pedidos.where((p) => p.estado == 'pagado').length;
    }
    final base = pedidos.where(_esActivo);
    if (tipo == null) return base.length;
    return base.where((p) => p.tipoPedido == tipo).length;
  }

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}, '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // ---------- acciones ----------

  // "Nuevo Pedido" abre el modal de elegir tipo; luego arma el pedido inline.
  Future<void> _nuevoPedido() async {
    // Sin caja abierta no se registran pedidos.
    if (await cajaCerrada()) {
      if (!mounted) return;
      await mostrarAvisoCajaCerrada(context, irAAbrir: widget.onIrACaja);
      return;
    }
    if (!mounted) return;
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

  // Traspasos que otros mozos le ofrecen al usuario: aceptar o rechazar.
  Widget _bannerTraspasos() {
    final n = traspasosPorResponder(AuthService.instance.currentUser?.id ?? '')
        .length;
    if (n == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.naranja.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.naranja, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.users, size: 22, color: AppColors.naranja),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              n == 1
                  ? 'Tienes 1 pedido por aceptar de otro mozo'
                  : 'Tienes $n pedidos por aceptar de otros mozos',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: () async {
              await showBlurDialog<void>(
                context: context,
                builder: (_) => const BandejaTraspasosDialog(),
              );
              _cargar();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.naranja),
            child: const Text('Ver'),
          ),
        ],
      ),
    );
  }

  Widget _bannerCajaCerrada() {
    if (!CajaService.instance.enServidor) return const SizedBox.shrink();
    if (estadoCajaServidor?.abierta == true) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade400, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.alertTriangle,
            size: 22,
            color: Colors.amber.shade900,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Caja cerrada',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                Text(
                  'No se podrán cobrar pedidos ni registrar pagos hasta que se abra la caja.',
                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                ),
              ],
            ),
          ),
          if (_esAdmin || widget.usuario.rol == AppRole.cajero) ...[
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: _abrirCajaDialog,
              icon: const Icon(LucideIcons.lockOpen, size: 16),
              label: const Text('Abrir Caja Ahora'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _abrirCajaDialog() async {
    final montoCtrl = TextEditingController(text: '0');
    final notasCtrl = TextEditingController();
    List<Turno> turnos = [];
    try {
      turnos = await CajaService.instance.cargarTurnos();
    } catch (_) {}
    String? turnoSeleccionadoId = turnos.firstOrNull?.id;

    if (!mounted) return;
    final confirmado = await showBlurDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertaApp(
          title: const Text('Apertura Rápida de Caja'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingresa el efectivo inicial y turno para comenzar a registrar pagos.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: montoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Monto inicial (S/)',
                    prefixText: 'S/ ',
                  ),
                ),
                const SizedBox(height: 12),
                if (turnos.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: turnoSeleccionadoId,
                    decoration: const InputDecoration(labelText: 'Turno'),
                    items: [
                      for (final t in turnos)
                        DropdownMenuItem(
                          value: t.id,
                          child: Text(
                            '${t.nombre} (${t.horaInicio} - ${t.horaFin})',
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      setDialogState(() => turnoSeleccionadoId = val);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: notasCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas u observaciones (opcional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Abrir Caja'),
            ),
          ],
        ),
      ),
    );

    if (confirmado != true || !mounted) return;
    final monto =
        double.tryParse(montoCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    try {
      await CajaService.instance.abrir(
        montoInicial: monto,
        turnoId: turnoSeleccionadoId,
        notas: notasCtrl.text.trim(),
      );
      if (mounted) {
        showAppToast(
          context,
          'Caja abierta con éxito.',
          type: ToastType.success,
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) showAppToast(context, e.toString(), type: ToastType.error);
    }
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
          _bannerCajaCerrada(),
          _bannerTraspasos(),
          _cabeceraCola(),
          const SizedBox(height: 12),
          _filtroEstado(),
          const SizedBox(height: 10),
          _buscador(),
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

  // Tabs por tipo de pedido (mesa, delivery, para llevar), cada una con su
  // cantidad.
  Widget _filtroEstado() {
    const opciones = <(String?, String)>[
      (null, 'Todos'),
      ('mesa', 'Mesa'),
      ('delivery', 'Delivery'),
      ('llevar', 'Para llevar'),
      ('pagados', 'Pagados'),
    ];
    // Tabs y "Nuevo Pedido" en la misma fila; si los tabs no caben aparecen las
    // flechas para desplazarlos.
    return Row(
      children: [
        Expanded(
          child: TabsDesplazables(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final o in opciones) _pastillaTipo(o.$1, o.$2)],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _botonNuevoPedido(),
      ],
    );
  }

  // Buscador y, solo en "Pagados", filtro por medio de pago (por ejemplo, cada
  // número de Yape).
  Widget _buscador() {
    final nombres = <String>{
      for (final m in mediosPagoActivos) m.medioPago,
      for (final p in pagos) p.medioPago.medioPago,
    }.toList()..sort();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppSearchField(
          controller: _busqueda,
          hint: 'Buscar mesa, mozo o pedido...',
          onChanged: (_) => setState(() {}),
        ),
        if (_tipoFiltro == 'pagados')
          SizedBox(
            width: 240,
            child: AppSelect<String>(
              compacto: true,
              value: _medioFiltro,
              hint: 'Medio de pago',
              items: [
                const AppSelectItem(
                  value: 'todos',
                  label: 'Todos los medios de pago',
                ),
                for (final n in nombres) AppSelectItem(value: n, label: n),
              ],
              onChanged: (v) => setState(() => _medioFiltro = v ?? 'todos'),
            ),
          ),
      ],
    );
  }

  Widget _pastillaTipo(String? valor, String etiqueta) {
    return AppTag(
      etiqueta: etiqueta,
      activo: _tipoFiltro == valor,
      cantidad: _contarTipo(valor),
      onTap: () => setState(() {
        _tipoFiltro = valor;
        if (valor != 'pagados') _medioFiltro = 'todos';
      }),
    );
  }

  Widget _tipoDePedido(Pedido p) => EtiquetaTipoPedido(pedido: p);

  // Texto de la línea de pago de la tarjeta (null si aún no se cobró).
  String? _lineaDePago(Pedido p) {
    final cobrados = mediosDePagoDe(p.id);
    if (cobrados.isNotEmpty) return 'Pagó con ${cobrados.join(' · ')}';
    return null;
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
                if (p.estado == 'pagado')
                  // Ya cobrado: "Pagado" en rojo con letras blancas.
                  const _TagPagado(cobrado: true)
                else ...[
                  // Cobrado antes de servir: "Pagado" en naranja.
                  if (pagadoSinServir(p)) ...[
                    const _TagPagado(),
                    const SizedBox(width: 6),
                  ],
                  BadgeEstadoPedido(p.estado),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // El tipo de pedido (Mesa, Para llevar, Delivery) con su color.
                Flexible(child: _tipoDePedido(p)),
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
            // Mozo que atiende el pedido (el de esa mesa).
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(LucideIcons.user, size: 12, color: tenue),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Mozo: ${nombreMeseroDe(p)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
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
            // Con qué medios se cobró, si ya hay cobros.
            if (_lineaDePago(p) case final linea?) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(LucideIcons.wallet, size: 15, color: tenue),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      linea,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Tag de un pedido ya cobrado que todavía no sale.
class _TagPagado extends StatelessWidget {
  // true: el pedido ya está cobrado (rojo); false: se cobró antes de servir
  // (naranja).
  final bool cobrado;

  const _TagPagado({this.cobrado = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cobrado ? AppColors.error : AppColors.naranja,
        borderRadius: BorderRadius.circular(100),
      ),
      child: const Text(
        'Pagado',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

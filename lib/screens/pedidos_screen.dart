import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/borrador_pedido_store.dart';
import '../data/configuracion_store.dart';
import '../data/mesas_por_liberar_store.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../models/usuario.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
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
import '../utils/nota_pedido.dart';
import '../widgets/app_search_field.dart';
import '../widgets/menu_flotante.dart';
import '../widgets/etiqueta_tipo_pedido.dart';
import '../widgets/aviso_caja_cerrada.dart';
import '../data/cierres_store.dart';
import '../models/turno.dart';
import '../services/caja_service.dart';
import '../widgets/dialogo_app.dart';
import '../widgets/app_toast.dart';
import '../widgets/indicador_abajo.dart';
import '../widgets/cronometro_pedido.dart';
import '../widgets/detalle_pedido_panel.dart';
import '../widgets/elegir_nuevo_pedido_dialog.dart';
import '../widgets/nuevo_pedido_dialog.dart';
import '../widgets/app_tag.dart';
import '../widgets/tabs_texto.dart';
import '../widgets/texto_adaptable.dart';

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
  static const _anchoDetalle = 420.0;
  static const _anchoMinDosSecciones = 900.0;

  String? _tipoFiltro; // null = Todos; 'mesa' | 'delivery' | 'llevar'

  // Vistas de la cola: Clientes y Empleados, como pestañas en cadena.
  static const _vistas = <_VistaCola>[
    _VistaCola(id: 'clientes', nombre: 'Clientes', filtro: 'clientes'),
    _VistaCola(id: 'empleados', nombre: 'Empleados', filtro: 'empleados'),
    _VistaCola(id: 'familia', nombre: 'Familia', filtro: 'familia'),
  ];
  String _vistaId = 'clientes';

  _VistaCola get _vistaActual =>
      _vistas.firstWhere((v) => v.id == _vistaId, orElse: () => _vistas.first);

  bool _enVista(Pedido p) => _enVistaDe(_vistaActual, p);

  // Pedidos viejos fuera de esta vista: Pedidos solo muestra lo de hoy o de la
  // caja actual (lo anterior vive en Ventas y Caja).
  bool _esDelPeriodo(Pedido p) {
    final h = DateTime.now();
    final hoy = DateTime(h.year, h.month, h.day);
    final caja = inicioCajaActual;
    final desde = caja.isBefore(hoy) ? caja : hoy;
    return !p.fechaPedido.isBefore(desde);
  }

  bool _enVistaDe(_VistaCola v, Pedido p) =>
      _esDelPeriodo(p) &&
      switch (v.filtro) {
        'clientes' => !esPedidoDeEmpleado(p) && !esPedidoDeFamilia(p.id),
        'empleados' => esPedidoDeEmpleado(p),
        'familia' => esPedidoDeFamilia(p.id),
        _ => true,
      };

  // Pedidos abiertos que tiene cada vista.
  int _cantidadDeVista(_VistaCola v) =>
      pedidos.where((p) => _esActivo(p) && _enVistaDe(v, p)).length;

  // Subheader con las vistas (Clientes, Empleados, Familia): rectangulares y
  // solo la elegida va en verde, con la cantidad de pedidos de cada una.
  Widget _pestanasVistas() {
    Widget pestana(_VistaCola v) {
      final activa = v.id == _vistaId;
      return InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => _vistaId = v.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: activa ? AppColors.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                v.nombre,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: activa ? Colors.white : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: activa ? Colors.white : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_cantidadDeVista(v)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: activa
                        ? AppColors.primaryGreen
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (final v in _vistas) pestana(v)],
        ),
      ),
    );
  }

  final _busqueda = TextEditingController();
  String? _seleccionId; // pedido mostrado en el detalle
  bool _armandoPedido = false; // true = la vista muestra "Nuevo pedido"
  String _destinatarioNuevo = 'cliente'; // 'cliente' | 'familia' | 'empleado'
  String? _tipoNuevoPedido; // 'mesa' | 'delivery', elegido en el modal
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    // Se salió de aquí con un pedido a medias: se vuelve a él.
    final borrador = borradorDe(widget.usuario.id);
    // Un borrador con un tipo que ya no existe (por ejemplo, uno de una versión
    // anterior) se descarta en vez de abrirse.
    if (borrador != null &&
        const ['mesa', 'llevar', 'delivery'].contains(borrador.tipo)) {
      _armandoPedido = true;
      _tipoNuevoPedido = borrador.tipo;
    } else if (borrador != null) {
      descartarBorradorYEsperar();
    }
    mesasPorLiberarNotifier.addListener(_alCambiarEnVivo);
    traspasosRevision.addListener(_alCambiarEnVivo);
    _cargar();
    cargarCuentasCeroCerradas().then((_) {
      if (mounted) setState(() {});
    });
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

  bool _modalRechazo = false;

  // Si el otro mozo rechazó un traspaso que este mozo envió, se le avisa para
  // que elija a otro.
  Future<void> _avisarRechazos() async {
    if (_modalRechazo || !mounted || traspasosRechazados.isEmpty) return;
    _modalRechazo = true;
    while (mounted && traspasosRechazados.isNotEmpty) {
      final t = traspasosRechazados.removeAt(0);
      final pedido = pedidos.where((p) => p.id == t.pedidoId).firstOrNull;
      TraspasoService.instance.marcarVisto(t.id);
      final numPedido = pedido?.numeroPedido ?? t.pedidoNumero ?? '';
      final ubicacion = pedido?.ubicacion ?? t.ubicacion ?? '';
      final elegir = await showBlurDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertaApp(
          title: const Text('Traspaso rechazado'),
          content: Text(
            '${t.destinoNombre.isEmpty ? 'El mozo' : t.destinoNombre} '
            'rechazó el pedido #${numPedido.isEmpty ? 's/n' : numPedido} '
            '(${ubicacion.isEmpty ? 'Salón' : ubicacion}). Sigue a tu nombre: elige a otro mozo '
            'para traspasarlo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Después'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Elegir otro mozo'),
            ),
          ],
        ),
      );
      if (elegir != true || !mounted) continue;
      final pedidoObj =
          pedido ?? pedidos.where((p) => p.id == t.pedidoId).firstOrNull;
      if (pedidoObj == null) continue;
      final destino = await showBlurDialog<String>(
        context: context,
        builder: (_) => TraspasarPedidoDialog(pedido: pedidoObj),
      );
      if (destino != null && mounted) {
        showAppToast(
          context,
          'Traspaso del pedido #${pedidoObj.numeroPedido} enviado a $destino.',
          type: ToastType.success,
        );
      }
    }
    _modalRechazo = false;
    if (mounted) _cargar();
  }

  void _alCambiarEnVivo() {
    if (!mounted) return;
    setState(() {});
    // Un traspaso nuevo o rechazado avisa al momento, sin esperar la consulta
    // periódica.
    _avisarTraspasos();
    _avisarRechazos();
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
    // Para saber qué mesas siguen ocupadas (notificación "Mesas por liberar").
    if (PedidoMozoService.instance.activo) {
      await TraspasoService.instance.cargar();
      await CatalogService.instance.cargarMesas();
      // Cobrar no dispara un evento: se consulta también en cada lectura.
      await recargarMesasPorLiberar();
    }
    if (mounted) setState(() {});
    _avisarTraspasos();
    _avisarRechazos();
  }

  // ---------- datos ----------

  bool get _esAdmin => widget.usuario.administraPedidos;

  // En la cola quedan los pedidos abiertos: pendientes y servidos sin cobrar.
  // Un pedido ya cobrado por completo sale de la vista de pedidos: queda en
  // Ventas y en Caja.
  bool _esCobrado(Pedido p) {
    if (p.estado == 'anulado' || p.estado == 'devuelto') return false;
    // Si está en 'pagado', pero por anulación de pagos/movimientos en caja ahora tiene saldo pendiente:
    if (p.estado == 'pagado') {
      return saldoPendienteDePedido(p.id) <= 0.005;
    }
    // Cuenta en cero a propósito (familia, empleado o cumpleaños): al "pagarse"
    // queda con un pago en cero y sale de la vista. Solo si su total es cero: un
    // pedido de empleado con abonos y saldo sigue en la cola.
    if (motivoCuentaCero(p) != null &&
        totalDePedido(p.id).abs() < 0.005 &&
        pagos.any(
          (x) =>
              x.pedidoId == p.id &&
              !x.esReembolso &&
              !x.anulado &&
              x.estado != 'anulado',
        )) {
      return true;
    }
    // Si su estado es 'pendiente', 'pedido' o 'servido', pero ya está 100% saldado con pagos activos:
    final total = totalDePedido(p.id);
    if (total > 0.005 && saldoPendienteDePedido(p.id) <= 0.005) {
      final tienePagos = pagos.any(
        (x) =>
            x.pedidoId == p.id &&
            !x.esReembolso &&
            !x.anulado &&
            x.estado != 'anulado',
      );
      if (tienePagos) return true;
    }
    return pagadoSinServir(p);
  }

  // En la cola solo salen pedidos abiertos, no cobrados y con sus productos ya
  // cargados: sin ellos el total se ve en cero y la tarjeta aparecía unos
  // segundos hasta que llegaba el detalle y desaparecía.
  bool _esActivo(Pedido p) =>
      p.abierto &&
      !cuentasCeroCerradas.contains(p.id) &&
      !_esCobrado(p) &&
      (detallesPorPedido[p.id] ?? const <PedidoLine>[]).isNotEmpty;

  // Texto del buscador: coincide con la mesa, el mozo, el número del pedido o
  // el cliente (sin distinguir mayúsculas ni tildes).
  bool _coincide(Pedido p) {
    // El número de pedido se busca con o sin "#" ("#0007", "0007" o "7").
    final q = _normalizar(_busqueda.text.trim()).replaceAll('#', '').trim();
    if (q.isEmpty) return true;
    final campos = [
      p.ubicacion,
      if (p.mesaNumero > 0) 'mesa ${p.mesaNumero}',
      nombreMeseroDe(p),
      p.numeroPedido,
      p.clienteNombre ?? '',
      p.clienteCelular ?? '',
    ];
    if (campos.any((c) => _normalizar(c).contains(q))) return true;
    // El celular también se encuentra escrito con espacios o guiones.
    final digitos = q.replaceAll(RegExp(r'\D'), '');
    return digitos.length >= 3 &&
        (p.clienteCelular ?? '')
            .replaceAll(RegExp(r'\D'), '')
            .contains(digitos);
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
    // Solo los pedidos abiertos: lo ya cobrado no se muestra.
    final base = pedidos.where(
      (p) => _esActivo(p) && _enVista(p) && _coincide(p) && _conMedio(p),
    );
    if (_tipoFiltro == null) return base.toList();
    return base.where((p) => p.tipoPedido == _tipoFiltro).toList();
  }

  // Pedido elegido, o null si ya no está activo (pagado/cancelado/devuelto).
  Pedido? get _seleccionado {
    for (final p in pedidos) {
      if (p.id == _seleccionId && _esDelPeriodo(p) && _esActivo(p)) {
        return p;
      }
    }
    return null;
  }

  int _contarTipo(String? tipo) {
    final base = pedidos.where((p) => _esActivo(p) && _enVista(p));
    if (tipo == null) return base.length;
    return base.where((p) => p.tipoPedido == tipo).length;
  }

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
    // Un solo modal con dos pasos (para quién es y el tipo): cualquier usuario,
    // también el mozo, puede registrar pedidos de clientes, empleados o familia.
    final eleccion = await showBlurDialog<EleccionNuevoPedido>(
      context: context,
      builder: (_) => const ElegirNuevoPedidoDialog(conDestinatario: true),
    );
    if (eleccion == null || !mounted) return;
    final destinatario = eleccion.destinatario;
    final tipo = eleccion.tipo;
    setState(() {
      _destinatarioNuevo = destinatario;
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
      if (creado) {
        // El pedido nuevo se ve en la vista de su destinatario (clientes,
        // empleados o familia) y sin filtros que lo escondan.
        _vistaId = switch (_destinatarioNuevo) {
          'empleado' => 'empleados',
          'familia' => 'familia',
          _ => 'clientes',
        };
        _tipoFiltro = null;
        _medioFiltro = 'todos';
        _busqueda.clear();
        if (pedidos.isNotEmpty) _seleccionId = pedidos.first.id;
      }
    });
  }

  // ---------- UI ----------

  double _margen(BuildContext context) =>
      AppBreakpoints.esMobile(context) ? 12 : 20;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _armandoPedido
            ? Padding(
                // El armado del pedido ocupa toda la vista, pegado a los
                // bordes, con su barra verde arriba.
                padding: EdgeInsets.zero,
                child: NuevoPedidoDialog(
                  usuario: widget.usuario,
                  tipo: _tipoNuevoPedido!,
                  onTerminar: _terminarNuevoPedido,
                  onVolver: _volverATipo,
                  inicioPersonal: _destinatarioNuevo == 'empleado',
                  esFamilia: _destinatarioNuevo == 'familia',
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
          const SizedBox(width: 12),
          VerticalDivider(width: 1, color: Colors.grey.shade200),
          const SizedBox(width: 12),
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
      color: Colors.white,
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
          if (_esAdmin) ...[
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
    // Celular: filtros más livianos y tarjetas compactas.
    final movil = AppBreakpoints.esMobile(context);
    final lista = Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bannerCajaCerrada(),
          _bannerTraspasos(),
          if (movil)
            _filtrosMovil()
          else ...[
            _pestanasVistas(),
            const SizedBox(height: 8),
            _barraFiltros(),
          ],
          const SizedBox(height: 10),
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
                      // En celular no hay barra de desplazamiento: las tarjetas
                      // ocupan el mismo ancho que los filtros.
                      final holgura = movil ? 0.0 : 14.0;
                      final ancho =
                          (c.maxWidth - holgura - espacio * (columnas - 1)) /
                          columnas;
                      return IndicadorAbajo(
                        builder: (ctl) => SingleChildScrollView(
                          controller: ctl,
                          padding: EdgeInsets.only(right: holgura, bottom: 8),
                          child: Wrap(
                            spacing: espacio,
                            runSpacing: espacio,
                            crossAxisAlignment: WrapCrossAlignment.start,
                            children: [
                              for (final p in cola)
                                SizedBox(
                                  width: ancho,
                                  child: movil
                                      ? _tarjetaPedidoMovil(p)
                                      : _tarjetaPedido(p),
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
    return lista;
  }

  // Filtros de celular: buscador con "Nuevo", pestañas de texto por tipo de
  // pedido (con su cantidad) y dos selectores lado a lado, "Para quién" y "Medio de pago",
  // que abren su lista de opciones. Un selector con algo elegido se pinta de
  // verde y su "x" lo quita.
  Widget _filtrosMovil() {
    final nombres = <String>{
      for (final m in mediosPagoActivos) m.medioPago,
      for (final p in pagos) p.medioPago.medioPago,
    }.toList()..sort();
    Widget selector({
      required IconData icono,
      required String texto,
      String? textoCorto,
      required bool activo,
      required VoidCallback onQuitar,
      required String tooltip,
      required String seleccionada,
      required List<OpcionMenu<String>> opciones,
      required ValueChanged<String> onSeleccionar,
    }) {
      return Expanded(
        child: MenuFlotante<String>(
          tooltip: tooltip,
          seleccionada: seleccionada,
          onSeleccionar: onSeleccionar,
          opciones: opciones,
          disparador: (context, abierto) {
            final color = activo
                ? AppColors.primaryGreenDark
                : Colors.grey.shade700;
            return Container(
              height: 40,
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                color: activo
                    ? AppColors.primaryGreen.withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: activo || abierto
                      ? AppColors.primaryGreen
                      : Colors.grey.shade400,
                ),
              ),
              child: Row(
                children: [
                  Icon(icono, size: 16, color: color),
                  const SizedBox(width: 6),
                  // El texto se adapta al ancho (versión corta o más chico), sin
                  // cortarse con "…".
                  Expanded(
                    child: TextoAdaptable(
                      textos: [texto, ?textoCorto],
                      alineacion: Alignment.centerLeft,
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ),
                  if (activo)
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onQuitar,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(Icons.close, size: 16, color: color),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: abierto ? 0.5 : 0,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    }

    // Sin margen propio: queda alineado con las tarjetas de abajo.
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // El buscador y "Nuevo" (el mismo botón y tamaño del resto del
          // sistema) comparten la fila: nada flota sobre la lista.
          Row(
            children: [
              Expanded(
                child: AppSearchField(
                  controller: _busqueda,
                  hint: 'Buscar...',
                  compacto: true,
                  ajustarAlTexto: false,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              _botonNuevoPedido(),
            ],
          ),
          const SizedBox(height: 4),
          TabsTexto(
            tabs: [
              for (final o in const <(String?, String)>[
                (null, 'Todos'),
                ('mesa', 'Mesa'),
                ('delivery', 'Delivery'),
                ('llevar', 'Para llevar'),
              ])
                TabTexto(
                  etiqueta: o.$2,
                  cantidad: _contarTipo(o.$1),
                  activa: _tipoFiltro == o.$1,
                  onTap: () => setState(() => _tipoFiltro = o.$1),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              selector(
                icono: LucideIcons.users,
                texto: _vistaActual.nombre,
                activo: _vistaId != 'clientes',
                onQuitar: () => setState(() => _vistaId = 'clientes'),
                tooltip: 'Pedidos de clientes, empleados o familia',
                seleccionada: _vistaId,
                opciones: [
                  for (final v in _vistas)
                    OpcionMenu(
                      valor: v.id,
                      etiqueta: '${v.nombre} (${_cantidadDeVista(v)})',
                    ),
                ],
                onSeleccionar: (v) => setState(() => _vistaId = v),
              ),
              const SizedBox(width: 8),
              selector(
                icono: LucideIcons.wallet,
                texto: _medioFiltro == 'todos'
                    ? 'Todos los pagos'
                    : _medioFiltro,
                textoCorto: _medioFiltro == 'todos' ? 'Pagos' : null,
                activo: _medioFiltro != 'todos',
                onQuitar: () => setState(() => _medioFiltro = 'todos'),
                tooltip: 'Filtrar por medio de pago',
                seleccionada: _medioFiltro,
                opciones: [
                  const OpcionMenu(
                    valor: 'todos',
                    etiqueta: 'Todos los medios de pago',
                  ),
                  for (final n in nombres) OpcionMenu(valor: n, etiqueta: n),
                ],
                onSeleccionar: (v) => setState(() => _medioFiltro = v),
              ),
            ],
          ),
        ],
      ),
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

  String _medioFiltro = 'todos'; // nombre del medio de pago, o 'todos'

  // Pedidos con algún cobro (por ejemplo, abonos) con el medio elegido.
  bool _conMedio(Pedido p) =>
      _medioFiltro == 'todos' || mediosDePagoDe(p.id).contains(_medioFiltro);

  // Buscador, filtros por medio de pago y por tipo de pedido, y "Nuevo Pedido"
  // junto a los filtros. En pantallas angostas los filtros pasan debajo del
  // buscador.
  Widget _barraFiltros() {
    final nombres = <String>{
      for (final m in mediosPagoActivos) m.medioPago,
      for (final p in pagos) p.medioPago.medioPago,
    }.toList()..sort();
    final buscador = AppSearchField(
      controller: _busqueda,
      hint: 'Buscar...',
      compacto: true,
      ajustarAlTexto: false,
      onChanged: (_) => setState(() {}),
    );
    // Medio de pago: botón de color fijo con la flecha a la derecha, como el
    // selector de estado del detalle.
    Widget selectMedio(double ancho) => SizedBox(
      width: ancho,
      child: MenuFlotante<String>(
        tooltip: 'Filtrar por medio de pago',
        seleccionada: _medioFiltro,
        onSeleccionar: (v) => setState(() => _medioFiltro = v),
        opciones: [
          const OpcionMenu(
            valor: 'todos',
            etiqueta: 'Todos los medios de pago',
          ),
          for (final n in nombres) OpcionMenu(valor: n, etiqueta: n),
        ],
        disparador: (context, abierto) => Container(
          height: AppSizes.boton,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.navbar,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _medioFiltro == 'todos' ? 'Medio de pago' : _medioFiltro,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                turns: abierto ? 0.5 : 0,
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Tipo de pedido: tags naranja, cada uno con su cantidad.
    Widget tags() => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final o in const <(String?, String)>[
            (null, 'Todos'),
            ('mesa', 'Mesa'),
            ('delivery', 'Delivery'),
            ('llevar', 'Para llevar'),
          ])
            AppTag(
              etiqueta: o.$2,
              activo: _tipoFiltro == o.$1,
              cantidad: _contarTipo(o.$1),
              color: AppColors.naranja,
              colorBorde: Colors.grey.shade300,
              colorTextoInactivo: Colors.grey.shade800,
              onTap: () => setState(() => _tipoFiltro = o.$1),
            ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, c) {
        // En tablet (hasta 1024 px de pantalla) el buscador ocupa su propia
        // línea, a todo el ancho. En escritorio comparte la fila con los
        // botones aunque el listado quede algo angosto (el detalle ocupa 420
        // px y la pantalla puede estar ampliada); solo si de verdad no cabe
        // (menos de 480 px) también se apila.
        final ancha =
            MediaQuery.sizeOf(context).width > 1024 && c.maxWidth >= 480;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ancha)
              Row(
                children: [
                  // El buscador llega a 440 px y se achica si falta espacio; los
                  // botones quedan a la derecha.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: buscador,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  selectMedio(150),
                  const SizedBox(width: 8),
                  _botonNuevoPedido(),
                ],
              )
            else ...[
              buscador,
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: selectMedio(double.infinity)),
                  const SizedBox(width: 8),
                  _botonNuevoPedido(),
                ],
              ),
            ],
            const SizedBox(height: 8),
            tags(),
          ],
        );
      },
    );
  }

  // Empleado y familia llevan el nombre en su etiqueta.
  bool _nombreEnEtiqueta(Pedido p) =>
      esPedidoDeEmpleado(p) || esPedidoDeFamilia(p.id);

  Widget _tipoDePedido(Pedido p) =>
      EtiquetaTipoPedido(pedido: p, colorFijo: Colors.grey.shade800);

  String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // Texto de la línea de pago de la tarjeta (null si aún no se cobró).
  String? _lineaDePago(Pedido p) {
    final cobrados = mediosDePagoDe(p.id);
    if (cobrados.isNotEmpty) return 'Pagó con ${cobrados.join(' · ')}';
    return null;
  }

  // Tarjeta de celular: compacta (número, tipo y hora; mozo; total y
  // cronómetro), neutra: el estado se ve en su etiqueta de color, no en la
  // tarjeta.
  Widget _tarjetaPedidoMovil(Pedido p) {
    final nombreEtiqueta = (nombreClienteDe(p) ?? '').trim();
    final cliente = esPedidoDeEmpleado(p)
        ? (nombreEtiqueta.isEmpty ? 'Empleado' : 'Empleado: $nombreEtiqueta')
        : esPedidoDeFamilia(p.id)
        ? (nombreEtiqueta.isEmpty ? 'Familia' : 'Familia: $nombreEtiqueta')
        : sinLineaDePropina(p.notas);
    final productos = (detallesPorPedido[p.id] ?? [])
        .where(esLineaDeProducto)
        .fold<int>(0, (s, l) => s + l.cantidad);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _seleccionId = p.id),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '#${p.numeroPedido}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                              TextSpan(
                                text:
                                    ' · ${p.ubicacion} · ${_hora(p.fechaPedido)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (p.estado == 'pagado' || _esCobrado(p))
                        const _TagPagado(cobrado: true)
                      else ...[
                        if (pagadoSinServir(p)) ...[
                          const _TagPagado(),
                          const SizedBox(width: 6),
                        ],
                        BadgeEstadoPedido(p.estado),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.user,
                        size: 13,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Mozo: ${nombreMeseroDe(p)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // El total se achica antes de desbordar la fila.
                      Flexible(
                        flex: 3,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            esPedidoDeFamilia(p.id) &&
                                    totalDePedido(p.id).abs() < 0.005
                                ? 'Cuenta de familia'
                                : 'S/ ${totalDePedido(p.id).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      // Se recorta si falta ancho (celular chico o letra grande).
                      Expanded(
                        flex: 2,
                        child: Text(
                          ' · $productos producto${productos == 1 ? '' : 's'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CronometroPedido(pedido: p),
                    ],
                  ),
                  if (_lineaDePago(p) case final linea?) ...[
                    const SizedBox(height: 4),
                    Text(
                      linea,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (cliente != null)
              Container(
                color: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                child: Text(
                  cliente,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaPedido(Pedido p) {
    final tenue = Colors.grey.shade600;
    final colorEstado = _esCobrado(p)
        ? paletaEstadoPedido('pagado').color
        : paletaEstadoPedido(p.estado).color;
    // Cliente, empleado o familia: va en una franja de color fuerte bajo la
    // cabecera.
    final nombreEtiqueta = (nombreClienteDe(p) ?? '').trim();
    final cliente = esPedidoDeEmpleado(p)
        ? (nombreEtiqueta.isEmpty ? 'Empleado' : 'Empleado: $nombreEtiqueta')
        : esPedidoDeFamilia(p.id)
        ? (nombreEtiqueta.isEmpty ? 'Familia' : 'Familia: $nombreEtiqueta')
        : sinLineaDePropina(p.notas);
    final lineas = (detallesPorPedido[p.id] ?? [])
        .where(esLineaDeProducto)
        .toList();
    final seleccionado = p.id == _seleccionId;
    const maxItems = 3;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _seleccionId = p.id),
      // La tarjeta elegida sobresale como una tecla: sin trazo ni fondo de
      // color, solo se levanta con una sombra gris leve.
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        transform: Matrix4.translationValues(0, seleccionado ? -2 : 0, 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? Colors.transparent : Colors.grey.shade200,
          ),
          boxShadow: seleccionado
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera con el color del estado, suave, como una franja.
            Container(
              color: colorEstado.withValues(alpha: 0.1),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // El número va primero, con grosor.
                      Text(
                        '#${p.numeroPedido}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      // La etiqueta de estado llena el resto de la fila y se pega a
                      // la esquina derecha.
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (p.estado == 'pagado' || _esCobrado(p))
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
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // El tipo de pedido (Mesa, Para llevar, Delivery) con su color.
                      Flexible(child: _tipoDePedido(p)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Solo la hora del pedido.
                  Text(
                    _hora(p.fechaPedido),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: tenue,
                    ),
                  ),
                  // Mozo que atiende el pedido (el de esa mesa).
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.user,
                        size: 14,
                        color: Colors.grey.shade800,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Mozo: ${nombreMeseroDe(p)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // En un pedido de empleado o de familia el nombre ya va en la
                  // franja: aquí solo queda la nota, sin la línea "Cliente: ...".
                  if (_nombreEnEtiqueta(p) &&
                      notaGeneralDe(p.notas) != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      notaGeneralDe(p.notas)!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (cliente != null)
              Container(
                color: colorEstado,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: Text(
                  cliente,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 10),
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            esPedidoDeFamilia(p.id) &&
                                    totalDePedido(p.id).abs() < 0.005
                                ? 'Cuenta de familia'
                                : 'S/ ${totalDePedido(p.id).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
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
                          child: Icon(
                            LucideIcons.wallet,
                            size: 15,
                            color: tenue,
                          ),
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

// Vista de la cola de pedidos (una pestaña): qué pedidos muestra.
class _VistaCola {
  final String id;
  final String nombre;
  // 'clientes' | 'empleados' | 'todos'
  final String filtro;

  const _VistaCola({
    required this.id,
    required this.nombre,
    required this.filtro,
  });
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';

import '../widgets/dialogo_app.dart';

import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/cierres_store.dart';
import '../data/configuracion_store.dart';
import '../data/movimientos_caja_store.dart';
import '../data/pagos_store.dart';
import '../services/caja_service.dart';
import '../services/movimiento_caja_service.dart';
import '../services/pago_service.dart';
import '../data/pedidos_store.dart';
import '../models/caja_servidor.dart';
import '../models/app_role.dart';
import '../models/cierre_caja.dart';
import '../models/movimiento_caja.dart';
import '../models/usuario.dart';
import '../models/pedido.dart';
import '../models/turno.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../widgets/app_search_field.dart';
import '../widgets/etiqueta_tipo_pedido.dart';
import '../widgets/app_tag.dart';
import '../widgets/app_toast.dart';
import '../widgets/comprobante_en_cobro.dart';
import '../widgets/comprobantes_caja_panel.dart';
import '../widgets/detalle_pedido_panel.dart';
import '../widgets/emitir_comprobante_dialog.dart';
import '../widgets/movimiento_caja_dialog.dart';
import '../widgets/app_select.dart';
import '../widgets/selector_dia.dart';
import '../widgets/selector_rango_fechas.dart';
import '../widgets/tabla_app.dart';
import '../widgets/categorias_movimiento_dialog.dart';
import '../widgets/campo_texto.dart';
import '../widgets/descargo_pago_dialog.dart';

// Historial de pedidos y Caja: vistas individuales (ver nav_items.dart).

// Mozo que tomó el pedido, con el nombre que manda el servidor.
String _mozoDe(Pedido p) =>
    (p.mozoNombre != null && p.mozoNombre!.trim().isNotEmpty)
    ? p.mozoNombre!
    : '—';

String _fecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _soles(double v) => 'S/ ${v.toStringAsFixed(2)}';

BoxDecoration get _panel => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: Colors.grey.shade200),
);

// ---------------------------------------------------------------------------
// Historial de pedidos
// ---------------------------------------------------------------------------

class HistorialPedidosScreen extends StatefulWidget {
  final Usuario usuario;

  const HistorialPedidosScreen({super.key, required this.usuario});

  @override
  State<HistorialPedidosScreen> createState() => _HistorialPedidosScreenState();
}

class _HistorialPedidosScreenState extends State<HistorialPedidosScreen> {
  final _busqueda = TextEditingController();
  String _filtro = 'todos'; // todos | pagados | por_cobrar
  String _medioFiltro = 'todos'; // nombre del medio de pago, o 'todos'
  String _tipoFiltro = 'todos'; // todos | mesa | llevar | delivery
  String _mozoFiltro = 'todos'; // id del mozo, o 'todos'
  // Día de los pedidos mostrados (por defecto, hoy); se cambia con las flechas
  // o el calendario.
  DateTimeRange? _rango = DateTimeRange(
    start: DateUtils.dateOnly(DateTime.now()),
    end: DateUtils.dateOnly(DateTime.now()),
  );

  @override
  void initState() {
    super.initState();
    _cargarPagos();
  }

  // Si no se pudieron leer los pagos del servidor, aquí va el motivo: sin ellos
  // la tabla no puede mostrar la fecha ni el método de pago.
  String? _errorPagos;

  // Los pagos viven en el servidor: se traen los del rango elegido.
  Future<void> _cargarPagos() async {
    final r = _rango;
    String? error;
    try {
      if (r == null) {
        await PagoService.instance.cargarDelDia();
      } else {
        await PagoService.instance.cargarDelRango(r.start, r.end);
      }
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
    }
    if (mounted) setState(() => _errorPagos = error);
  }

  void _cambiarRango(DateTimeRange? r) {
    setState(() => _rango = r);
    _cargarPagos();
  }

  // Fecha y hora del último pago del pedido (null si aún no se cobró nada).
  DateTime? _fechaPago(Pedido p) {
    DateTime? ultima;
    for (final x in pagos) {
      if (x.pedidoId != p.id || x.esReembolso) continue;
      if (ultima == null || x.fechaPago.isAfter(ultima)) ultima = x.fechaPago;
    }
    return ultima;
  }

  // El día se filtra por la fecha del pago; un pedido sin cobrar todavía se
  // ubica por la fecha en que se tomó.
  bool _enRango(Pedido p) {
    final r = _rango;
    if (r == null) return true;
    final d = DateUtils.dateOnly(_fechaPago(p) ?? p.fechaPedido);
    return !d.isBefore(DateUtils.dateOnly(r.start)) &&
        !d.isAfter(DateUtils.dateOnly(r.end));
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  // Estado de pago del pedido según sus cobros.
  String _estadoPago(Pedido p) {
    if (p.estado == 'anulado') return 'Anulado';
    if (p.estado == 'pagado') return 'Pagado';
    final hayPagos = pagos.any((x) => x.pedidoId == p.id);
    if (hayPagos &&
        totalDePedido(p.id) > 0 &&
        saldoPendienteDePedido(p.id) <= 0.01) {
      return 'Pagado';
    }
    return hayPagos ? 'Parcial' : 'Por cobrar';
  }

  // Nombres de los medios de pago para el filtro (los activos y los usados).
  List<String> get _nombresMedios => <String>{
    for (final m in mediosPagoActivos) m.medioPago,
    for (final p in pagos) p.medioPago.medioPago,
  }.toList()..sort();

  // Mozos que tomaron pedidos, para el filtro (id y nombre).
  List<({String id, String nombre})> get _mozos {
    final porId = <String, String>{};
    for (final p in pedidos) {
      final id = p.usuarioId;
      if (id != null) porId.putIfAbsent(id, () => _mozoDe(p));
    }
    return [for (final e in porId.entries) (id: e.key, nombre: e.value)]
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
  }

  String _metodos(Pedido p) {
    final pagosPedido = pagos
        .where(
          (x) => x.pedidoId == p.id && !x.esReembolso && x.estado != 'anulado',
        )
        .toList();
    if (pagosPedido.isEmpty) return '—';

    // Agrupar por medio de pago y sumar montos cobrados
    final mapa = <String, double>{};
    for (final x in pagosPedido) {
      final nombre = x.medioPago.medioPago;
      mapa[nombre] = (mapa[nombre] ?? 0.0) + x.montoCobrado;
    }

    return mapa.entries
        .map((e) => '${e.key}: S/ ${e.value.toStringAsFixed(2)}')
        .join(', ');
  }

  List<Pedido> get _filas {
    final t = _busqueda.text.trim().toLowerCase();
    return pedidos.where((p) {
      if (!_enRango(p)) return false;
      if (_medioFiltro != 'todos' &&
          !mediosDePagoDe(p.id).contains(_medioFiltro)) {
        return false;
      }
      // Mesa es todo lo que no es delivery ni para llevar (Mesa 2, Mesa 19...).
      if (_tipoFiltro != 'todos') {
        final tipo = switch (p.tipoPedido) {
          'delivery' => 'delivery',
          'llevar' => 'llevar',
          _ => 'mesa',
        };
        if (tipo != _tipoFiltro) return false;
      }
      if (_mozoFiltro != 'todos' && p.usuarioId != _mozoFiltro) return false;
      final ep = _estadoPago(p);
      if (_filtro == 'pagados' && ep != 'Pagado') return false;
      if (_filtro == 'por_cobrar' && ep != 'Por cobrar' && ep != 'Parcial') {
        return false;
      }
      if (t.isEmpty) return true;
      return p.numeroPedido.contains(t) ||
          (p.clienteNombre?.toLowerCase().contains(t) ?? false) ||
          _mozoDe(p).toLowerCase().contains(t);
    }).toList();
  }

  // Cobrar usa el mismo detalle que Pedidos (Pagar / Pago compartido), en un
  // modal que se cierra solo cuando el pedido queda pagado o cancelado.
  Future<void> _cobrar(Pedido p) async {
    await showBlurDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogo) {
          final actual = _pedidoPorId(p.id) ?? p;
          final ancho = MediaQuery.sizeOf(context);
          return Material(
            color: Colors.transparent,
            child: SizedBox(
              width: AppBreakpoints.esMobile(context) ? ancho.width : 440,
              height: ancho.height * 0.9,
              child: DetallePedidoPanel(
                key: ValueKey('cobro-${p.id}'),
                pedido: actual,
                esAdmin: widget.usuario.rol == AppRole.administrador,
                onVolver: () => Navigator.of(dialogContext).pop(),
                onCambio: () {
                  setDialogo(() {});
                  setState(() {});
                  final estado = (_pedidoPorId(p.id) ?? p).estado;
                  if (estado == 'pagado' || estado == 'anulado') {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    });
                  }
                },
              ),
            ),
          );
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Pedido? _pedidoPorId(String id) {
    for (final x in pedidos) {
      if (x.id == id) return x;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final filas = _filas;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: _panel,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, c) {
                  const titulo = Text(
                    'Historial de ventas',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  );
                  final controles = [
                    _pastilla('Todos', 'todos'),
                    _pastilla('Pagados', 'pagados'),
                    _pastilla('Por cobrar', 'por_cobrar'),
                    SelectorDia(
                      dia: _rango?.start ?? DateTime.now(),
                      onChanged: (d) =>
                          _cambiarRango(DateTimeRange(start: d, end: d)),
                    ),
                    SizedBox(
                      width: 220,
                      child: AppSelect<String>(
                        compacto: true,
                        value: _medioFiltro,
                        hint: 'Medio de pago',
                        items: [
                          const AppSelectItem(
                            value: 'todos',
                            label: 'Todos los medios de pago',
                          ),
                          for (final n in _nombresMedios)
                            AppSelectItem(value: n, label: n),
                        ],
                        onChanged: (v) =>
                            setState(() => _medioFiltro = v ?? 'todos'),
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: AppSelect<String>(
                        compacto: true,
                        value: _tipoFiltro,
                        hint: 'Tipo de pedido',
                        items: const [
                          AppSelectItem(
                            value: 'todos',
                            label: 'Todos los tipos',
                          ),
                          AppSelectItem(value: 'mesa', label: 'Mesa'),
                          AppSelectItem(value: 'llevar', label: 'Para llevar'),
                          AppSelectItem(value: 'delivery', label: 'Delivery'),
                        ],
                        onChanged: (v) =>
                            setState(() => _tipoFiltro = v ?? 'todos'),
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: AppSelect<String>(
                        compacto: true,
                        value: _mozoFiltro,
                        hint: 'Mozo',
                        items: [
                          const AppSelectItem(
                            value: 'todos',
                            label: 'Todos los mozos',
                          ),
                          for (final m in _mozos)
                            AppSelectItem(value: m.id, label: m.nombre),
                        ],
                        onChanged: (v) =>
                            setState(() => _mozoFiltro = v ?? 'todos'),
                      ),
                    ),
                    AppSearchField(
                      controller: _busqueda,
                      hint: 'Buscar pedido o cliente...',
                      onChanged: (_) => setState(() {}),
                    ),
                  ];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titulo,
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: controles),
                    ],
                  );
                },
              ),
              if (_errorPagos != null) ...[
                const SizedBox(height: 8),
                Text(
                  'No se pudieron leer los pagos del servidor: $_errorPagos',
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: filas.isEmpty
                    ? Center(
                        child: Text(
                          'Sin pedidos',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : SingleChildScrollView(child: _tabla(filas)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pastilla(String etiqueta, String valor) {
    return AppTag(
      etiqueta: etiqueta,
      activo: _filtro == valor,
      onTap: () => setState(() => _filtro = valor),
    );
  }

  // Boleta, factura o ticket de venta de un pedido: también después de cobrarlo,
  // por si el cliente lo pide más tarde.
  Future<void> _emitirComprobante(Pedido p) async {
    await emitirComprobanteDePedido(context, p);
    if (mounted) setState(() {});
  }

  Widget _botonAccion(
    String tooltip,
    IconData icono,
    Color color,
    VoidCallback onTap,
  ) => Tooltip(
    message: tooltip,
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Icon(icono, size: 15, color: color),
      ),
    ),
  );

  Widget _acciones(Pedido p) {
    final estado = _estadoPago(p);
    final botones = [
      // Reimprimir la cuenta o la comanda, las veces que haga falta.
      _botonAccion(
        'Reimprimir cuenta o comanda',
        LucideIcons.printer,
        Colors.black87,
        () => mostrarTicketDelPedido(context, p),
      ),
      if (estado != 'Pagado' && estado != 'Anulado')
        _botonAccion(
          'Cobrar',
          LucideIcons.wallet,
          AppColors.primaryGreen,
          () => _cobrar(p),
        ),
      if (estado != 'Anulado' && puedeElegirComprobante(p))
        _botonAccion(
          'Emitir comprobante',
          LucideIcons.fileCheck,
          Colors.black87,
          () => _emitirComprobante(p),
        ),
    ];
    if (botones.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < botones.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          botones[i],
        ],
      ],
    );
  }

  Widget _tabla(List<Pedido> filas) {
    return TablaApp<Pedido>(
      porPagina: 8,
      filas: filas,
      columnas: [
        ColumnaTabla(
          titulo: 'Fecha de pago',
          ancho: 150,
          ordenarPor: (p) => _fechaPago(p) ?? DateTime(1970),
          celda: (p) {
            final f = _fechaPago(p);
            // Un pedido ya pagado sin pagos cargados no es "sin pago": falta leerlos.
            return TablaApp.texto(
              f != null
                  ? _fecha(f)
                  : (p.estado == 'pagado'
                        ? 'Pagado · sin fecha'
                        : '— (sin pago)'),
            );
          },
        ),
        ColumnaTabla(
          titulo: 'Tipo',
          ancho: 150,
          rol: RolTarjeta.titulo,
          ordenarPor: (p) => p.ubicacion,
          celda: (p) => Align(
            alignment: Alignment.centerLeft,
            child: EtiquetaTipoPedido(pedido: p, tamano: 13),
          ),
        ),
        ColumnaTabla(
          titulo: 'Mozo',
          flex: 1,
          ordenarPor: (p) => _mozoDe(p).toLowerCase(),
          celda: (p) => TablaApp.texto(_mozoDe(p)),
        ),
        ColumnaTabla(
          titulo: 'Total',
          ancho: 100,
          ordenarPor: (p) => totalCobradoDePedido(p.id),
          celda: (p) => TablaApp.texto(_soles(totalCobradoDePedido(p.id))),
        ),
        ColumnaTabla(
          titulo: 'Método de pago',
          flex: 1.3,
          anchoMin: 150,
          celda: (p) => Tooltip(
            message: _metodos(p),
            child: Text(
              _metodos(p),
              softWrap: true,
              style: TablaApp.estiloTexto,
            ),
          ),
        ),
        ColumnaTabla(
          titulo: 'Acciones',
          ancho: 150,
          rol: RolTarjeta.acciones,
          celda: (p) => _acciones(p),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cajas
// ---------------------------------------------------------------------------

class CajaScreen extends StatefulWidget {
  final Usuario usuario;

  const CajaScreen({super.key, required this.usuario});

  @override
  State<CajaScreen> createState() => _CajaScreenState();
}

class _CajaScreenState extends State<CajaScreen> {
  // Rango de fechas de los cierres mostrados (null = todos).
  DateTimeRange? _rangoCierres;

  // Filtros de movimientos de caja
  TipoMovimiento? _filtroTipoMovimiento;
  String? _filtroCategoriaId;

  // Si no se pudieron traer los movimientos del servidor, aquí va el motivo.
  String? _errorMovimientos;
  // Si no se pudo leer la caja del servidor, aquí va el motivo.
  String? _errorCaja;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // Trae lo que vive en el servidor: los cobros del día y los ingresos y
  // salidas de la caja actual.
  Future<void> _cargar() async {
    try {
      await PagoService.instance.cargarDelDia();
    } catch (_) {}
    if (mounted) setState(() {});
    if (CajaService.instance.enServidor) {
      try {
        await CajaService.instance.cargarEstado();
        await CajaService.instance.cargarCierres();
        if (mounted) setState(() => _errorCaja = null);
      } catch (e) {
        if (mounted) setState(() => _errorCaja = e.toString());
      }
    }
    try {
      try {
        await MovimientoCajaService.instance.cargarCategorias();
      } catch (_) {
        // Sin categorías del servidor se usan las de partida.
      }
      await MovimientoCajaService.instance.cargarDelTurno(inicioCajaActual);
      if (mounted) setState(() => _errorMovimientos = null);
    } catch (e) {
      if (mounted) setState(() => _errorMovimientos = e.toString());
    }
  }

  // Vuelve a pedir al servidor los totales de la caja, cobros y movimientos en tiempo real.
  Future<void> _refrescarCaja() async {
    await _cargar();
  }

  bool get _cajaCerrada =>
      estadoCajaServidor != null && !estadoCajaServidor!.abierta;

  Future<void> _abrirCaja() async {
    List<Turno> turnos = [];
    try {
      turnos = await CajaService.instance.cargarTurnos();
    } catch (_) {}

    final r =
        await showBlurDialog<
          ({double montoInicial, String? turnoId, String? notas})
        >(
          context: context,
          builder: (dialogContext) => _AbrirCajaDialog(turnos: turnos),
        );
    if (r == null || !mounted) return;
    try {
      await CajaService.instance.abrir(
        montoInicial: r.montoInicial,
        turnoId: r.turnoId,
        notas: r.notas,
      );
      if (!mounted) return;
      setState(() {});
      showAppToast(
        context,
        'La caja está abierta.',
        type: ToastType.success,
        titulo: 'Caja abierta',
      );
      _cargar();
    } catch (e) {
      if (mounted) showAppToast(context, e.toString(), type: ToastType.error);
    }
  }

  Future<void> _traspasoCaja() async {
    final notasCtrl = TextEditingController();
    List<Map<String, dynamic>> usuarios = [];
    try {
      final res = await ApiClient.instance.get('/api/v1/usuarios');
      if (res is List) {
        usuarios = res.whereType<Map<String, dynamic>>().where((u) {
          final rol = (u['rol'] ?? '').toString().toUpperCase();
          final activo = u['activo'] == true || u['estado'] == true;
          return activo && (rol.contains('ADMIN') || rol.contains('CAJ'));
        }).toList();
      }
    } catch (_) {}

    String? nuevoUsuarioId = usuarios.firstOrNull?['id']?.toString();

    final confirmar = await showBlurDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertaApp(
          title: const Text('Traspaso de Responsable de Caja'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transfiere la posesión de la caja activa a otro administrador o cajero sin cerrar la sesión ni afectar el cuadre.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
                if (usuarios.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: nuevoUsuarioId,
                    decoration: const InputDecoration(
                      labelText: 'Nuevo responsable',
                    ),
                    items: [
                      for (final u in usuarios)
                        DropdownMenuItem(
                          value: u['id']?.toString(),
                          child: Text(
                            '${u['nombre'] ?? u['usuario']} (${u['rol']})',
                          ),
                        ),
                    ],
                    onChanged: (val) => setDlgState(() => nuevoUsuarioId = val),
                  )
                else
                  const Text(
                    'No se encontraron otros usuarios cajeros o administradores activos.',
                  ),
                const SizedBox(height: 12),
                CampoTexto(
                  controller: notasCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Motivo / Observaciones (opcional)',
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
              onPressed: nuevoUsuarioId == null
                  ? null
                  : () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Efectuar Traspaso'),
            ),
          ],
        ),
      ),
    );

    if (confirmar != true || nuevoUsuarioId == null || !mounted) return;

    try {
      await CajaService.instance.traspaso(
        nuevoUsuarioId: nuevoUsuarioId!,
        notas: notasCtrl.text.trim(),
      );
      if (mounted) {
        showAppToast(
          context,
          'Traspaso de caja efectuado con éxito.',
          type: ToastType.success,
        );
        _cargar();
      }
    } catch (e) {
      if (mounted) showAppToast(context, e.toString(), type: ToastType.error);
    }
  }

  Future<void> _imprimirReporteTurno({String? cierreId}) async {
    try {
      showAppToast(
        context,
        'Enviando resumen de turno a la impresora...',
        type: ToastType.info,
      );
      await CajaService.instance.imprimirReporteTurno(cierreId: cierreId);
      if (mounted) {
        showAppToast(
          context,
          'Resumen de turno impreso con éxito.',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted)
        showAppToast(context, 'Error al imprimir: $e', type: ToastType.error);
    }
  }

  Future<void> _imprimirReporteDiaConsolidado({String? fechaOperativa}) async {
    try {
      showAppToast(
        context,
        'Enviando consolidado del día a la impresora...',
        type: ToastType.info,
      );
      await CajaService.instance.imprimirReporteDiaConsolidado(
        fechaOperativa: fechaOperativa,
      );
      if (mounted) {
        showAppToast(
          context,
          'Consolidado del día impreso con éxito.',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted)
        showAppToast(context, 'Error al imprimir: $e', type: ToastType.error);
    }
  }

  Future<void> _abrirReporteDiaDetallado({
    String? fechaOperativa,
    String? cierreId,
  }) async {
    final url = CajaService.instance.urlReporteDiaDetalladoHTML(
      fechaOperativa: fechaOperativa,
      cierreId: cierreId,
    );
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted)
          showAppToast(
            context,
            'No se pudo abrir el navegador: $url',
            type: ToastType.error,
          );
      }
    } catch (e) {
      if (mounted) showAppToast(context, e.toString(), type: ToastType.error);
    }
  }

  Future<void> _reportesDeOtraFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    final fStr = picked.toIso8601String().split('T')[0];

    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reportes del día: $fStr',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(LucideIcons.printer, color: Colors.green),
              title: const Text('Imprimir Consolidado del Día (Ticket)'),
              subtitle: const Text('Desglose de turnos y métodos de pago'),
              onTap: () {
                Navigator.pop(ctx);
                _imprimirReporteDiaConsolidado(fechaOperativa: fStr);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.fileText, color: Colors.purple),
              title: const Text(
                'Ver / Descargar Súper Reporte Detallado (PDF/HTML)',
              ),
              subtitle: const Text(
                'Pedidos, mesas, mozos, anulaciones y rectificaciones',
              ),
              onTap: () {
                Navigator.pop(ctx);
                _abrirReporteDiaDetallado(fechaOperativa: fStr);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Cierre con el servidor: solo se declara el efectivo contado en caja y se valida cuadre exacto.
  Future<void> _cerrarCajaServidor() async {
    final srvTotales = estadoCajaServidor?.totales;
    final r = await showBlurDialog<({double declaradoEfectivo, String? notas})>(
      context: context,
      builder: (dialogContext) => _CerrarCajaDialog(
        efectivoEsperado: srvTotales?.efectivoEsperado ?? 0,
        turnoNombre: estadoCajaServidor?.apertura?.turnoNombre,
      ),
    );
    if (r == null || !mounted) return;
    try {
      await CajaService.instance.cerrar(
        declaradoEfectivo: r.declaradoEfectivo,
        declaradoTarjeta: srvTotales?.tarjeta ?? 0,
        declaradoDigital: srvTotales?.digital ?? 0,
        notas: r.notas,
      );
      if (!mounted) return;
      setState(() {});
      showAppToast(
        context,
        'La caja se cerró exitosamente. Para el siguiente turno, ábrela de nuevo.',
        type: ToastType.success,
        titulo: 'Caja cerrada',
      );
      _cargar();
    } catch (e) {
      if (mounted) showAppToast(context, e.toString(), type: ToastType.error);
    }
  }

  Future<void> _registrar(TipoMovimiento tipo) async {
    final r = await showBlurDialog<MovimientoNuevo>(
      context: context,
      builder: (_) => MovimientoCajaDialog(tipo: tipo),
    );
    if (r == null || !mounted) return;
    try {
      await MovimientoCajaService.instance.registrar(
        categoria: r.categoria,
        monto: r.monto,
        medio: r.medio,
        nota: r.nota,
      );
      if (!mounted) return;
      setState(() {});
      showAppToast(
        context,
        '${tipo.etiqueta} de ${_soles(r.monto)} registrado en ${r.medio.medioPago}.',
        type: ToastType.success,
      );
      await _refrescarCaja();
    } catch (e) {
      if (mounted) showAppToast(context, e.toString(), type: ToastType.error);
    }
  }

  Future<void> _descargo(MovimientoCaja m) async {
    final r = await showBlurDialog<bool>(
      context: context,
      builder: (_) => DescargoPagoDialog(movimiento: m),
    );
    if (r == true && mounted) {
      showAppToast(
        context,
        'Descargo aplicado correctamente. Movimiento de caja y pago actualizados.',
        type: ToastType.success,
      );
      await _refrescarCaja();
    }
  }

  Future<void> _editar(MovimientoCaja m) async {
    final r = await showBlurDialog<MovimientoNuevo>(
      context: context,
      builder: (_) => MovimientoCajaDialog(tipo: m.tipo, existente: m),
    );
    if (r == null || !mounted) return;
    try {
      await MovimientoCajaService.instance.editar(
        m,
        categoria: r.categoria,
        monto: r.monto,
        medio: r.medio,
        nota: r.nota,
      );
      if (!mounted) return;
      showAppToast(context, 'Movimiento corregido.', type: ToastType.success);
      await _refrescarCaja();
    } catch (e) {
      if (mounted) showAppToast(context, e.toString(), type: ToastType.error);
    }
  }

  Future<void> _administrarCategorias() async {
    await showBlurDialog(
      context: context,
      builder: (_) => const CategoriasMovimientoDialog(),
    );
    if (mounted) setState(() {});
  }

  Future<void> _anular(MovimientoCaja m) async {
    final motivo = await showBlurDialog<String>(
      context: context,
      builder: (_) => AnularMovimientoDialog(movimiento: m),
    );
    if (motivo == null || !mounted) return;
    try {
      await MovimientoCajaService.instance.anular(m, motivo: motivo);
      if (!mounted) return;
      showAppToast(context, 'Movimiento anulado.', type: ToastType.success);
      await _refrescarCaja();
    } catch (e) {
      if (mounted) showAppToast(context, e.toString(), type: ToastType.error);
    }
  }

  Future<void> _cerrarCaja() async {
    if (CajaService.instance.enServidor && estadoCajaServidor != null) {
      await _cerrarCajaServidor();
      return;
    }
    final inicial = TextEditingController(text: '0');
    final efectivo = TextEditingController();
    final tarjeta = TextEditingController();
    final digital = TextEditingController();
    final notas = TextEditingController();

    double n(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;
    final confirmar = await showBlurDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertaApp(
        title: const Text('Cerrar caja'),
        content: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuenta el dinero de la caja y escribe lo que hay.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
                _campoDialogo(inicial, 'Monto inicial (S/)'),
                _campoDialogo(efectivo, 'Efectivo declarado (S/)'),
                _campoDialogo(tarjeta, 'Tarjeta declarada (S/)'),
                _campoDialogo(digital, 'Digital declarado (S/)'),
                CampoTexto(
                  controller: notas,
                  decoration: const InputDecoration(labelText: 'Notas'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cerrar caja'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    registrarCierreCaja(
      usuarioId: widget.usuario.id,
      montoInicial: n(inicial),
      declaradoEfectivo: n(efectivo),
      declaradoTarjeta: n(tarjeta),
      declaradoDigital: n(digital),
      notas: notas.text.trim().isEmpty ? null : notas.text.trim(),
    );
    setState(() {});
    showAppToast(
      context,
      'La caja se cerró y empieza una nueva.',
      type: ToastType.success,
      titulo: 'Caja cerrada',
    );
    // La caja nueva empieza vacía: se vuelve a leer lo que haya del servidor.
    _cargar();
  }

  Widget _campoDialogo(TextEditingController c, String etiqueta) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: CampoTexto(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: etiqueta),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = totalesCajaActual();
    final desde = inicioCajaActual;
    final resumen = resumenPorMedio(desde);
    final extra = totalesMovimientos(desde);
    final srv = estadoCajaServidor?.totales;
    final filas = _cajaCerrada
        ? <FilaResumenMedio>[]
        : (srv?.porMedio ?? resumen);
    final ventas = _cajaCerrada
        ? 0.0
        : (srv?.ventas ?? resumen.fold<double>(0.0, (s, f) => s + f.ventas));
    final ingresos = _cajaCerrada ? 0.0 : (srv?.ingresos ?? extra.ingresos);
    final salidas = _cajaCerrada ? 0.0 : (srv?.salidas ?? extra.egresos);
    final numPedidos = _cajaCerrada ? 0 : (srv?.numPedidos ?? t.pedidos);
    final movimientos = _cajaCerrada
        ? <MovimientoCaja>[]
        : movimientosDesde(desde);
    final rangoCierres = _rangoCierres;
    final cierres = rangoCierres == null
        ? cierresCaja
        : [
            for (final c in cierresCaja)
              if (!DateUtils.dateOnly(c.fechaCierre)
                      .isBefore(DateUtils.dateOnly(rangoCierres.start)) &&
                  !DateUtils.dateOnly(c.fechaCierre)
                      .isAfter(DateUtils.dateOnly(rangoCierres.end)))
                c,
          ];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_cajaCerrada) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.naranja.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.lockOpen, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'La caja está cerrada. Ábrela con el monto inicial para '
                        'empezar el turno.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: _abrirCaja,
                      child: const Text('Abrir caja'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_errorCaja != null) ...[
              Text(
                'No se pudo leer la caja del servidor: $_errorCaja',
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              decoration: _panel,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Caja actual',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _cajaCerrada
                                  ? 'No hay turno activo actualmente'
                                  : '${estadoCajaServidor?.apertura?.turnoNombre ?? 'Turno'} · Desde ${_fecha(desde)} · $numPedidos pedido(s) cobrado(s)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (!_cajaCerrada && CajaService.instance.enServidor)
                            OutlinedButton.icon(
                              onPressed: _traspasoCaja,
                              icon: const Icon(LucideIcons.userCheck, size: 16),
                              label: const Text('Traspaso de Caja'),
                            ),
                          if (CajaService.instance.enServidor)
                            PopupMenuButton<String>(
                              tooltip: 'Reportes de Caja',
                              constraints: const BoxConstraints(
                                minWidth: 220,
                                maxWidth: 260,
                              ),
                              onSelected: (val) {
                                if (val == 'turno') _imprimirReporteTurno();
                                if (val == 'dia_print')
                                  _imprimirReporteDiaConsolidado();
                                if (val == 'dia_pdf')
                                  _abrirReporteDiaDetallado();
                                if (val == 'otra_fecha') _reportesDeOtraFecha();
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'turno',
                                  child: Row(
                                    children: [
                                      Icon(
                                        LucideIcons.printer,
                                        size: 16,
                                        color: Colors.blue,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '1. Resumen Turno (Ticket)',
                                          style: TextStyle(fontSize: 12.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'dia_print',
                                  child: Row(
                                    children: [
                                      Icon(
                                        LucideIcons.receipt,
                                        size: 16,
                                        color: Colors.green,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '2. Consolidado Día (Ticket)',
                                          style: TextStyle(fontSize: 12.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'dia_pdf',
                                  child: Row(
                                    children: [
                                      Icon(
                                        LucideIcons.fileText,
                                        size: 16,
                                        color: Colors.purple,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '3. Detallado Día (PDF/HTML)',
                                          style: TextStyle(fontSize: 12.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'otra_fecha',
                                  child: Row(
                                    children: [
                                      Icon(
                                        LucideIcons.calendar,
                                        size: 16,
                                        color: Colors.orange,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '4. Reportes de otra fecha...',
                                          style: TextStyle(fontSize: 12.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      LucideIcons.barChart2,
                                      size: 16,
                                      color: AppColors.primaryGreen,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Reportes ▾',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          FilledButton.icon(
                            onPressed: _cajaCerrada ? null : _cerrarCaja,
                            icon: const Icon(LucideIcons.lock, size: 16),
                            label: const Text('Cerrar caja'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _tarjetasCaja(
                    apertura: estadoCajaServidor?.apertura,
                    filas: filas,
                    ventas: ventas,
                    delivery: srv?.delivery ?? 0,
                    numPedidos: numPedidos,
                    ingresos: ingresos,
                    salidas: salidas,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Por medio de pago (desglosado por grupo y variante)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  _tablaMediosAgrupados(filas),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Ingresos y salidas, y comprobantes de hoy, en la misma fila (uno
            // debajo del otro si no caben).
            LayoutBuilder(
              builder: (context, c) {
                final panelMov = _panelMovimientos(movimientos);
                if (!CajaService.instance.enServidor) return panelMov;
                const comprobantes = ComprobantesCajaPanel();
                if (c.maxWidth < 900) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      panelMov,
                      const SizedBox(height: 16),
                      comprobantes,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: panelMov),
                    const SizedBox(width: 16),
                    const Expanded(child: comprobantes),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Container(
              decoration: _panel,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Cierres de caja',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SelectorRangoFechas(
                        valor: _rangoCierres,
                        permiteTodas: true,
                        onChanged: (r) => setState(() => _rangoCierres = r),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (cierres.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          cierresCaja.isEmpty
                              ? 'Aún no hay cierres de caja'
                              : 'No hay cierres de caja en ese rango de fechas',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    )
                  else
                    TablaApp<CierreCaja>(
                      porPagina: 10,
                      filas: cierres,
                      columnas: _columnasCierres(),
                      // En el celular, la tarjeta muestra lo principal y al
                      // tocarla se ve el cierre completo.
                      onTarjeta: _verCierreCompleto,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tablaMediosAgrupados(List<FilaResumenMedio> filas) {
    if (filas.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        child: Text(
          _cajaCerrada
              ? 'Caja cerrada · No hay movimientos en este turno'
              : 'Sin métodos de pago registrados',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    final grupos = <String, List<FilaResumenMedio>>{
      'efectivo': [],
      'tarjeta': [],
      'digital': [],
    };

    for (final f in filas) {
      final g = f.grupo.toLowerCase();
      final m = f.medio.toLowerCase();
      if (g == 'efectivo' || m.contains('efectivo')) {
        grupos['efectivo']!.add(f);
      } else if (g == 'digital' || m.contains('yape') || m.contains('plin')) {
        grupos['digital']!.add(f);
      } else {
        grupos['tarjeta']!.add(f);
      }
    }

    final titulosGrupos = {
      'efectivo': (
        'EFECTIVO',
        LucideIcons.dollarSign,
        const Color(0xFF16A34A),
        const Color(0xFFEFFBEF),
      ),
      'tarjeta': (
        'TARJETAS / POS',
        LucideIcons.creditCard,
        const Color(0xFF3B82F6),
        const Color(0xFFEFF6FF),
      ),
      'digital': (
        'YAPE / PLIN / BILLETERAS',
        LucideIcons.smartphone,
        const Color(0xFFD946EF),
        const Color(0xFFFCEBFD),
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in grupos.entries)
          if (entry.value.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: titulosGrupos[entry.key]!.$4,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: titulosGrupos[entry.key]!.$3.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    titulosGrupos[entry.key]!.$2,
                    size: 16,
                    color: titulosGrupos[entry.key]!.$3,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    titulosGrupos[entry.key]!.$1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: titulosGrupos[entry.key]!.$3,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Subtotal Ventas: ${_soles(entry.value.fold(0.0, (s, it) => s + it.ventas))} | Neto: ${_soles(entry.value.fold(0.0, (s, it) => s + it.neto))}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: titulosGrupos[entry.key]!.$3,
                    ),
                  ),
                ],
              ),
            ),
            TablaApp<FilaResumenMedio>(
              porPagina: 10,
              filas: entry.value,
              columnas: [
                ColumnaTabla(
                  titulo: 'Variante / Medio',
                  flex: 1.5,
                  ordenarPor: (f) => f.medio.toLowerCase(),
                  celda: (f) => TablaApp.texto(f.medio, fuerte: true),
                ),
                ColumnaTabla(
                  titulo: 'Ventas',
                  ordenarPor: (f) => f.ventas,
                  celda: (f) => TablaApp.texto(_soles(f.ventas)),
                ),
                ColumnaTabla(
                  titulo: 'Ingresos',
                  ordenarPor: (f) => f.ingresos,
                  celda: (f) => TablaApp.texto(_soles(f.ingresos)),
                ),
                ColumnaTabla(
                  titulo: 'Salidas',
                  ordenarPor: (f) => f.egresos,
                  celda: (f) => TablaApp.texto(_soles(f.egresos)),
                ),
                ColumnaTabla(
                  titulo: 'Neto',
                  ordenarPor: (f) => f.neto,
                  celda: (f) => TablaApp.texto(_soles(f.neto), fuerte: true),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  // Ingresos y salidas de la caja actual, con los botones para registrarlos y filtros por tipo/categoría.
  Widget _panelMovimientos(List<MovimientoCaja> movimientos) {
    final catActivas = _filtroTipoMovimiento == null
        ? categoriasMovimiento
        : categoriasDeTipo(_filtroTipoMovimiento!);

    final movimientosFiltrados = movimientos.where((m) {
      if (_filtroTipoMovimiento != null && m.tipo != _filtroTipoMovimiento) {
        return false;
      }
      if (_filtroCategoriaId != null && m.categoriaId != _filtroCategoriaId) {
        return false;
      }
      return true;
    }).toList();

    return Container(
      decoration: _panel,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              const titulo = Text(
                'Ingresos y salidas',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              );
              final angosto = c.maxWidth < 560;
              final botones = Wrap(
                alignment: angosto ? WrapAlignment.start : WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _cajaCerrada
                        ? null
                        : () => _registrar(TipoMovimiento.ingreso),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Ingreso'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _cajaCerrada
                        ? null
                        : () => _registrar(TipoMovimiento.egreso),
                    icon: const Icon(LucideIcons.minus, size: 16),
                    label: const Text('Salida'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _administrarCategorias,
                    icon: const Icon(LucideIcons.tag, size: 16),
                    label: const Text('Categorías'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _cargar,
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: const Text('Actualizar'),
                  ),
                ],
              );
              if (angosto) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titulo, const SizedBox(height: 10), botones],
                );
              }
              return Row(
                children: [
                  titulo,
                  const SizedBox(width: 16),
                  Expanded(child: botones),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          // FILTROS: Tipo y Categoría
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Filtrar:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              ChoiceChip(
                label: const Text('Todos', style: TextStyle(fontSize: 11)),
                selected: _filtroTipoMovimiento == null,
                onSelected: (s) => setState(() {
                  _filtroTipoMovimiento = null;
                  _filtroCategoriaId = null;
                }),
              ),
              ChoiceChip(
                label: const Text('Ingresos', style: TextStyle(fontSize: 11)),
                selected: _filtroTipoMovimiento == TipoMovimiento.ingreso,
                onSelected: (s) => setState(() {
                  _filtroTipoMovimiento = TipoMovimiento.ingreso;
                  _filtroCategoriaId = null;
                }),
              ),
              ChoiceChip(
                label: const Text(
                  'Salidas / Egresos',
                  style: TextStyle(fontSize: 11),
                ),
                selected: _filtroTipoMovimiento == TipoMovimiento.egreso,
                onSelected: (s) => setState(() {
                  _filtroTipoMovimiento = TipoMovimiento.egreso;
                  _filtroCategoriaId = null;
                }),
              ),
              if (catActivas.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _filtroCategoriaId,
                      hint: const Text(
                        'Todas las categorías',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todas las categorías'),
                        ),
                        ...catActivas.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(c.nombre),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _filtroCategoriaId = val),
                    ),
                  ),
                ),
            ],
          ),
          if (_errorMovimientos != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'No se pudieron leer los movimientos del servidor: '
                    '$_errorMovimientos',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  ),
                ),
                TextButton(onPressed: _cargar, child: const Text('Reintentar')),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (_cajaCerrada)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Caja cerrada · Abre la caja para registrar y ver movimientos',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          else if (movimientosFiltrados.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  movimientos.isEmpty
                      ? 'Aún no hay ingresos ni salidas en esta caja'
                      : 'No hay movimientos con los filtros seleccionados',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          else
            // Se ven 4 registros; el resto se desplaza.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: Scrollbar(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final m in movimientosFiltrados) _filaMovimiento(m),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Widget _filaMovimiento(MovimientoCaja m) {
    final esIngreso = m.tipo == TipoMovimiento.ingreso;
    final color = m.anulado
        ? Colors.grey.shade500
        : (esIngreso ? AppColors.primaryGreen : AppColors.error);
    final detalle = [
      _hora(m.fecha),
      if ((m.nota ?? '').isNotEmpty) m.nota!,
      if ((m.registradoPor ?? '').isNotEmpty) 'por ${m.registradoPor}',
    ].join(' · ');
    final puedeCambiar = MovimientoCajaService.edicionDisponible && !m.anulado;
    final tooltipBloqueado = m.anulado
        ? 'Ya está anulado'
        : 'Disponible cuando el servidor lo habilite';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  esIngreso
                      ? LucideIcons.arrowDownLeft
                      : LucideIcons.arrowUpRight,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${m.categoriaNombre} · ${m.medioPagoNombre}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: m.anulado
                                  ? Colors.grey.shade500
                                  : Colors.black87,
                              decoration: m.anulado
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (m.anulado) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              'ANULADO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      detalle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${esIngreso ? '+' : '-'}${_soles(m.monto)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                  decoration: m.anulado ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
          if (m.anulado)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 46),
              child: Text(
                'Anulado${(m.motivoAnulacion ?? '').isNotEmpty ? ': ${m.motivoAnulacion}' : ''}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            )
          else if (m.editado)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 46),
              child: Text(
                'Editado',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 4,
              children: [
                if (m.esCobroPedido) ...[
                  Tooltip(
                    message: puedeCambiar
                        ? 'Rectificar medio de pago (descargo)'
                        : tooltipBloqueado,
                    child: TextButton.icon(
                      onPressed: puedeCambiar ? () => _descargo(m) : null,
                      icon: const Icon(LucideIcons.arrowLeftRight, size: 14),
                      label: const Text('Descargo'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ] else ...[
                  Tooltip(
                    message: puedeCambiar ? '' : tooltipBloqueado,
                    child: TextButton.icon(
                      onPressed: puedeCambiar ? () => _editar(m) : null,
                      icon: const Icon(LucideIcons.pencil, size: 14),
                      label: const Text('Editar'),
                    ),
                  ),
                ],
                Tooltip(
                  message: puedeCambiar ? '' : tooltipBloqueado,
                  child: TextButton.icon(
                    onPressed: puedeCambiar ? () => _anular(m) : null,
                    icon: const Icon(LucideIcons.ban, size: 14),
                    label: const Text('Anular'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Detalle completo de un cierre (celular): hoja inferior con su barra de
  // arrastre y todas las columnas de la tabla.
  void _verCierreCompleto(CierreCaja c) {
    final columnas = _columnasCierres();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              'Cierre del ${_fecha(c.fechaCierre)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final col in columnas)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: [
                    Text(
                      col.titulo.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: col.celda(c),
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

  List<ColumnaTabla<CierreCaja>> _columnasCierres() {
    ColumnaTabla<CierreCaja> monto(
      String titulo,
      double Function(CierreCaja) valor, {
      bool fuerte = false,
    }) => ColumnaTabla(
      titulo: titulo,
      anchoMin: 96,
      rol: RolTarjeta.dato,
      ordenarPor: valor,
      celda: (c) => TablaApp.texto(_soles(valor(c)), fuerte: fuerte),
    );
    return [
      ColumnaTabla(
        titulo: 'Fecha',
        ancho: 150,
        ordenarPor: (c) => c.fechaCierre,
        celda: (c) => TablaApp.texto(_fecha(c.fechaCierre)),
      ),
      ColumnaTabla(
        titulo: 'Cajero',
        anchoMin: 120,
        rol: RolTarjeta.titulo,
        ordenarPor: (c) => (c.usuarioNombre ?? '').toLowerCase(),
        celda: (c) => TablaApp.texto(c.usuarioNombre ?? '—', fuerte: true),
      ),
      monto('Inicial', (c) => c.montoInicial),
      monto('Declarado', (c) => c.montoDeclarado),
      ColumnaTabla(
        titulo: 'Dif. efectivo',
        anchoMin: 110,
        rol: RolTarjeta.dato,
        ordenarPor: (c) => c.diferenciaEfectivo,
        celda: (c) {
          final dif = c.diferenciaEfectivo;
          return TablaApp.texto(
            '${dif >= 0 ? '+' : '-'}${_soles(dif.abs())}',
            fuerte: true,
            color: dif.abs() < 0.01
                ? AppColors.primaryGreen
                : (dif < 0 ? AppColors.error : const Color(0xFFEF6C00)),
          );
        },
      ),
      ColumnaTabla(
        titulo: 'Reportes',
        anchoMin: 110,
        rol: RolTarjeta.acciones,
        celda: (c) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'Imprimir Ticket de este Turno',
              child: IconButton(
                icon: const Icon(
                  LucideIcons.printer,
                  size: 16,
                  color: Colors.blue,
                ),
                onPressed: () => _imprimirReporteTurno(cierreId: c.id),
              ),
            ),
            Tooltip(
              message: 'Ver Detalle del Turno (PDF/HTML)',
              child: IconButton(
                icon: const Icon(
                  LucideIcons.fileText,
                  size: 16,
                  color: Colors.purple,
                ),
                onPressed: () => _abrirReporteDiaDetallado(cierreId: c.id),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // Tarjetas del resumen de la caja actual (7 métricas clave solicitadas):
  // 1. Monto apertura, 2. Ingresos, 3. Egresos, 4. Neto, 5. Efectivo, 6. Tarjetas/POS, 7. Yape/Plin
  Widget _tarjetasCaja({
    AperturaCaja? apertura,
    required List<FilaResumenMedio> filas,
    required double ventas,
    required double delivery,
    required int numPedidos,
    required double ingresos,
    required double salidas,
  }) {
    final montoApertura = apertura?.montoInicial ?? 0.0;
    final totalIngresos = ventas + ingresos;
    final totalEgresos = salidas;

    final totalEfectivo = filas
        .where(
          (f) =>
              f.grupo.toLowerCase() == 'efectivo' ||
              f.medio.toLowerCase().contains('efectivo'),
        )
        .fold(0.0, (s, f) => s + f.ventas + f.ingresos);
    final totalTarjeta = filas
        .where(
          (f) =>
              f.grupo.toLowerCase() == 'tarjeta' ||
              (!f.medio.toLowerCase().contains('efectivo') &&
                  !f.medio.toLowerCase().contains('yape') &&
                  !f.medio.toLowerCase().contains('plin') &&
                  f.grupo.toLowerCase() != 'digital'),
        )
        .fold(0.0, (s, f) => s + f.ventas + f.ingresos);
    final totalDigital = filas
        .where(
          (f) =>
              f.grupo.toLowerCase() == 'digital' ||
              f.medio.toLowerCase().contains('yape') ||
              f.medio.toLowerCase().contains('plin'),
        )
        .fold(0.0, (s, f) => s + f.ventas + f.ingresos);

    final neto = montoApertura + totalEfectivo - totalEgresos;

    // Menos que una tablet: tarjetas en miniatura, 2 columnas por 2 filas, con
    // desplazamiento hacia el lado para ver el resto.
    final mini = AppBreakpoints.esMenorATablet(context);
    final tarjetas = [
      _tarjetaCaja(
        LucideIcons.lockOpen,
        const Color(0xFF0EA5E9),
        const Color(0xFFE6F6FD),
        'Monto de apertura',
        montoApertura,
        apertura != null
            ? [
                if ((apertura.usuarioNombre ?? '').isNotEmpty)
                  'Abrió ${apertura.usuarioNombre}',
                _hora(apertura.fechaApertura),
              ].join(' · ')
            : 'Caja cerrada',
      ),
      _tarjetaCaja(
        LucideIcons.trendingUp,
        const Color(0xFF10B981),
        const Color(0xFFE8F7F1),
        'Ingresos',
        totalIngresos,
        'Ventas + ingresos extra',
      ),
      _tarjetaCaja(
        LucideIcons.arrowUpRight,
        AppColors.error,
        const Color(0xFFFDECEC),
        'Egresos',
        totalEgresos,
        'Salidas de caja',
      ),
      _tarjetaCaja(
        LucideIcons.wallet,
        const Color(0xFF8B5CF6),
        const Color(0xFFF3EEFF),
        'Neto',
        neto,
        'Apertura + Ingresos - Egresos',
      ),
      _tarjetaCaja(
        LucideIcons.dollarSign,
        const Color(0xFF16A34A),
        const Color(0xFFEFFBEF),
        'Ingresos Efectivo',
        totalEfectivo,
        'Total cobrado en efectivo',
      ),
      _tarjetaCaja(
        LucideIcons.creditCard,
        const Color(0xFF3B82F6),
        const Color(0xFFEFF6FF),
        'Tarjetas / POS',
        totalTarjeta,
        'Total cobrado con tarjeta',
      ),
      _tarjetaCaja(
        LucideIcons.smartphone,
        const Color(0xFFD946EF),
        const Color(0xFFFCEBFD),
        'Yape / Plin',
        totalDigital,
        'Total cobrado por billeteras',
      ),
    ];
    if (mini) {
      return LayoutBuilder(
        builder: (context, c) {
          const espacio = 8.0;
          // Un poco menos de la mitad: se asoma la siguiente columna.
          final ancho = (c.maxWidth - espacio) / 2 - 14;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < tarjetas.length; i += 2) ...[
                  if (i > 0) const SizedBox(width: espacio),
                  SizedBox(
                    width: ancho,
                    child: Column(
                      children: [
                        tarjetas[i],
                        if (i + 1 < tarjetas.length) ...[
                          const SizedBox(height: espacio),
                          tarjetas[i + 1],
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        const espacio = 12.0;
        final columnas = c.maxWidth >= 1000 ? 4 : (c.maxWidth >= 560 ? 2 : 1);
        final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final tarjeta in tarjetas)
              SizedBox(width: ancho, child: tarjeta),
          ],
        );
      },
    );
  }

  Widget _tarjetaCaja(
    IconData icono,
    Color color,
    Color fondo,
    String titulo,
    double valor,
    String? detalle,
  ) {
    final mini = AppBreakpoints.esMenorATablet(context);
    return Container(
      padding: EdgeInsets.all(mini ? 10 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: mini ? 30 : 44,
            height: mini ? 30 : 44,
            // Sin fondo de color: el grupo de tarjetas es todo blanco.
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(mini ? 9 : 12),
              border: Border.all(color: fondo),
            ),
            child: Icon(icono, size: mini ? 15 : 20, color: color),
          ),
          SizedBox(width: mini ? 8 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: mini ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: mini ? 2 : 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _soles(valor),
                    style: TextStyle(
                      fontSize: mini ? 15 : 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                if (detalle != null && !mini) ...[
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Diálogo para abrir caja seleccionando turno y monto inicial
class _AbrirCajaDialog extends StatefulWidget {
  final List<Turno> turnos;
  const _AbrirCajaDialog({required this.turnos});

  @override
  State<_AbrirCajaDialog> createState() => _AbrirCajaDialogState();
}

class _AbrirCajaDialogState extends State<_AbrirCajaDialog> {
  final _monto = TextEditingController(text: '0');
  final _notas = TextEditingController();
  Turno? _turnoSeleccionado;

  @override
  void initState() {
    super.initState();
    if (widget.turnos.isNotEmpty) {
      final now = TimeOfDay.now();
      final nowMinutes = now.hour * 60 + now.minute;
      for (final t in widget.turnos) {
        final partesI = t.horaInicio.split(':');
        final partesF = t.horaFin.split(':');
        if (partesI.length >= 2 && partesF.length >= 2) {
          final ini = int.tryParse(partesI[0]) ?? 0;
          final fin = int.tryParse(partesF[0]) ?? 23;
          final iniMin = ini * 60 + (int.tryParse(partesI[1]) ?? 0);
          final finMin = fin * 60 + (int.tryParse(partesF[1]) ?? 0);
          if (iniMin <= finMin) {
            if (nowMinutes >= iniMin && nowMinutes <= finMin) {
              _turnoSeleccionado = t;
              break;
            }
          } else {
            if (nowMinutes >= iniMin || nowMinutes <= finMin) {
              _turnoSeleccionado = t;
              break;
            }
          }
        }
      }
      _turnoSeleccionado ??= widget.turnos.first;
    }
  }

  @override
  void dispose() {
    _monto.dispose();
    _notas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogoApp(
      titulo: 'Abrir caja',
      ancho: 440,
      acciones: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final m =
                double.tryParse(_monto.text.trim().replaceAll(',', '.')) ?? 0;
            Navigator.of(context).pop((
              montoInicial: m,
              turnoId: _turnoSeleccionado?.id,
              notas: _notas.text.trim(),
            ));
          },
          child: const Text('Abrir caja'),
        ),
      ],
      children: [
        Text(
          'Configura el turno y el monto en efectivo con el que se inicia la caja.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 14),
        if (widget.turnos.isNotEmpty) ...[
          Text(
            'Turno operativo',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Turno>(
                isExpanded: true,
                value: _turnoSeleccionado,
                items: widget.turnos.map((t) {
                  return DropdownMenuItem<Turno>(
                    value: t,
                    child: Text('${t.nombre} (${t.horaInicio} - ${t.horaFin})'),
                  );
                }).toList(),
                onChanged: (t) => setState(() => _turnoSeleccionado = t),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        CampoTexto(
          controller: _monto,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monto inicial en efectivo (S/)',
          ),
        ),
        const SizedBox(height: 12),
        CampoTexto(
          controller: _notas,
          decoration: const InputDecoration(labelText: 'Notas (opcional)'),
        ),
      ],
    );
  }
}

// Diálogo para cerrar caja con validación estricta de efectivo contado vs esperado
class _CerrarCajaDialog extends StatefulWidget {
  final double efectivoEsperado;
  final String? turnoNombre;

  const _CerrarCajaDialog({required this.efectivoEsperado, this.turnoNombre});

  @override
  State<_CerrarCajaDialog> createState() => _CerrarCajaDialogState();
}

class _CerrarCajaDialogState extends State<_CerrarCajaDialog> {
  final _efectivo = TextEditingController();
  final _notas = TextEditingController();

  @override
  void dispose() {
    _efectivo.dispose();
    _notas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double? declarado = double.tryParse(
      _efectivo.text.trim().replaceAll(',', '.'),
    );
    final double dif = (declarado ?? 0) - widget.efectivoEsperado;
    final bool cuadra = declarado != null && dif.abs() <= 0.05;
    final bool tieneTexto = _efectivo.text.trim().isNotEmpty;

    return DialogoApp(
      titulo:
          'Cerrar caja ${widget.turnoNombre != null ? '· ${widget.turnoNombre}' : ''}',
      ancho: 440,
      acciones: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: cuadra
              ? () => Navigator.of(
                  context,
                ).pop((declaradoEfectivo: declarado, notas: _notas.text.trim()))
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: cuadra
                ? AppColors.primaryGreen
                : Colors.grey.shade400,
          ),
          child: const Text('Cerrar caja'),
        ),
      ],
      children: [
        Text(
          'Ingresa el efectivo contado físicamente en caja. Los cobros por tarjeta o transferencias (Yape/Plin) quedan en las cuentas del banco.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Efectivo esperado en caja:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              Text(
                'S/ ${widget.efectivoEsperado.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CampoTexto(
          controller: _efectivo,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Efectivo contado / declarado (S/)',
            hintText: 'Ej. 250.00',
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (tieneTexto) ...[
          const SizedBox(height: 12),
          if (cuadra)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7F1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.checkCircle,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '✔ Cuadre perfecto: El monto coincide exactamente con el efectivo esperado (S/ ${widget.efectivoEsperado.toStringAsFixed(2)}).',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.alertTriangle,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dif < 0
                              ? '❌ No se puede cerrar caja: Falta efectivo'
                              : '❌ No se puede cerrar caja: Sobra efectivo',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dif < 0
                              ? 'Esperado: S/ ${widget.efectivoEsperado.toStringAsFixed(2)} | Ingresado: S/ ${(declarado ?? 0).toStringAsFixed(2)}\nFaltan: S/ ${dif.abs().toStringAsFixed(2)}'
                              : 'Esperado: S/ ${widget.efectivoEsperado.toStringAsFixed(2)} | Ingresado: S/ ${(declarado ?? 0).toStringAsFixed(2)}\nSobran: S/ ${dif.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 12),
        CampoTexto(
          controller: _notas,
          decoration: const InputDecoration(
            labelText: 'Notas / Observaciones (opcional)',
          ),
        ),
      ],
    );
  }
}

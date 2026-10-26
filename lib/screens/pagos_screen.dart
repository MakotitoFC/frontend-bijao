import 'package:flutter/material.dart';

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
import '../data/usuarios_store.dart';
import '../models/app_role.dart';
import '../models/cierre_caja.dart';
import '../models/movimiento_caja.dart';
import '../models/usuario.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../widgets/app_search_field.dart';
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

// Historial de pedidos y Caja: vistas individuales (ver nav_items.dart).

String _nombreUsuario(String? id) {
  for (final u in usuarios) {
    if (u.id == id) return u.nombre;
  }
  return '—';
}

// Mozo que tomó el pedido: el nombre que manda el servidor o, si falta, el
// del usuario del pedido.
String _mozoDe(Pedido p) =>
    (p.mozoNombre != null && p.mozoNombre!.trim().isNotEmpty)
    ? p.mozoNombre!
    : _nombreUsuario(p.usuarioId);

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

  // Los pagos viven en el servidor: se traen los del rango elegido.
  Future<void> _cargarPagos() async {
    final r = _rango;
    try {
      if (r == null) {
        await PagoService.instance.cargarDelDia();
      } else {
        await PagoService.instance.cargarDelRango(r.start, r.end);
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _cambiarRango(DateTimeRange? r) {
    setState(() => _rango = r);
    _cargarPagos();
  }

  bool _enRango(Pedido p) {
    final r = _rango;
    if (r == null) return true;
    final d = DateUtils.dateOnly(p.fechaPedido);
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

  String _metodos(Pedido p) {
    final m = <String>{
      for (final x in pagos.where((x) => x.pedidoId == p.id))
        x.medioPago.medioPago,
    };
    return m.isEmpty ? '—' : m.join(', ');
  }

  List<Pedido> get _filas {
    final t = _busqueda.text.trim().toLowerCase();
    return pedidos.where((p) {
      if (!_enRango(p)) return false;
      if (_medioFiltro != 'todos' &&
          !mediosDePagoDe(p.id).contains(_medioFiltro)) {
        return false;
      }
      final ep = _estadoPago(p);
      if (_filtro == 'pagados' && ep != 'Pagado') return false;
      if (_filtro == 'por_cobrar' && ep != 'Por cobrar' && ep != 'Parcial') {
        return false;
      }
      if (t.isEmpty) return true;
      return p.numeroPedido.contains(t) ||
          (p.clienteNombre?.toLowerCase().contains(t) ?? false) ||
          _nombreUsuario(p.usuarioId).toLowerCase().contains(t);
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
                    AppSearchField(
                      controller: _busqueda,
                      hint: 'Buscar pedido o cliente...',
                      onChanged: (_) => setState(() {}),
                    ),
                  ];
                  if (c.maxWidth >= 1040) {
                    return Row(
                      children: [
                        titulo,
                        const Spacer(),
                        ...controles.take(3),
                        const SizedBox(width: 8),
                        controles[3],
                        const SizedBox(width: 8),
                        controles.last,
                      ],
                    );
                  }
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

  Widget _chipPago(String estado) {
    final (fondo, tinta) = switch (estado) {
      'Pagado' => (
        AppColors.neonVerde.withValues(alpha: 0.22),
        AppColors.verdeTexto,
      ),
      'Parcial' => (const Color(0xFFFFF3E0), const Color(0xFFEF6C00)),
      'Anulado' => (Colors.grey.shade200, const Color(0xFF6B7280)),
      _ => (const Color(0xFFFCE4EC), const Color(0xFFC2185B)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: tinta,
        ),
      ),
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
      porPagina: 10,
      filas: filas,
      columnas: [
        ColumnaTabla(
          titulo: 'Pedido',
          ancho: 100,
          ordenarPor: (p) => p.numeroPedido,
          celda: (p) => TablaApp.texto('#${p.numeroPedido}'),
        ),
        ColumnaTabla(
          titulo: 'Fecha',
          ancho: 150,
          ordenarPor: (p) => p.fechaPedido,
          celda: (p) => TablaApp.texto(_fecha(p.fechaPedido)),
        ),
        ColumnaTabla(
          titulo: 'Cliente',
          flex: 1.2,
          rol: RolTarjeta.titulo,
          ordenarPor: (p) => (p.clienteNombre ?? '').toLowerCase(),
          celda: (p) => TablaApp.texto(p.clienteNombre ?? '—', fuerte: true),
        ),
        ColumnaTabla(
          titulo: 'Tipo',
          ancho: 110,
          ordenarPor: (p) => p.ubicacion,
          celda: (p) => TablaApp.texto(p.ubicacion),
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
          ordenarPor: (p) => totalDePedido(p.id),
          celda: (p) => TablaApp.texto(_soles(totalDePedido(p.id))),
        ),
        ColumnaTabla(
          titulo: 'Método',
          flex: 1.3,
          anchoMin: 150,
          celda: (p) => Tooltip(
            message: _metodos(p),
            child: Text(
              _metodos(p),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TablaApp.estiloTexto,
            ),
          ),
        ),
        ColumnaTabla(
          titulo: 'Pago',
          ancho: 110,
          rol: RolTarjeta.estado,
          ordenarPor: (p) => _estadoPago(p),
          celda: (p) => Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _chipPago(_estadoPago(p)),
              if (pagadoSinServir(p)) _chipPago('Sin servir'),
            ],
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

  // Vuelve a pedir al servidor los totales de la caja (tras un movimiento).
  Future<void> _refrescarCaja() async {
    if (!CajaService.instance.enServidor) return;
    try {
      await CajaService.instance.cargarEstado();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  bool get _cajaCerrada =>
      estadoCajaServidor != null && !estadoCajaServidor!.abierta;

  Future<void> _abrirCaja() async {
    final monto = TextEditingController(text: '0');
    final notas = TextEditingController();
    final confirmar = await showBlurDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertaApp(
        title: const Text('Abrir caja'),
        content: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Escribe el efectivo con el que empieza el turno (el sencillo).',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 14),
              _campoDialogo(monto, 'Monto inicial (S/)'),
              CampoTexto(
                controller: notas,
                decoration: const InputDecoration(labelText: 'Notas'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Abrir caja'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      await CajaService.instance.abrir(
        montoInicial:
            double.tryParse(monto.text.trim().replaceAll(',', '.')) ?? 0,
        notas: notas.text,
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

  // Cierre con el servidor: el monto inicial sale de la apertura y el servidor
  // calcula lo que debería haber (ventas, ingresos y salidas).
  Future<void> _cerrarCajaServidor() async {
    final efectivo = TextEditingController();
    final tarjeta = TextEditingController();
    final digital = TextEditingController();
    final notas = TextEditingController();
    double n(TextEditingController c) =>
        double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;
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
                // Lo que "debería haber" es interno: el cajero cuenta y declara
                // sin verlo, y el sistema calcula la diferencia.
                Text(
                  'Cuenta el dinero de la caja y escribe lo que hay.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
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
    try {
      await CajaService.instance.cerrar(
        declaradoEfectivo: n(efectivo),
        declaradoTarjeta: n(tarjeta),
        declaradoDigital: n(digital),
        notas: notas.text,
      );
      if (!mounted) return;
      setState(() {});
      showAppToast(
        context,
        'La caja se cerró. Para el siguiente turno, ábrela de nuevo.',
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
      _refrescarCaja();
    } catch (e) {
      if (mounted) showAppToast(context, e.toString(), type: ToastType.error);
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
      setState(() {});
      showAppToast(context, 'Movimiento corregido.', type: ToastType.success);
      _refrescarCaja();
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
      setState(() {});
      showAppToast(context, 'Movimiento anulado.', type: ToastType.success);
      _refrescarCaja();
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
    final filas = srv?.porMedio ?? resumen;
    final ventas =
        srv?.ventas ?? resumen.fold<double>(0.0, (s, f) => s + f.ventas);
    final ingresos = srv?.ingresos ?? extra.ingresos;
    final salidas = srv?.salidas ?? extra.egresos;
    final numPedidos = srv?.numPedidos ?? t.pedidos;
    final movimientos = movimientosDesde(desde);
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
                              'Desde ${_fecha(desde)} · $numPedidos pedido(s) cobrado(s)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
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
                  const SizedBox(height: 14),
                  _tarjetasCaja(
                    filas: filas,
                    ventas: ventas,
                    delivery: srv?.delivery ?? 0,
                    numPedidos: numPedidos,
                    ingresos: ingresos,
                    salidas: salidas,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Por medio de pago',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TablaApp<FilaResumenMedio>(
                    porPagina: 10,
                    filas: filas,
                    columnas: [
                      ColumnaTabla(
                        titulo: 'Medio',
                        flex: 1.4,
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
                        celda: (f) =>
                            TablaApp.texto(_soles(f.neto), fuerte: true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _panelMovimientos(movimientos),
            const SizedBox(height: 16),
            if (CajaService.instance.enServidor) ...[
              const ComprobantesCajaPanel(),
              const SizedBox(height: 16),
            ],
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

  // Ingresos y salidas de la caja actual, con los botones para registrarlos.
  Widget _panelMovimientos(List<MovimientoCaja> movimientos) {
    return Container(
      decoration: _panel,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // El título a la izquierda y los botones en el otro extremo; en un
          // ancho chico los botones bajan debajo del título.
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
                    onPressed: () => _registrar(TipoMovimiento.ingreso),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Ingreso'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _registrar(TipoMovimiento.egreso),
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
          const SizedBox(height: 8),
          if (movimientos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Aún no hay ingresos ni salidas en esta caja',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          else
            for (final m in movimientos) _filaMovimiento(m),
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
                    Text(
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
                Tooltip(
                  message: puedeCambiar ? '' : tooltipBloqueado,
                  child: TextButton.icon(
                    onPressed: puedeCambiar ? () => _editar(m) : null,
                    icon: const Icon(LucideIcons.pencil, size: 14),
                    label: const Text('Editar'),
                  ),
                ),
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
      rol: titulo == 'Total' ? RolTarjeta.dato : RolTarjeta.oculta,
      ordenarPor: valor,
      celda: (c) => TablaApp.texto(_soles(valor(c)), fuerte: fuerte),
    );
    return [
      ColumnaTabla(
        titulo: 'Cierre',
        ancho: 150,
        ordenarPor: (c) => c.fechaCierre,
        celda: (c) => TablaApp.texto(_fecha(c.fechaCierre)),
      ),
      ColumnaTabla(
        titulo: 'Cajero',
        anchoMin: 120,
        rol: RolTarjeta.oculta,
        ordenarPor: (c) =>
            (c.usuarioNombre ?? _nombreUsuario(c.usuarioId)).toLowerCase(),
        celda: (c) => TablaApp.texto(
          c.usuarioNombre ?? _nombreUsuario(c.usuarioId),
          fuerte: true,
        ),
      ),
      ColumnaTabla(
        titulo: 'Pedidos',
        ancho: 84,
        ordenarPor: (c) => c.numPedidos,
        celda: (c) => TablaApp.texto('${c.numPedidos}'),
      ),
      monto('Inicial', (c) => c.montoInicial),
      monto('Efectivo', (c) => c.totalEfectivo),
      monto('Tarjeta', (c) => c.totalTarjeta),
      monto('Yape', (c) => c.totalYape),
      monto('Plin', (c) => c.totalPlin),
      monto('Delivery', (c) => c.totalDelivery),
      monto('Total', (c) => c.totalGeneral, fuerte: true),
      monto('Ingresos', (c) => c.totalIngresos),
      monto('Salidas', (c) => c.totalEgresos),
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
        titulo: 'Notas',
        anchoMin: 140,
        rol: RolTarjeta.oculta,
        celda: (c) => TablaApp.texto(c.notas ?? '—'),
      ),
    ];
  }

  // Tarjetas del resumen de la caja actual, con lo que el servidor calcula:
  // ventas, delivery, y lo cobrado en efectivo, tarjeta y digital.
  Widget _tarjetasCaja({
    required List<FilaResumenMedio> filas,
    required double ventas,
    required double delivery,
    required int numPedidos,
    required double ingresos,
    required double salidas,
  }) {
    double ventasDe(String grupo) =>
        filas.where((f) => f.grupo == grupo).fold(0.0, (s, f) => s + f.ventas);
    // Menos que una tablet: tarjetas en miniatura, 2 columnas por 2 filas, con
    // desplazamiento hacia el lado para ver el resto.
    final mini = AppBreakpoints.esMenorATablet(context);
    final tarjetas = [
      _tarjetaCaja(
        LucideIcons.trendingUp,
        const Color(0xFF3B82F6),
        const Color(0xFFEFF6FF),
        'Ingresos Brutos',
        ventas,
        '$numPedidos pedidos totales',
      ),
      _tarjetaCaja(
        LucideIcons.trendingUp,
        const Color(0xFF10B981),
        const Color(0xFFE8F7F1),
        'Ventas de Comida',
        ventas - delivery,
        'Libre de delivery',
      ),
      _tarjetaCaja(
        LucideIcons.user,
        const Color(0xFFF59E0B),
        const Color(0xFFFFF4E0),
        'Ventas Delivery',
        delivery,
        'Cobrado en pedidos de delivery',
      ),
      _tarjetaCaja(
        LucideIcons.dollarSign,
        const Color(0xFF10B981),
        const Color(0xFFE8F7F1),
        'Ventas Efectivo',
        ventasDe('efectivo'),
        'Cobrado en efectivo',
      ),
      _tarjetaCaja(
        LucideIcons.creditCard,
        const Color(0xFF8B5CF6),
        const Color(0xFFF3EEFF),
        'Tarjetas / POS',
        ventasDe('tarjeta'),
        null,
      ),
      _tarjetaCaja(
        LucideIcons.smartphone,
        const Color(0xFFD946EF),
        const Color(0xFFFCEBFD),
        'Yape / Plin',
        ventasDe('digital'),
        null,
      ),
      _tarjetaCaja(
        LucideIcons.arrowDownLeft,
        const Color(0xFF16A34A),
        const Color(0xFFE8F7F1),
        'Ingresos',
        ingresos,
        null,
      ),
      _tarjetaCaja(
        LucideIcons.arrowUpRight,
        AppColors.error,
        const Color(0xFFFDECEC),
        'Salidas',
        salidas,
        null,
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

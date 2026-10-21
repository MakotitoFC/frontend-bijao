import 'package:flutter/material.dart';

import '../widgets/dialogo_app.dart';

import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/cierres_store.dart';
import '../data/movimientos_caja_store.dart';
import '../data/pagos_store.dart';
import '../services/caja_service.dart';
import '../services/movimiento_caja_service.dart';
import '../services/pago_service.dart';
import '../data/pedidos_store.dart';
import '../data/usuarios_store.dart';
import '../models/app_role.dart';
import '../models/cierre_caja.dart';
import '../models/comprobante.dart';
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
  // Rango de fechas de los pedidos mostrados (por defecto, hoy).
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
    return hayPagos ? 'Parcial' : 'Por cobrar';
  }

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
                    'Historial de pedidos',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  );
                  final controles = [
                    _pastilla('Todos', 'todos'),
                    _pastilla('Pagados', 'pagados'),
                    _pastilla('Por cobrar', 'por_cobrar'),
                    SelectorRangoFechas(
                      valor: _rango,
                      permiteTodas: true,
                      onChanged: _cambiarRango,
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
    // Se leen los cobros del servidor: sin ellos no se puede facturar.
    try {
      await PagoService.instance.cargarDePedido(p);
    } catch (_) {}
    if (!mounted) return;
    final c = await showBlurDialog<Comprobante>(
      context: context,
      builder: (_) => EmitirComprobanteDialog(pedido: p),
    );
    if (c == null || !mounted) return;
    await showBlurDialog<void>(
      context: context,
      builder: (_) => ComprobanteEmitidoDialog(comprobante: c, pedido: p),
    );
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
          titulo: 'Mesero',
          flex: 1,
          ordenarPor: (p) => _nombreUsuario(p.usuarioId).toLowerCase(),
          celda: (p) => TablaApp.texto(_nombreUsuario(p.usuarioId)),
        ),
        ColumnaTabla(
          titulo: 'Total',
          ancho: 100,
          ordenarPor: (p) => totalDePedido(p.id),
          celda: (p) => TablaApp.texto(_soles(totalDePedido(p.id))),
        ),
        ColumnaTabla(
          titulo: 'Cobrado',
          ancho: 100,
          ordenarPor: (p) => totalDePedido(p.id) - saldoPendienteDePedido(p.id),
          celda: (p) => TablaApp.texto(
            _soles(totalDePedido(p.id) - saldoPendienteDePedido(p.id)),
          ),
        ),
        ColumnaTabla(
          titulo: 'Método',
          ancho: 110,
          celda: (p) => TablaApp.texto(_metodos(p)),
        ),
        ColumnaTabla(
          titulo: 'Pago',
          ancho: 110,
          ordenarPor: (p) => _estadoPago(p),
          celda: (p) => _chipPago(_estadoPago(p)),
        ),
        ColumnaTabla(
          titulo: 'Acciones',
          ancho: 110,
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
    final t = estadoCajaServidor?.totales;
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
                if (t != null)
                  Text(
                    'Debería haber: efectivo ${_soles(t.efectivoEsperado)} '
                    '(incluye el monto inicial de ${_soles(t.montoInicial)}), '
                    'tarjeta ${_soles(t.tarjeta)}, '
                    'digital (Yape/Plin) ${_soles(t.digital)}.',
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
    final esperado = netoPorGrupo(inicioCajaActual);
    final extra = totalesMovimientos(inicioCajaActual);
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
                  'Debería haber, contando cobros, ingresos y salidas: '
                  'efectivo ${_soles(esperado.efectivo)} (más el monto inicial), '
                  'tarjeta ${_soles(esperado.tarjeta)}, '
                  'digital (Yape/Plin) ${_soles(esperado.digital)}.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                if (extra.ingresos > 0 || extra.egresos > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Incluye ${_soles(extra.ingresos)} de ingresos y '
                    '${_soles(extra.egresos)} de salidas.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
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
    final efectivoEsperado =
        srv?.efectivoEsperado ??
        resumen
            .where((f) => grupoDeMedio(f.medio) == 'efectivo')
            .fold<double>(0.0, (s, f) => s + f.neto);
    final movimientos = movimientosDesde(desde);
    final rangoCierres = _rangoCierres;
    final cierres = rangoCierres == null
        ? cierresCaja
        : [
            for (final c in cierresCaja)
              if (!DateUtils.dateOnly(c.fechaCierre).isBefore(
                    DateUtils.dateOnly(rangoCierres.start),
                  ) &&
                  !DateUtils.dateOnly(c.fechaCierre).isAfter(
                    DateUtils.dateOnly(rangoCierres.end),
                  ))
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
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _dato('Ventas', ventas),
                      _dato('Ingresos', ingresos),
                      _dato('Salidas', salidas),
                      _dato(
                        'Efectivo esperado',
                        efectivoEsperado,
                        destacado: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    srv != null
                        ? 'El efectivo esperado es el monto inicial + ventas + '
                              'ingresos − salidas en efectivo.'
                        : 'El efectivo esperado es ventas + ingresos − salidas en '
                              'efectivo; falta sumar el monto inicial, que se escribe al cerrar.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Por medio de pago',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TablaApp<FilaResumenMedio>(
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
                        celda: (f) => TablaApp.texto(_soles(f.neto), fuerte: true),
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
                      filas: cierres,
                      columnas: _columnasCierres(),
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
          // El título a la izquierda y los botones en el otro extremo.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'Ingresos y salidas',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              Flexible(
                flex: 3,
                child: Wrap(
                  alignment: WrapAlignment.end,
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

  List<ColumnaTabla<CierreCaja>> _columnasCierres() {
    ColumnaTabla<CierreCaja> monto(
      String titulo,
      double Function(CierreCaja) valor, {
      bool fuerte = false,
    }) => ColumnaTabla(
      titulo: titulo,
      anchoMin: 96,
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
        celda: (c) => TablaApp.texto(c.notas ?? '—'),
      ),
    ];
  }

  Widget _dato(String etiqueta, double valor, {bool destacado = false}) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: destacado
            ? AppColors.primaryGreen.withValues(alpha: 0.12)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            _soles(valor),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: destacado ? AppColors.primaryGreen : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

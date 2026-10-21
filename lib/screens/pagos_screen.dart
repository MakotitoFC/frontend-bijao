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
import '../models/movimiento_caja.dart';
import '../models/usuario.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../widgets/app_search_field.dart';
import '../widgets/app_tag.dart';
import '../widgets/app_toast.dart';
import '../widgets/comprobantes_caja_panel.dart';
import '../widgets/detalle_pedido_panel.dart';
import '../widgets/movimiento_caja_dialog.dart';
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

const _estiloCabecera = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  color: Color(0xFF6B7280),
);
const _estiloCelda = TextStyle(fontSize: 12, color: Colors.black87);

DataColumn _col(String t) => DataColumn(
  label: Center(child: Text(t, style: _estiloCabecera)),
);

DataCell _celda(Widget w) => DataCell(Center(child: w));

DataCell _texto(String t, {bool fuerte = false}) => _celda(
  Text(
    t,
    style: fuerte
        ? _estiloCelda.copyWith(fontWeight: FontWeight.w600)
        : _estiloCelda,
  ),
);

// Tabla centrada que ocupa al menos el ancho disponible y, si es más ancha,
// se desplaza en horizontal.
Widget _tablaCentrada(List<DataColumn> columnas, List<DataRow> filas) {
  return LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: c.maxWidth),
        child: Center(
          child: DataTable(
            showCheckboxColumn: false,
            headingRowHeight: 38,
            dataRowMinHeight: 46,
            dataRowMaxHeight: 46,
            columnSpacing: 26,
            horizontalMargin: 12,
            dividerThickness: 0.6,
            columns: columnas,
            rows: filas,
          ),
        ),
      ),
    ),
  );
}

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

  @override
  void initState() {
    super.initState();
    _cargarPagosDelDia();
  }

  // Los pagos viven en el servidor: se traen los del día al abrir la pantalla.
  Future<void> _cargarPagosDelDia() async {
    try {
      await PagoService.instance.cargarDelDia();
    } catch (_) {}
    if (mounted) setState(() {});
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
                    AppSearchField(
                      controller: _busqueda,
                      hint: 'Buscar pedido o cliente...',
                      onChanged: (_) => setState(() {}),
                    ),
                  ];
                  if (c.maxWidth >= 860) {
                    return Row(
                      children: [
                        titulo,
                        const Spacer(),
                        ...controles.take(3),
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
                      Wrap(runSpacing: 8, children: controles),
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

  Widget _tabla(List<Pedido> filas) {
    return _tablaCentrada(
      [
        _col('Pedido'),
        _col('Fecha'),
        _col('Cliente'),
        _col('Tipo'),
        _col('Mesero'),
        _col('Total'),
        _col('Cobrado'),
        _col('Método'),
        _col('Pago'),
        _col('Acciones'),
      ],
      [
        for (final p in filas)
          DataRow(
            cells: [
              _texto('#${p.numeroPedido}'),
              _texto(_fecha(p.fechaPedido)),
              _texto(p.clienteNombre ?? '—', fuerte: true),
              _texto(p.ubicacion),
              _texto(_nombreUsuario(p.usuarioId)),
              _texto(_soles(totalDePedido(p.id))),
              _texto(
                _soles(totalDePedido(p.id) - saldoPendienteDePedido(p.id)),
              ),
              _texto(_metodos(p)),
              _celda(_chipPago(_estadoPago(p))),
              _celda(
                _estadoPago(p) == 'Pagado' || _estadoPago(p) == 'Anulado'
                    ? const SizedBox.shrink()
                    : Tooltip(
                        message: 'Cobrar',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _cobrar(p),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primaryGreen),
                            ),
                            child: const Icon(
                              LucideIcons.wallet,
                              size: 15,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
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
                  _tablaCentrada(
                    [
                      _col('Medio'),
                      _col('Ventas'),
                      _col('Ingresos'),
                      _col('Salidas'),
                      _col('Neto'),
                    ],
                    [
                      for (final f in filas)
                        DataRow(
                          cells: [
                            _texto(f.medio, fuerte: true),
                            _texto(_soles(f.ventas)),
                            _texto(_soles(f.ingresos)),
                            _texto(_soles(f.egresos)),
                            _texto(_soles(f.neto), fuerte: true),
                          ],
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
                  const Text(
                    'Cierres de caja',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (cierresCaja.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Aún no hay cierres de caja',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    )
                  else
                    _tablaCentrada(
                      [
                        _col('Cierre'),
                        _col('Cajero'),
                        _col('Pedidos'),
                        _col('Inicial'),
                        _col('Efectivo'),
                        _col('Tarjeta'),
                        _col('Yape'),
                        _col('Plin'),
                        _col('Delivery'),
                        _col('Total'),
                        _col('Ingresos'),
                        _col('Salidas'),
                        _col('Declarado'),
                        _col('Dif. efectivo'),
                        _col('Notas'),
                      ],
                      [for (final c in cierresCaja) _fila(c)],
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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Ingresos y salidas',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
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
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              ),
              OutlinedButton.icon(
                onPressed: _administrarCategorias,
                icon: const Icon(LucideIcons.tag, size: 16),
                label: const Text('Categorías'),
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

  DataRow _fila(CierreCaja c) {
    final dif = c.diferenciaEfectivo;
    return DataRow(
      cells: [
        _texto(_fecha(c.fechaCierre)),
        _texto(c.usuarioNombre ?? _nombreUsuario(c.usuarioId), fuerte: true),
        _texto('${c.numPedidos}'),
        _texto(_soles(c.montoInicial)),
        _texto(_soles(c.totalEfectivo)),
        _texto(_soles(c.totalTarjeta)),
        _texto(_soles(c.totalYape)),
        _texto(_soles(c.totalPlin)),
        _texto(_soles(c.totalDelivery)),
        _texto(_soles(c.totalGeneral), fuerte: true),
        _texto(_soles(c.totalIngresos)),
        _texto(_soles(c.totalEgresos)),
        _texto(_soles(c.montoDeclarado)),
        _celda(
          Text(
            '${dif >= 0 ? '+' : '-'}${_soles(dif.abs())}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: dif.abs() < 0.01
                  ? AppColors.primaryGreen
                  : (dif < 0 ? AppColors.error : const Color(0xFFEF6C00)),
            ),
          ),
        ),
        _texto(c.notas ?? '—'),
      ],
    );
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

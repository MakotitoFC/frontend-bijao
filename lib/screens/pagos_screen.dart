import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/cierres_store.dart';
import '../data/mesas_store.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../data/usuarios_store.dart';
import '../models/cierre_caja.dart';
import '../models/mesa.dart';
import '../models/mock_user.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/panel_pedido_mesa.dart';

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
  final MockUser usuario;

  const HistorialPedidosScreen({super.key, required this.usuario});

  @override
  State<HistorialPedidosScreen> createState() => _HistorialPedidosScreenState();
}

class _HistorialPedidosScreenState extends State<HistorialPedidosScreen> {
  final _busqueda = TextEditingController();
  String _filtro = 'todos'; // todos | pagados | por_cobrar

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  // Estado de pago del pedido según sus cobros.
  String _estadoPago(Pedido p) {
    if (p.estado == 'cancelado' || p.estado == 'anulado') return 'Cancelado';
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

  Future<void> _cobrar(Pedido p) async {
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
    await showBlurDialog<void>(
      context: context,
      builder: (dialogContext) => PanelPedidoMesa(
        key: ValueKey('cobro-${p.id}'),
        mesa: mesa,
        usuario: widget.usuario,
        onCerrar: () => Navigator.of(dialogContext).pop(),
        onCambio: () => setState(() {}),
      ),
    );
    if (mounted) setState(() {});
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
            Row(
              children: [
                const Text(
                  'Historial de pedidos',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                _pastilla('Todos', 'todos'),
                _pastilla('Pagados', 'pagados'),
                _pastilla('Por cobrar', 'por_cobrar'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _busqueda,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Buscar pedido o cliente...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
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
    final activo = _filtro == valor;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _filtro = valor),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: Neon.etiqueta(activa: activo, radio: 20),
          child: Text(
            etiqueta,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.verdeTexto,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipPago(String estado) {
    final (fondo, tinta) = switch (estado) {
      'Pagado' => (
        AppColors.neonVerde.withValues(alpha: 0.22),
        AppColors.verdeTexto,
      ),
      'Parcial' => (const Color(0xFFFFF3E0), const Color(0xFFEF6C00)),
      'Cancelado' => (Colors.grey.shade200, const Color(0xFF6B7280)),
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
              _texto(
                p.tipoPedido == 'delivery'
                    ? 'Delivery'
                    : 'Mesa ${p.todasLasMesas.join(' + ')}',
              ),
              _texto(_nombreUsuario(p.usuarioId)),
              _texto(_soles(totalDePedido(p.id))),
              _texto(
                _soles(totalDePedido(p.id) - saldoPendienteDePedido(p.id)),
              ),
              _texto(_metodos(p)),
              _celda(_chipPago(_estadoPago(p))),
              _celda(
                _estadoPago(p) == 'Pagado' || _estadoPago(p) == 'Cancelado'
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
  final MockUser usuario;

  const CajaScreen({super.key, required this.usuario});

  @override
  State<CajaScreen> createState() => _CajaScreenState();
}

class _CajaScreenState extends State<CajaScreen> {
  Future<void> _cerrarCaja() async {
    final t = totalesCajaActual();
    final inicial = TextEditingController(text: '0');
    final efectivo = TextEditingController();
    final tarjeta = TextEditingController();
    final digital = TextEditingController();
    final notas = TextEditingController();
    double n(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar caja'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Según los cobros: efectivo ${_soles(t.efectivo)}, '
                  'tarjeta ${_soles(t.tarjeta)}, '
                  'digital (Yape/Plin) ${_soles(t.yape + t.plin)}.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
                _campoDialogo(inicial, 'Monto inicial (S/)'),
                _campoDialogo(efectivo, 'Efectivo declarado (S/)'),
                _campoDialogo(tarjeta, 'Tarjeta declarada (S/)'),
                _campoDialogo(digital, 'Digital declarado (S/)'),
                TextField(
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
  }

  Widget _campoDialogo(TextEditingController c, String etiqueta) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: etiqueta),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = totalesCajaActual();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                            'Desde ${_fecha(inicioCajaActual)} · ${t.pedidos} pedido(s) cobrado(s)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _cerrarCaja,
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
                    _dato('Efectivo', t.efectivo),
                    _dato('Tarjeta', t.tarjeta),
                    _dato('Yape', t.yape),
                    _dato('Plin', t.plin),
                    _dato('Delivery', t.delivery),
                    _dato('Total', t.general, destacado: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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

  DataRow _fila(CierreCaja c) {
    final dif = c.diferenciaEfectivo;
    return DataRow(
      cells: [
        _texto(_fecha(c.fechaCierre)),
        _texto(_nombreUsuario(c.usuarioId), fuerte: true),
        _texto('${c.numPedidos}'),
        _texto(_soles(c.montoInicial)),
        _texto(_soles(c.totalEfectivo)),
        _texto(_soles(c.totalTarjeta)),
        _texto(_soles(c.totalYape)),
        _texto(_soles(c.totalPlin)),
        _texto(_soles(c.totalDelivery)),
        _texto(_soles(c.totalGeneral), fuerte: true),
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

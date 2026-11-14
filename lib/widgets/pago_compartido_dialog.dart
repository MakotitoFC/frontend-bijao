import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/configuracion_store.dart';
import '../data/movimientos_caja_store.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../models/comprobante.dart';
import '../models/medio_pago.dart';
import '../models/movimiento_caja.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import '../services/catalog_service.dart';
import '../services/movimiento_caja_service.dart';
import '../services/pago_service.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';
import 'app_toast.dart';
import 'campo_texto.dart';
import 'comprobante_en_cobro.dart';
import 'pago_dialogs.dart';

// Boleta de un pagador: lo que consumió (o su parte) y cómo pagó.
typedef BoletaPagador = ({
  String nombre,
  List<({String descripcion, double monto})> items,
  double total,
  List<({MedioPago medio, double monto})> pagos,
  double recibido,
  double vuelto,
});

typedef ResultadoPagoCompartido = ({
  bool boletasIndividuales,
  List<BoletaPagador> boletas,
});

double _r2(double v) => (v * 100).roundToDouble() / 100;

class _FilaPago {
  MedioPago medio;
  final TextEditingController monto = TextEditingController();

  _FilaPago(this.medio);
}

class _Pagador {
  final TextEditingController nombre;
  final List<_FilaPago> pagos;
  ComprobanteEnCobro? comprobante;
  final TextEditingController recibido = TextEditingController();

  _Pagador(String nombre, MedioPago medio)
      : nombre = TextEditingController(text: nombre),
        pagos = [_FilaPago(medio)];

  double get totalPagos => pagos.fold(
        0.0,
        (s, p) => s + (double.tryParse(p.monto.text.trim()) ?? 0.0),
      );

  double get efectivoRecibido =>
      double.tryParse(recibido.text.trim()) ?? 0.0;

  double vuelto(double totalEfectivo) {
    final rec = efectivoRecibido;
    return rec > totalEfectivo ? _r2(rec - totalEfectivo) : 0.0;
  }

  void liberar() {
    comprobante?.dispose();
    nombre.dispose();
    recibido.dispose();
    for (final p in pagos) {
      p.monto.dispose();
    }
  }
}

// Representa 1 unidad individual de un producto del pedido
class _Unidad {
  final PedidoLine linea;
  final int indice; // de 0 a cantidad - 1
  final double monto;

  const _Unidad(this.linea, this.indice, this.monto);

  String get clave => '${linea.id}#$indice';
}

/// Asistente paso a paso para dividir cuenta por consumo exacto entre comensales
class PagoCompartidoDialog extends StatefulWidget {
  final Pedido pedido;
  final String titulo;
  final bool permiteVolver;

  const PagoCompartidoDialog({
    super.key,
    required this.pedido,
    required this.titulo,
    this.permiteVolver = false,
  });

  @override
  State<PagoCompartidoDialog> createState() => _PagoCompartidoDialogState();
}

class _PagoCompartidoDialogState extends State<PagoCompartidoDialog> {
  static const _maxPagadores = 8;
  static const _minPagadores = 2;

  int _paso = 0; // 0 = Reparto de platos, 1..N = Cobro a Persona N
  int _cantPersonas = 2;
  bool _guardando = false;

  CategoriaMovimiento? _categoriaSeleccionada;
  final List<_Pagador> _pagadores = [];
  final Map<String, int> _asignUnidad = {};

  late final double _saldo = saldoCuentaDePedido(widget.pedido.id);
  late final List<PedidoLine> _lineas = (detallesPorPedido[widget.pedido.id] ?? [])
      .where(esLineaDeProducto)
      .where((l) => _saldoLinea(l) > 0.001)
      .toList();

  late final List<_Unidad> _unidades = [
    for (final l in _lineas) ..._unidadesDe(l),
  ];

  List<_Unidad> _unidadesDe(PedidoLine l) {
    final n = l.cantidad < 1 ? 1 : l.cantidad;
    final saldo = _saldoLinea(l);
    final cada = _r2(saldo / n);
    return [
      for (var i = 0; i < n; i++)
        _Unidad(l, i, i == n - 1 ? _r2(saldo - cada * (n - 1)) : cada),
    ];
  }

  late final bool _admiteComprobante = puedeElegirComprobante(widget.pedido);

  MedioPago get _medioInicial =>
      mediosPagoActivos.firstWhere((m) => m.grupo == 'efectivo',
          orElse: () => mediosPagoActivos.first);

  static const _coloresPagador = [
    Color(0xFF0E9F6E),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFEF4444),
    Color(0xFF64748B),
  ];

  Color _colorDe(int i) => _coloresPagador[i % _coloresPagador.length];

  double _saldoLinea(PedidoLine l) =>
      l.precioTotalLinea - montoPagadoDeLinea(l.id);

  String _nombreDefecto(int i) => 'Persona ${i + 1}';

  @override
  void initState() {
    super.initState();
    _categoriaSeleccionada = categoriasDeTipo(TipoMovimiento.ingreso)
            .where((c) => c.nombre.toLowerCase().contains('venta'))
            .firstOrNull ??
        categoriasDeTipo(TipoMovimiento.ingreso).firstOrNull;

    CatalogService.instance.cargarMediosPago().then((_) {
      if (!mounted) return;
      setState(() {});
    }).catchError((_) {});

    if (categoriasMovimiento.isEmpty) {
      MovimientoCajaService.instance.cargarCategorias().then((_) {
        if (!mounted) return;
        setState(() {
          _categoriaSeleccionada = categoriasDeTipo(TipoMovimiento.ingreso)
                  .where((c) => c.nombre.toLowerCase().contains('venta'))
                  .firstOrNull ??
              categoriasDeTipo(TipoMovimiento.ingreso).firstOrNull;
        });
      }).catchError((_) {});
    }

    _ajustarPagadores(_cantPersonas);
  }

  @override
  void dispose() {
    for (final p in _pagadores) {
      p.liberar();
    }
    super.dispose();
  }

  void _ajustarPagadores(int nuevaCant) {
    while (_pagadores.length < nuevaCant) {
      final i = _pagadores.length;
      _pagadores.add(_Pagador(_nombreDefecto(i), _medioInicial));
    }
    while (_pagadores.length > nuevaCant) {
      final p = _pagadores.removeLast();
      p.liberar();
    }
    // Si alguna unidad quedó asignada a un índice fuera de rango, reasignar a 0
    for (final u in _unidades) {
      final actual = _asignUnidad[u.clave] ?? 0;
      if (actual >= nuevaCant) {
        _asignUnidad[u.clave] = 0;
      }
    }
  }

  double _montoPagador(int i) {
    return _unidades
        .where((u) => (_asignUnidad[u.clave] ?? 0) == i)
        .fold(0.0, (s, u) => s + u.monto);
  }

  List<_Unidad> _unidadesDePagador(int i) {
    return _unidades.where((u) => (_asignUnidad[u.clave] ?? 0) == i).toList();
  }

  List<Map<String, dynamic>> _itemsConsumidos(int i) {
    final unidadesP = _unidadesDePagador(i);
    final Map<String, ({String nombre, int cantidad, double pu, double subtotal})> map = {};
    for (final u in unidadesP) {
      final nombre = u.linea.nombrePlato;
      final pu = u.monto;
      if (map.containsKey(nombre)) {
        final actual = map[nombre]!;
        map[nombre] = (
          nombre: nombre,
          cantidad: actual.cantidad + 1,
          pu: actual.pu,
          subtotal: actual.subtotal + u.monto,
        );
      } else {
        map[nombre] = (
          nombre: nombre,
          cantidad: 1,
          pu: pu,
          subtotal: u.monto,
        );
      }
    }
    return map.values
        .map((x) => {
              'nombre': x.nombre,
              'cantidad': x.cantidad,
              'precio_unitario': x.pu,
              'subtotal': x.subtotal,
            })
        .toList();
  }

  void _iniciarCobroSecuencial() {
    // Validar que cada comensal tenga al menos 1 plato asignado
    for (var i = 0; i < _pagadores.length; i++) {
      if (_montoPagador(i) <= 0.005) {
        showAppToast(
          context,
          '${_nombreDefecto(i)} no tiene platos asignados. Asígnale al menos un consumo o reduce la cantidad de personas.',
          type: ToastType.warning,
        );
        return;
      }
    }

    // Inicializar los comprobantes y pagos de cada comensal con sus platos
    for (var i = 0; i < _pagadores.length; i++) {
      final p = _pagadores[i];
      final monto = _montoPagador(i);
      final items = _itemsConsumidos(i);

      if (_admiteComprobante) {
        p.comprobante?.dispose();
        final c = ComprobanteEnCobro(monto, tipoInicial: 'ticket_venta');
        c.itemsOriginales = List<Map<String, dynamic>>.from(items);
        c.total = monto;
        c.recalcularItemsInflados(notificar: false);
        c.addListener(() {
          if (mounted) setState(() {});
        });
        p.comprobante = c;
      }

      // Reiniciar monto del primer pago al total de la persona
      if (p.pagos.isEmpty) {
        p.pagos.add(_FilaPago(_medioInicial));
      }
      p.pagos.first.monto.text = monto.toStringAsFixed(2);
      // Eliminar filas adicionales que pudieran haber quedado
      while (p.pagos.length > 1) {
        p.pagos.removeLast().monto.dispose();
      }
    }

    setState(() => _paso = 1);
  }

  bool _pagadorValido(int i) {
    final p = _pagadores[i];
    final montoDebe = _montoPagador(i);
    final diff = (montoDebe - p.totalPagos).abs();
    if (diff > 0.01) return false;

    // Si tiene pago en efectivo y puso monto recibido, verificar que cubra el efectivo
    final efectivoPago = p.pagos
        .where((x) =>
            x.medio.grupo == 'efectivo' ||
            x.medio.medioPago.toLowerCase().contains('efectivo'))
        .fold(0.0, (s, x) => s + (double.tryParse(x.monto.text.trim()) ?? 0.0));

    if (efectivoPago > 0.005 && p.efectivoRecibido > 0.005) {
      if (p.efectivoRecibido < efectivoPago - 0.01) return false;
    }

    // Comprobante
    final c = p.comprobante;
    if (c != null && !c.completo) {
      return false;
    }

    return true;
  }

  Future<void> _finalizarCobro() async {
    // Validar a todos los pagadores antes de ejecutar
    for (var i = 0; i < _pagadores.length; i++) {
      if (!_pagadorValido(i)) {
        setState(() => _paso = i + 1);
        showAppToast(
          context,
          'Revisa los datos de pago y comprobante de ${_nombreDefecto(i)} antes de finalizar.',
          type: ToastType.warning,
        );
        return;
      }
    }

    setState(() => _guardando = true);
    final totalPagadores = _pagadores.length;
    final List<String> errores = [];
    final List<Comprobante> comprobantesEmitidos = [];

    try {
      for (var i = 0; i < totalPagadores; i++) {
        final p = _pagadores[i];
        final unidadesP = _unidadesDePagador(i);

        // Agrupar items de este pagador para enviar en pago_detalle
        final Map<String, ({String pedidoDetalleId, double monto, int cant})> agrupados = {};
        for (final u in unidadesP) {
          final pid = u.linea.id;
          if (agrupados.containsKey(pid)) {
            agrupados[pid] = (
              pedidoDetalleId: pid,
              monto: agrupados[pid]!.monto + u.monto,
              cant: agrupados[pid]!.cant + 1,
            );
          } else {
            agrupados[pid] = (
              pedidoDetalleId: pid,
              monto: u.monto,
              cant: 1,
            );
          }
        }
        final detallesJson = agrupados.values
            .map((a) => {
                  'pedido_detalle_id': a.pedidoDetalleId,
                  'monto_aplicado': a.monto,
                  'cantidad_pagada': a.cant,
                })
            .toList();

        String? primerPagoId;
        for (var k = 0; k < p.pagos.length; k++) {
          final fila = p.pagos[k];
          final montoFila = double.tryParse(fila.monto.text.trim()) ?? 0.0;
          if (montoFila <= 0.005) continue;

          final esEfectivo = fila.medio.grupo == 'efectivo' ||
              fila.medio.medioPago.toLowerCase().contains('efectivo');
          final rec = esEfectivo ? p.efectivoRecibido : 0.0;
          final vto = (rec > montoFila) ? (rec - montoFila) : 0.0;

          final nombrePagador = p.nombre.text.trim().isNotEmpty
              ? p.nombre.text.trim()
              : _nombreDefecto(i);

          final reg = await PagoService.instance.registrar(
            pedido: widget.pedido,
            medio: fila.medio,
            montoAbonado: montoFila,
            pagador: nombrePagador,
            categoriaMovimientoId: _categoriaSeleccionada?.id,
            montoRecibido: rec > 0.005 ? rec : null,
            vuelto: vto > 0.005 ? vto : null,
            detalles: k == 0 ? detallesJson : null,
          );
          primerPagoId ??= reg.id;
        }

        // Emisión de comprobante electrónico (Boleta / Factura)
        if (p.comprobante != null && p.comprobante!.emite && primerPagoId != null) {
          try {
            final c = await p.comprobante!.emitir(widget.pedido, pagoId: primerPagoId);
            comprobantesEmitidos.add(c);
          } catch (e) {
            final nom = p.nombre.text.trim().isNotEmpty
                ? p.nombre.text.trim()
                : _nombreDefecto(i);
            errores.add('Fallo comprobante de $nom: $e');
          }
        }
      }

      // Actualizar pagos en la app
      try {
        await PagoService.instance.cargarDePedido(widget.pedido);
      } catch (_) {}

      if (!mounted) return;

      if (errores.isNotEmpty) {
        showAppToast(
          context,
          'Pagos registrados con éxito en caja. Observaciones: ${errores.join(' · ')}',
          type: ToastType.warning,
          titulo: 'Pagos con avisos',
          duration: const Duration(seconds: 8),
        );
      } else {
        showAppToast(
          context,
          'Cuenta dividida cobrada con éxito entre $totalPagadores personas.',
          type: ToastType.success,
          titulo: 'Cobro completado',
        );
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      showAppToast(
        context,
        'Ocurrió un error registrando los pagos: $e',
        type: ToastType.error,
        titulo: 'Error en cobro',
        duration: const Duration(seconds: 6),
      );
    }
  }

  // ===========================================================================
  // UI WIDGETS
  // ===========================================================================

  Widget _avatar(int i, {double tam = 26}) => Container(
        width: tam,
        height: tam,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _colorDe(i), shape: BoxShape.circle),
        child: Text(
          '${i + 1}',
          style: TextStyle(
            color: Colors.white,
            fontSize: tam * 0.46,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  // ---------------------------------------------------------------------------
  // PASO 0: REPARTO DE PLATOS
  // ---------------------------------------------------------------------------
  Widget _buildPasoReparto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tarjetaSaldo('Total a dividir', _saldo),
        const SizedBox(height: 12),
        // Selector de cantidad de personas
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cantidad de personas',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Entre $_minPagadores y $_maxPagadores comensales',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                onPressed: _cantPersonas > _minPagadores
                    ? () {
                        setState(() {
                          _cantPersonas--;
                          _ajustarPagadores(_cantPersonas);
                        });
                      }
                    : null,
                icon: const Icon(Icons.remove, size: 16),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '$_cantPersonas personas',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                onPressed: _cantPersonas < _maxPagadores
                    ? () {
                        setState(() {
                          _cantPersonas++;
                          _ajustarPagadores(_cantPersonas);
                        });
                      }
                    : null,
                icon: const Icon(Icons.add, size: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Resumen rápido de totales por persona
        Row(
          children: [
            for (var i = 0; i < _cantPersonas; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: _colorDe(i).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _colorDe(i).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _avatar(i, tam: 18),
                          const SizedBox(width: 4),
                          Text(
                            'P${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _colorDe(i),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'S/ ${_montoPagador(i).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'ASIGNAR CADA PLATO A QUIEN LO CONSUMIÓ',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              for (var idx = 0; idx < _unidades.length; idx++) ...[
                if (idx > 0) Divider(height: 1, color: Colors.grey.shade200),
                Builder(builder: (context) {
                  final u = _unidades[idx];
                  final asignado = _asignUnidad[u.clave] ?? 0;
                  final varios = u.linea.cantidad > 1;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u.linea.nombrePlato,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                varios
                                    ? 'Unidad ${u.indice + 1} de ${u.linea.cantidad} · S/ ${u.monto.toStringAsFixed(2)}'
                                    : 'Cantidad: 1 · S/ ${u.monto.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _avatar(asignado, tam: 22),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 4,
                          child: AppSelect<int>(
                            value: asignado,
                            compacto: true,
                            items: [
                              for (var i = 0; i < _cantPersonas; i++)
                                AppSelectItem(
                                  value: i,
                                  label: _pagadores[i].nombre.text.trim().isEmpty
                                      ? _nombreDefecto(i)
                                      : _pagadores[i].nombre.text.trim(),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _asignUnidad[u.clave] = v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _iniciarCobroSecuencial,
          icon: const Icon(LucideIcons.arrowRight, size: 16),
          label: Text('Continuar al cobro (Paso 1 de $_cantPersonas)'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PASOS 1 a N: COBRO SECUENCIAL POR PERSONA
  // ---------------------------------------------------------------------------
  Widget _buildPasoCobroPersona(int index) {
    final p = _pagadores[index];
    final montoDebe = _montoPagador(index);
    final diff = montoDebe - p.totalPagos;
    final cuadra = diff.abs() <= 0.01;
    final esUltimo = index == _cantPersonas - 1;
    final items = _itemsConsumidos(index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Indicador de pasos arriba
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _cantPersonas; i++) ...[
                if (i > 0)
                  Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => _paso = i + 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _paso == i + 1
                          ? _colorDe(i).withValues(alpha: 0.15)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _paso == i + 1 ? _colorDe(i) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _avatar(i, tam: 18),
                        const SizedBox(width: 6),
                        Text(
                          _pagadores[i].nombre.text.trim().isEmpty
                              ? 'P${i + 1}'
                              : _pagadores[i].nombre.text.trim(),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: _paso == i + 1 ? FontWeight.w800 : FontWeight.w600,
                            color: _paso == i + 1 ? _colorDe(i) : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'S/ ${_montoPagador(i).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _paso == i + 1 ? Colors.black87 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Tarjeta de Consumo de esta persona
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _colorDe(index).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _colorDe(index).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _avatar(index, tam: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CampoTexto(
                      controller: p.nombre,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Nombre del comensal',
                        hintText: _nombreDefecto(index),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'TOTAL A COBRAR',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'S/ ${montoDebe.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _colorDe(index),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: _colorDe(index).withValues(alpha: 0.2)),
              const SizedBox(height: 8),
              Text(
                'Platos consumidos:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
              for (final it in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '${it['cantidad']}x ${it['nombre']}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      Text(
                        'S/ ${(it['subtotal'] as double).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // SECCIÓN MÉTODO DE PAGO
        const Text(
          'MÉTODO DE PAGO',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        for (var k = 0; k < p.pagos.length; k++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: AppSelect<String>(
                    value: p.pagos[k].medio.id,
                    compacto: true,
                    items: [
                      for (final m in mediosPagoActivos)
                        AppSelectItem(value: m.id, label: m.medioPago),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          p.pagos[k].medio = mediosPagoActivos.firstWhere((m) => m.id == v);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: AppSizes.boton,
                    child: CampoTexto(
                      controller: p.pagos[k].monto,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixText: 'S/ ',
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                ),
                if (p.pagos.length > 1)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        p.pagos.removeAt(k).monto.dispose();
                      });
                    },
                    icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ],

        // Si paga en efectivo, campo de recibido y vuelto
        if (p.pagos.any((x) =>
            x.medio.grupo == 'efectivo' ||
            x.medio.medioPago.toLowerCase().contains('efectivo'))) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: CampoTexto(
                  controller: p.recibido,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Efectivo recibido (S/) · para el vuelto',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Vuelto:',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                  Text(
                    'S/ ${p.vuelto(montoDebe).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
        ],

        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  p.pagos.add(_FilaPago(_medioInicial));
                });
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Dividir en otro método'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cuadra
                    ? AppColors.primaryGreen.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                cuadra
                    ? 'Monto exacto'
                    : (diff > 0
                        ? 'Falta S/ ${diff.toStringAsFixed(2)}'
                        : 'Sobra S/ ${(-diff).toStringAsFixed(2)}'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cuadra ? AppColors.primaryGreenDark : AppColors.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // SECCIÓN COMPROBANTE DE PAGO
        if (_admiteComprobante && p.comprobante != null) ...[
          const Text(
            'COMPROBANTE (BOLETA / FACTURA / NINGUNO)',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          SelectorComprobante(
            control: p.comprobante!,
            pedido: widget.pedido,
          ),
        ],
        const SizedBox(height: 24),

        // Botones de Navegación del Wizard
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _guardando
                  ? null
                  : () {
                      if (index == 0) {
                        setState(() => _paso = 0);
                      } else {
                        setState(() => _paso = index);
                      }
                    },
              icon: const Icon(LucideIcons.arrowLeft, size: 16),
              label: Text(index == 0 ? 'Reparto de platos' : 'P${index}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: (_pagadorValido(index) && !_guardando)
                    ? () {
                        if (esUltimo) {
                          _finalizarCobro();
                        } else {
                          setState(() => _paso = index + 2);
                        }
                      }
                    : null,
                icon: Icon(
                  esUltimo ? LucideIcons.checkCheck : LucideIcons.arrowRight,
                  size: 16,
                ),
                label: Text(
                  esUltimo
                      ? (_guardando ? 'Procesando...' : 'Finalizar cobro e imprimir')
                      : 'Siguiente (P${index + 2})',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: esUltimo ? const Color(0xFFF07F13) : AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModalPago(
      titulo: 'Dividir cuenta por comensal',
      subtitulo: 'Pedido #${widget.pedido.numeroPedido} · ${widget.titulo}',
      anchoEscritorio: 600,
      onVolver: widget.permiteVolver ? () => Navigator.of(context).pop() : null,
      child: _paso == 0 ? _buildPasoReparto() : _buildPasoCobroPersona(_paso - 1),
    );
  }
}

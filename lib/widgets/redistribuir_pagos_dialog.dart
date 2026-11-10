import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/configuracion_store.dart';
import '../models/medio_pago.dart';
import '../services/pago_service.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';
import 'campo_texto.dart';
import 'dialogo_app.dart';

class RedistribuirPagosDialog extends StatefulWidget {
  final String pedidoId;
  final int? comandaOrden;

  const RedistribuirPagosDialog({
    super.key,
    required this.pedidoId,
    this.comandaOrden,
  });

  @override
  State<RedistribuirPagosDialog> createState() => _RedistribuirPagosDialogState();
}

class _FilaDistribucion {
  MedioPago? medio;
  final TextEditingController montoCtrl;

  _FilaDistribucion({this.medio, double monto = 0.0})
      : montoCtrl = TextEditingController(
          text: monto > 0 ? monto.toStringAsFixed(2) : '',
        );

  double get monto => double.tryParse(montoCtrl.text.replaceAll(',', '.')) ?? 0.0;
}

class _RedistribuirPagosDialogState extends State<RedistribuirPagosDialog> {
  late final List<MedioPago> _medios = mediosPagoActivos;
  final List<_FilaDistribucion> _filas = [];
  final _motivo = TextEditingController(
    text: 'Reasignación de medios de pago por error de registro',
  );

  bool _cargando = true;
  bool _guardando = false;
  String? _error;
  double _totalPedido = 0.0;
  String _clienteNombre = '';
  int? _ordenComanda;

  @override
  void initState() {
    super.initState();
    _cargarDatosPedido();
  }

  @override
  void dispose() {
    for (final f in _filas) {
      f.montoCtrl.dispose();
    }
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosPedido() async {
    try {
      final res = await PagoService.instance.buscarPedidoPorComanda(
        widget.comandaOrden ?? 0,
      ).catchError((_) async {
        // Fallback a get por pedido
        final r = await PagoService.instance.rectificarPago(
          pagoId: '',
          nuevoMedioPagoId: '',
          motivo: '',
        ).catchError((_) => <String, dynamic>{});
        return r;
      });

      Map<String, dynamic> datos = res;
      if (datos.isEmpty || datos['pedido_id'] == null) {
        // Consultar directamente /api/pedidos/:id/pagos
        final resPagos = await PagoService.instance.buscarPedidoPorComanda(
          widget.comandaOrden ?? 1,
        ).catchError((_) => <String, dynamic>{});
        datos = resPagos;
      }

      final tot = (datos['total_pedido'] is num)
          ? (datos['total_pedido'] as num).toDouble()
          : (double.tryParse(datos['total_pedido']?.toString() ?? '0') ?? 0.0);

      _totalPedido = tot;
      _clienteNombre = datos['cliente_nombre']?.toString() ?? '';
      _ordenComanda = (datos['comanda_orden'] as num?)?.toInt() ?? widget.comandaOrden;

      final pagosRaw = datos['pagos'] as List?;
      if (pagosRaw != null && pagosRaw.isNotEmpty) {
        for (final p in pagosRaw) {
          if (p is Map<String, dynamic>) {
            final mId = p['medio_pago_id']?.toString() ?? '';
            final mAbonado = (p['monto_abonado'] is num)
                ? (p['monto_abonado'] as num).toDouble()
                : (double.tryParse(p['monto_abonado']?.toString() ?? '0') ?? 0.0);

            final medioEncontrado = _medios.where((m) => m.id == mId).firstOrNull ??
                _medios.firstOrNull;

            _filas.add(_FilaDistribucion(medio: medioEncontrado, monto: mAbonado));
          }
        }
      }

      if (_filas.isEmpty) {
        _filas.add(_FilaDistribucion(medio: _medios.firstOrNull, monto: _totalPedido));
      }

      setState(() => _cargando = false);
    } catch (e) {
      if (_filas.isEmpty) {
        _filas.add(_FilaDistribucion(medio: _medios.firstOrNull, monto: _totalPedido));
      }
      setState(() {
        _cargando = false;
        _error = 'Nota: Puede configurar la distribución manualmente.';
      });
    }
  }

  double get _sumaAsignada =>
      _filas.fold(0.0, (acc, f) => acc + f.monto);

  double get _diferencia =>
      (_totalPedido > 0 ? _totalPedido : _sumaAsignada) - _sumaAsignada;

  bool get _esValido {
    if (_guardando || _filas.isEmpty) return false;
    if (_motivo.text.trim().isEmpty) return false;
    for (final f in _filas) {
      if (f.medio == null || f.monto <= 0) return false;
    }
    if (_totalPedido > 0 && (_diferencia.abs() > 0.01)) return false;
    return true;
  }

  void _agregarFila() {
    final restante = _diferencia > 0 ? _diferencia : 0.0;
    setState(() {
      _filas.add(_FilaDistribucion(
        medio: _medios.firstOrNull,
        monto: restante,
      ));
    });
  }

  void _eliminarFila(int idx) {
    if (_filas.length <= 1) return;
    setState(() {
      final f = _filas.removeAt(idx);
      f.montoCtrl.dispose();
    });
  }

  Future<void> _guardar() async {
    if (!_esValido) return;
    setState(() => _guardando = true);

    try {
      final payloadDistrib = _filas.map((f) => {
        'medio_pago_id': f.medio!.id,
        'monto_abonado': f.monto,
      }).toList();

      await PagoService.instance.redistribuirPagos(
        pedidoId: widget.pedidoId,
        motivo: _motivo.text.trim(),
        distribucion: payloadDistrib,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _guardando = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DialogoApp(
      titulo: 'Dividir / Reasignar Métodos de Pago',
      ancho: 520,
      acciones: [
        OutlinedButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _esValido ? _guardar : null,
          icon: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(LucideIcons.check, size: 16),
          label: Text(_guardando ? 'Guardando...' : 'Confirmar Reasignación'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
        ),
      ],
      children: [
        if (_ordenComanda != null && _ordenComanda! > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.receipt, size: 18, color: Colors.teal.shade800),
                    const SizedBox(width: 8),
                    Text(
                      'Comanda #$_ordenComanda',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade900,
                        fontSize: 14,
                      ),
                    ),
                    if (_clienteNombre.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '· $_clienteNombre',
                        style: TextStyle(color: Colors.teal.shade700, fontSize: 13),
                      ),
                    ],
                  ],
                ),
                if (_totalPedido > 0)
                  Text(
                    'Total: S/ ${_totalPedido.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.teal.shade900,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        Text(
          'Permite corregir o dividir el pago en múltiples medios (ej. parte en Yape y parte en Efectivo) '
          'sin anular el pedido ni descuadrar la caja.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 14),
        if (_cargando)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final fila = _filas[idx];
              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: AppSelect<MedioPago>(
                      compacto: true,
                      value: fila.medio,
                      hint: 'Método de pago',
                      items: [
                        for (final m in _medios)
                          AppSelectItem(value: m, label: m.medioPago),
                      ],
                      onChanged: (nuevo) => setState(() => fila.medio = nuevo),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: CampoTexto(
                      controller: fila.montoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixText: 'S/ ',
                        labelText: 'Monto',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _filas.length > 1 ? () => _eliminarFila(idx) : null,
                    icon: Icon(
                      LucideIcons.trash2,
                      size: 18,
                      color: _filas.length > 1 ? Colors.red.shade400 : Colors.grey.shade300,
                    ),
                    tooltip: 'Quitar método',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _agregarFila,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Agregar otro método de pago'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
            ),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Suma asignada: S/ ${_sumaAsignada.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (_totalPedido > 0)
                Text(
                  _diferencia.abs() <= 0.01
                      ? '✓ Monto exacto cubierto'
                      : (_diferencia > 0
                          ? 'Faltan: S/ ${_diferencia.toStringAsFixed(2)}'
                          : 'Excede: S/ ${(-_diferencia).toStringAsFixed(2)}'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _diferencia.abs() <= 0.01
                        ? AppColors.primaryGreen
                        : AppColors.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          CampoTexto(
            controller: _motivo,
            maxLength: 120,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Motivo de la reasignación',
              counterText: '',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 12, color: Colors.red.shade800),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

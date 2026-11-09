import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/configuracion_store.dart';
import '../models/medio_pago.dart';
import '../models/movimiento_caja.dart';
import '../services/facturacion_service.dart';
import '../services/impresion_service.dart';
import '../services/pago_service.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';
import 'campo_texto.dart';
import 'dialogo_app.dart';

class DescargoPagoDialog extends StatefulWidget {
  final MovimientoCaja movimiento;

  const DescargoPagoDialog({super.key, required this.movimiento});

  @override
  State<DescargoPagoDialog> createState() => _DescargoPagoDialogState();
}

class _DescargoPagoDialogState extends State<DescargoPagoDialog> {
  late final List<MedioPago> _medios = mediosPagoActivos;
  MedioPago? _nuevoMedio;
  final _motivo = TextEditingController();
  bool _reimprimir = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    // Preseleccionar un método distinto al actual si existe
    _nuevoMedio = _medios
        .where((m) => m.id != widget.movimiento.medioPagoId)
        .firstOrNull ??
        _medios.firstOrNull;
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  bool get _valido =>
      _nuevoMedio != null &&
      _nuevoMedio!.id != widget.movimiento.medioPagoId &&
      _motivo.text.trim().isNotEmpty &&
      !_guardando;

  double get _montoBase => widget.movimiento.monto;

  double get _recargoNuevo {
    if (_nuevoMedio == null || !_nuevoMedio!.aplicaComision) return 0.0;
    return (_montoBase * _nuevoMedio!.porcentajeComision / 100);
  }

  double get _totalNuevo => _montoBase + _recargoNuevo;

  Future<void> _ejecutarDescargo() async {
    if (!_valido) return;
    setState(() => _guardando = true);

    try {
      final pagoId = widget.movimiento.pagoId;
      if (pagoId == null || pagoId.isEmpty) {
        throw Exception(
          'Este movimiento no tiene un ID de pago asociado para rectificar.',
        );
      }

      final resDescargo = await PagoService.instance.rectificarPago(
        pagoId: pagoId,
        nuevoMedioPagoId: _nuevoMedio!.id,
        motivo: _motivo.text.trim(),
      );

      // Si se solicitó reimprimir comprobante / precuenta
      if (_reimprimir) {
        try {
          final compId = resDescargo['comprobante_id'] as String?;
          if (compId != null && compId.isNotEmpty) {
            await FacturacionService.instance.reimprimir(compId);
          } else if (widget.movimiento.pedidosId != null) {
            await ImpresionService.instance.reimprimirPedido(
              widget.movimiento.pedidosId!,
              tipo: 'cuenta',
            );
          }
        } catch (_) {
          // Si la impresora térmica no responde, no bloquea el descargo financiero
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.movimiento;
    final medioActual = m.medioPagoNombre;

    return DialogoApp(
      titulo: 'Descargo / Rectificación de cobro',
      ancho: 460,
      acciones: [
        OutlinedButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _valido ? _ejecutarDescargo : null,
          icon: _guardando
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(LucideIcons.checkCheck, size: 16),
          label: Text(_guardando ? 'Guardando...' : 'Aplicar Descargo'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
          ),
        ),
      ],
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.triangleAlert, size: 20, color: Colors.amber.shade800),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'El descargo corregirá la forma de pago en la caja y en el pedido para que el arqueo cuadre exactamente.',
                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Resumen del cobro original
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Monto abonado:', style: TextStyle(fontSize: 13)),
                  Text(
                    'S/ ${_montoBase.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Método original marcado:', style: TextStyle(fontSize: 13)),
                  Text(
                    medioActual,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'Nuevo método de pago real',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        AppSelect<MedioPago>(
          value: _nuevoMedio,
          items: [
            for (final mp in _medios)
              AppSelectItem<MedioPago>(
                value: mp,
                label:
                    '${mp.medioPago}${mp.aplicaComision && mp.porcentajeComision > 0 ? ' (+${mp.porcentajeComision.toStringAsFixed(1)}% recargo)' : ''}',
              ),
          ],
          onChanged: (v) => setState(() => _nuevoMedio = v),
        ),

        if (_recargoNuevo > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recargo ${_nuevoMedio!.porcentajeComision.toStringAsFixed(1)}%:',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                ),
                Text(
                  '+S/ ${_recargoNuevo.toStringAsFixed(2)} (Total: S/ ${_totalNuevo.toStringAsFixed(2)})',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),
        const Text(
          'Motivo o justificación del descargo (obligatorio)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        CampoTexto(
          controller: _motivo,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Ej. Error de digitación en caja: se cobró por Yape pero se marcó Efectivo...',
          ),
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: 12),
        CheckboxListTile(
          value: _reimprimir,
          onChanged: (v) => setState(() => _reimprimir = v ?? true),
          title: const Text('Reimprimir precuenta/ticket con el nuevo método', style: TextStyle(fontSize: 13)),
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }
}

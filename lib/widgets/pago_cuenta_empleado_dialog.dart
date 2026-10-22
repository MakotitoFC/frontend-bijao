import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/configuracion_store.dart';
import '../models/pago_cuenta_empleado.dart';
import '../models/utensilio_roto.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/uuid_helper.dart';
import 'app_select.dart';
import 'app_toast.dart';
import 'dialogo_app.dart';
import 'campo_texto.dart';

class PagoCuentaEmpleadoDialog extends StatefulWidget {
  final UtensilioRoto rotura;

  const PagoCuentaEmpleadoDialog({super.key, required this.rotura});

  @override
  State<PagoCuentaEmpleadoDialog> createState() =>
      _PagoCuentaEmpleadoDialogState();
}

class _PagoCuentaEmpleadoDialogState extends State<PagoCuentaEmpleadoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _montoController;
  final _notaController = TextEditingController();

  // Medios de pago comunes de la base de datos
  List<({String id, String label})> get _mediosPago =>
      mediosPagoActivos.map((m) => (id: m.id, label: m.medioPago)).toList();

  late String _medioPagoSeleccionadoId;
  bool _guardando = false;

  double get _saldoPendiente =>
      (widget.rotura.costoTotal - widget.rotura.totalPagado).clamp(
        0.0,
        widget.rotura.costoTotal,
      );

  @override
  void initState() {
    super.initState();
    _medioPagoSeleccionadoId = _mediosPago.isNotEmpty
        ? _mediosPago.first.id
        : '';
    _montoController = TextEditingController(
      text: _saldoPendiente > 0 ? _saldoPendiente.toStringAsFixed(2) : '0.00',
    );
  }

  @override
  void dispose() {
    _montoController.dispose();
    _notaController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final monto = double.tryParse(_montoController.text.trim()) ?? 0.0;
    if (monto <= 0) {
      showAppToast(
        context,
        'El monto debe ser mayor a cero',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final userActual = AuthService.instance.usuarioActual;
      final nuevoPago = PagoCuentaEmpleado(
        id: UuidHelper.v7(),
        empleadoId: widget.rotura.empleadoId,
        monto: monto,
        medioPagoId: _medioPagoSeleccionadoId,
        utensilioRotoId: widget.rotura.id,
        usuarioId: userActual?.id ?? '',
        nota: _notaController.text.trim().isEmpty
            ? null
            : _notaController.text.trim(),
        createdAt: DateTime.now(),
      );

      await CatalogService.instance.crearPagoCuentaEmpleado(nuevoPago);
      if (!mounted) return;
      showAppToast(
        context,
        'Abono registrado a cuenta del empleado',
        type: ToastType.success,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'Error al registrar abono: $e',
          type: ToastType.error,
        );
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DialogoApp(
      titulo: 'Registrar abono',
      ancho: 460,
      acciones: [
        OutlinedButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
          ),
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Confirmar pago'),
        ),
      ],
      children: [
        Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pago a cuenta de empleado por rotura',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),
              // Resumen de la deuda
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Responsable:',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          widget.rotura.empleadoNombre ?? 'Empleado',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Utensilio:',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '${widget.rotura.cantidad}x ${widget.rotura.productoNombre ?? "Item"}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Deuda total:',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'S/ ${widget.rotura.costoTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ya abonado:',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'S/ ${widget.rotura.totalPagado.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Saldo pendiente:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'S/ ${_saldoPendiente.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Campo Monto
              CampoTexto(
                controller: _montoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: 'Monto a pagar (S/) *',
                  hintText: '0.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixText: 'S/ ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El monto es obligatorio';
                  }
                  final numVal = double.tryParse(v.trim());
                  if (numVal == null || numVal <= 0) return 'Monto inválido';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Medio de pago
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Medio de pago *',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AppSelect<String>(
                    hint: 'Selecciona medio de pago',
                    value: _medioPagoSeleccionadoId,
                    items: _mediosPago
                        .map((m) => AppSelectItem(value: m.id, label: m.label))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _medioPagoSeleccionadoId = v!),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Nota
              CampoTexto(
                controller: _notaController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Nota / Comprobante (opcional)',
                  hintText: 'Ej. Descuento en planilla o abono en caja...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

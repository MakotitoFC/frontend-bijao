import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../models/pago_cuenta_empleado.dart';
import '../models/utensilio_roto.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/uuid_helper.dart';
import 'app_select.dart';
import 'app_toast.dart';

class PagoCuentaEmpleadoDialog extends StatefulWidget {
  final UtensilioRoto rotura;

  const PagoCuentaEmpleadoDialog({super.key, required this.rotura});

  @override
  State<PagoCuentaEmpleadoDialog> createState() => _PagoCuentaEmpleadoDialogState();
}

class _PagoCuentaEmpleadoDialogState extends State<PagoCuentaEmpleadoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _montoController;
  final _notaController = TextEditingController();

  // Medios de pago comunes de la base de datos
  final List<({String id, String label})> _mediosPago = [
    (id: '66666666-6666-6666-6666-666666666661', label: 'Efectivo'),
    (id: '66666666-6666-6666-6666-666666666662', label: 'Yape'),
    (id: '66666666-6666-6666-6666-666666666663', label: 'Plin'),
    (id: '66666666-6666-6666-6666-666666666664', label: 'Tarjeta Visa/Mastercard'),
  ];

  late String _medioPagoSeleccionadoId;
  bool _guardando = false;

  double get _saldoPendiente =>
      (widget.rotura.costoTotal - widget.rotura.totalPagado).clamp(0.0, widget.rotura.costoTotal);

  @override
  void initState() {
    super.initState();
    _medioPagoSeleccionadoId = _mediosPago.first.id;
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
      showAppToast(context, 'El monto debe ser mayor a cero', type: ToastType.error);
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
        nota: _notaController.text.trim().isEmpty ? null : _notaController.text.trim(),
        createdAt: DateTime.now(),
      );

      await CatalogService.instance.crearPagoCuentaEmpleado(nuevoPago);
      if (!mounted) return;
      showAppToast(context, 'Abono registrado a cuenta del empleado', type: ToastType.success);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Error al registrar abono: $e', type: ToastType.error);
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecera
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.wallet, color: AppColors.primaryGreen, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Registrar Abono / Pago',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Pago a cuenta de empleado por rotura',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

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
                          Text('Responsable:', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                          Text(
                            widget.rotura.empleadoNombre ?? 'Empleado',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Utensilio:', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                          Text(
                            '${widget.rotura.cantidad}x ${widget.rotura.productoNombre ?? "Item"}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Deuda total:', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                          Text('S/ ${widget.rotura.costoTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Ya abonado:', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                          Text('S/ ${widget.rotura.totalPagado.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13, color: Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Saldo pendiente:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(
                            'S/ ${_saldoPendiente.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Campo Monto
                TextFormField(
                  controller: _montoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  decoration: InputDecoration(
                    labelText: 'Monto a pagar (S/) *',
                    hintText: '0.00',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.attach_money, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'El monto es obligatorio';
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
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                    ),
                    const SizedBox(height: 6),
                    AppSelect<String>(
                      hint: 'Selecciona medio de pago',
                      value: _medioPagoSeleccionadoId,
                      items: _mediosPago
                          .map((m) => AppSelectItem(value: m.id, label: m.label))
                          .toList(),
                      onChanged: (v) => setState(() => _medioPagoSeleccionadoId = v!),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Nota
                TextFormField(
                  controller: _notaController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Nota / Comprobante (opcional)',
                    hintText: 'Ej. Descuento en planilla o abono en caja...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 22),

                // Botones Cancelar / Guardar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      icon: _guardando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text('Confirmar pago'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/medio_pago.dart';
import '../services/api_client.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import 'app_switch.dart';
import 'dialogo_app.dart';

// Crea o edita un método de pago. Devuelve true si se guardó.
class MedioPagoDialog extends StatefulWidget {
  final MedioPago? medio;

  const MedioPagoDialog({super.key, this.medio});

  @override
  State<MedioPagoDialog> createState() => _MedioPagoDialogState();
}

class _MedioPagoDialogState extends State<MedioPagoDialog> {
  late final _nombre = TextEditingController(text: widget.medio?.medioPago);
  late final _descripcion = TextEditingController(
    text: widget.medio?.descripcion,
  );
  late final _porcentaje = TextEditingController(
    text: (widget.medio?.porcentajeComision ?? 0) > 0
        ? widget.medio!.porcentajeComision.toString()
        : '',
  );
  late bool _comision = widget.medio?.aplicaComision ?? false;
  bool _guardando = false;
  String? _error;

  bool get _editando => widget.medio != null;

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _porcentaje.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe el nombre del método de pago.');
      return;
    }
    final porcentaje =
        double.tryParse(_porcentaje.text.trim().replaceAll(',', '.')) ?? 0;
    if (_comision && (porcentaje <= 0 || porcentaje > 100)) {
      setState(() => _error = 'El porcentaje debe estar entre 0 y 100.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final servicio = CatalogService.instance;
      if (_editando) {
        await servicio.actualizarMedioPago(
          widget.medio!.id,
          nombre: nombre,
          descripcion: _descripcion.text,
          aplicaComision: _comision,
          porcentajeComision: _comision ? porcentaje : 0,
        );
      } else {
        await servicio.crearMedioPago(
          nombre: nombre,
          descripcion: _descripcion.text,
          aplicaComision: _comision,
          porcentajeComision: _comision ? porcentaje : 0,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = e is ApiException ? e.message : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DialogoApp(
      titulo: _editando ? 'Editar método de pago' : 'Nuevo método de pago',
      acciones: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
          ),
          child: Text(_editando ? 'Guardar' : 'Crear'),
        ),
      ],
      children: [
        CampoDialogo(
          etiqueta: 'Nombre',
          controller: _nombre,
          hint: 'Ej. Efectivo, Yape, Tarjeta',
          autofocus: true,
        ),
        const SizedBox(height: 14),
        CampoDialogo(
          etiqueta: 'Descripción (opcional)',
          controller: _descripcion,
          hint: 'Ej. Billetera digital',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recargo al cliente por usar este método',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Se suma al total que paga el cliente con este método (ej. tarjeta).',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AppSwitch(
              value: _comision,
              onChanged: (v) => setState(() => _comision = v),
            ),
          ],
        ),
        if (_comision) ...[
          const SizedBox(height: 12),
          CampoDialogo(
            etiqueta: 'Porcentaje (%)',
            controller: _porcentaje,
            hint: 'Ej. 4',
            teclado: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(fontSize: 12, color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

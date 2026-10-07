import 'package:flutter/material.dart';

import '../models/taper.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';

/// Modal dialog para crear o editar un Táper (tabla `taper` en BD.txt).
/// Columnas: id, nombre, precio, estado, sede_id, created_at.
class TaperFormDialog extends StatefulWidget {
  final Taper? taper; // null = nuevo táper

  const TaperFormDialog({super.key, this.taper});

  @override
  State<TaperFormDialog> createState() => _TaperFormDialogState();
}

class _TaperFormDialogState extends State<TaperFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _precioController;
  late bool _estado;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.taper?.nombre ?? '');
    _precioController = TextEditingController(
      text: widget.taper != null ? widget.taper!.precio.toStringAsFixed(2) : '',
    );
    _estado = widget.taper?.estado ?? true;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final nombre = _nombreController.text.trim();
    final precio = double.tryParse(_precioController.text.trim());
    if (precio == null || precio < 0) {
      showAppToast(context, 'Ingresa un precio válido mayor o igual a 0',
          type: ToastType.error);
      return;
    }

    setState(() => _guardando = true);

    try {
      final sedeActual = widget.taper?.sedeId ??
          AuthService.instance.currentUser?.sedeId;

      if (widget.taper != null) {
        // Actualizar existente
        final actualizado = await CatalogService.instance.actualizarTaper(
          widget.taper!.id,
          nombre: nombre,
          precio: precio,
          estado: _estado,
          sedeId: sedeActual,
        );
        if (!mounted) return;
        Navigator.of(context).pop(actualizado);
        showAppToast(context, 'Táper actualizado correctamente',
            type: ToastType.success);
      } else {
        // Crear nuevo
        final nuevo = await CatalogService.instance.crearTaper(
          nombre: nombre,
          precio: precio,
          sedeId: sedeActual,
        );
        if (!mounted) return;
        Navigator.of(context).pop(nuevo);
        showAppToast(context, 'Táper creado correctamente',
            type: ToastType.success);
      }
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'Error al guardar táper: $e',
          type: ToastType.error);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.taper != null;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.takeout_dining,
              color: AppColors.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              editando ? 'Editar Táper' : 'Nuevo Táper',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Los tápers se usan para cobrar el empaque en pedidos para llevar o delivery.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreController,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Nombre del táper *',
                  hintText: 'Ej. Táper Mediano (Térmico)',
                  prefixIcon: Icon(Icons.label_outline, size: 20),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El nombre es requerido';
                  }
                  if (v.trim().length > 50) {
                    return 'Máximo 50 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _precioController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio (S/) *',
                  hintText: '0.00',
                  prefixText: 'S/ ',
                  prefixIcon: Icon(Icons.attach_money, size: 20),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El precio es requerido';
                  }
                  final n = double.tryParse(v.trim());
                  if (n == null || n < 0) {
                    return 'Precio inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Táper Activo',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: Text(
                  _estado
                      ? 'Disponible para vincular a platos y pedidos'
                      : 'Inactivo: no se mostrará en las opciones de venta',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                value: _estado,
                activeThumbColor: AppColors.primaryGreen,
                onChanged: (val) => setState(() => _estado = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
          icon: _guardando
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check, size: 16),
          label: Text(editando ? 'Guardar cambios' : 'Crear táper'),
        ),
      ],
    );
  }
}

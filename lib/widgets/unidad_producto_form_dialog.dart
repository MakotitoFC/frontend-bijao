import 'package:flutter/material.dart';

import '../models/unidad_producto.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import 'app_switch.dart';
import 'app_toast.dart';
import 'campo_texto.dart';
import 'dialogo_app.dart';

// Alta y edición de una unidad de medida del inventario.
class UnidadProductoFormDialog extends StatefulWidget {
  final UnidadProducto? item;

  const UnidadProductoFormDialog({super.key, this.item});

  @override
  State<UnidadProductoFormDialog> createState() => _UnidadProductoFormDialogState();
}

class _UnidadProductoFormDialogState extends State<UnidadProductoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late bool _estado;
  late bool _esGlobal;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.item?.unidad ?? '');
    _estado = widget.item?.estado ?? true;
    _esGlobal = widget.item?.sedeId == null;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final user = AuthService.instance.usuarioActual;
      final sedeId = _esGlobal ? null : user?.sedeId;
      final nombre = _nombreController.text.trim();
      if (widget.item == null) {
        await CatalogService.instance.crearUnidadProducto(
          unidad: nombre,
          estado: _estado,
          sedeId: sedeId,
        );
        if (!mounted) return;
        showAppToast(context, 'Unidad de producto creada', type: ToastType.success);
      } else {
        await CatalogService.instance.actualizarUnidadProducto(
          widget.item!.id,
          unidad: nombre,
          estado: _estado,
          sedeId: sedeId,
        );
        if (!mounted) return;
        showAppToast(context, 'Unidad de producto actualizada', type: ToastType.success);
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Error: $e', type: ToastType.error);
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.item != null;
    return DialogoApp(
      titulo: editando ? 'Editar unidad' : 'Nueva unidad',
      ancho: 420,
      acciones: [
        OutlinedButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(editando ? 'Guardar cambios' : 'Crear unidad'),
        ),
      ],
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoTexto(
                controller: _nombreController,
                maxLength: 30,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Unidad de medida *',
                  hintText: 'Ej. Kg, Litro, Unidad, Paquete...',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'La unidad es obligatoria'
                    : null,
              ),
              const SizedBox(height: 12),
              AppSwitchTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Disponible en todas las sedes',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: Text(
                  _esGlobal
                      ? 'Se usa en todos los locales del restaurante'
                      : 'Solo se usa en la sede actual',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                value: _esGlobal,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primaryGreen,
                onChanged: (v) => setState(() => _esGlobal = v),
              ),
              AppSwitchTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Activo',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: Text(
                  _estado
                      ? 'Se puede elegir al registrar productos'
                      : 'Inactivo: no aparece al registrar productos',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                value: _estado,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primaryGreen,
                onChanged: (v) => setState(() => _estado = v),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

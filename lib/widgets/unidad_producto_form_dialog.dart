import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/unidad_producto.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';

class UnidadProductoFormDialog extends StatefulWidget {
  final UnidadProducto? item;

  const UnidadProductoFormDialog({super.key, this.item});

  @override
  State<UnidadProductoFormDialog> createState() => _UnidadProductoFormDialogState();
}

class _UnidadProductoFormDialogState extends State<UnidadProductoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _unidadController;
  late bool _estado;
  late bool _esGlobal;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _unidadController = TextEditingController(text: widget.item?.unidad ?? '');
    _estado = widget.item?.estado ?? true;
    _esGlobal = widget.item?.sedeId == null;
  }

  @override
  void dispose() {
    _unidadController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      final user = AuthService.instance.usuarioActual;
      final sedeId = _esGlobal ? null : user?.sedeId;
      final unidad = _unidadController.text.trim();

      if (widget.item == null) {
        await CatalogService.instance.crearUnidadProducto(
          unidad: unidad,
          estado: _estado,
          sedeId: sedeId,
        );
        if (!mounted) return;
        showAppToast(context, 'Unidad de producto creada', type: ToastType.success);
      } else {
        Navigator.of(context).pop(true);
        return;
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.scale, color: Colors.purple, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item == null ? 'Nueva Unidad de Producto' : 'Editar Unidad',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Unidad de medida (Kg, Litro, Unidad, Porción, etc.)',
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
                const SizedBox(height: 20),

                TextFormField(
                  controller: _unidadController,
                  maxLength: 30,
                  decoration: InputDecoration(
                    labelText: 'Unidad de medida *',
                    hintText: 'Ej. Kg, Litro, Unidad, Paquete...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(LucideIcons.weight, size: 18),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'La unidad es obligatoria';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _esGlobal ? LucideIcons.globe : LucideIcons.mapPin,
                        size: 20,
                        color: _esGlobal ? AppColors.primaryGreen : Colors.blueGrey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _esGlobal ? 'Todas las sedes (Global)' : 'Solo para mi sede',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _esGlobal
                                  ? 'Disponible en todos los locales'
                                  : 'Exclusivo para la sede actual',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _esGlobal,
                        activeTrackColor: AppColors.primaryGreen,
                        onChanged: (v) => setState(() => _esGlobal = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _estado = true),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _estado ? AppColors.primaryGreen.withValues(alpha: 0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _estado ? AppColors.primaryGreen : Colors.grey.shade300,
                              width: _estado ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: _estado ? AppColors.primaryGreen : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Activo',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _estado ? AppColors.primaryGreen : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _estado = false),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_estado ? Colors.grey.shade100 : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: !_estado ? Colors.grey.shade600 : Colors.grey.shade300,
                              width: !_estado ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.remove_circle_outline,
                                size: 16,
                                color: !_estado ? Colors.grey.shade700 : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Inactivo',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: !_estado ? Colors.grey.shade800 : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

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
                      label: Text(widget.item == null ? 'Crear unidad' : 'Guardar cambios'),
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

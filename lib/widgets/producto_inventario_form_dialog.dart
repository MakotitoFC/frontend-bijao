import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/catalogos_store.dart';
import '../models/producto_inventario.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/uuid_helper.dart';
import 'app_select.dart';
import 'app_toast.dart';

/// Modal de creación y edición de Producto de Inventario (`producto_inventario`).
/// Cumple exactamente con la estética oficial y las columnas de BD.txt.
class ProductoInventarioFormDialog extends StatefulWidget {
  final ProductoInventario? producto; // null = nuevo

  const ProductoInventarioFormDialog({super.key, this.producto});

  @override
  State<ProductoInventarioFormDialog> createState() =>
      _ProductoInventarioFormDialogState();
}

class _ProductoInventarioFormDialogState
    extends State<ProductoInventarioFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _stockActualController;
  late final TextEditingController _stockMinimoController;
  late final TextEditingController _costoReposicionController;
  late final TextEditingController _notasController;

  String? _tipoProductoId;
  String? _tipoSeguimientoId;
  String? _unidadProductoId;
  late bool _estado; // true = Activo/Disponible, false = Inactivo/Agotado
  bool _guardando = false;

  bool get _esEdicion => widget.producto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;

    _nombreController = TextEditingController(text: p?.nombre ?? '');
    _descripcionController = TextEditingController(text: p?.descripcion ?? '');
    _stockActualController = TextEditingController(
      text: p != null ? _formatearNumero(p.stockActual) : '0',
    );
    _stockMinimoController = TextEditingController(
      text: p != null ? _formatearNumero(p.stockMinimo) : '0',
    );
    _costoReposicionController = TextEditingController(
      text: p?.costoReposicion != null ? p!.costoReposicion!.toStringAsFixed(2) : '',
    );
    _notasController = TextEditingController(text: p?.notas ?? '');

    _estado = p?.estado ?? true;

    // Inicializar IDs seleccionados
    _tipoProductoId = p?.tipoProductoId ?? (tiposProducto.isNotEmpty ? tiposProducto.first.id : null);
    _tipoSeguimientoId = p?.tipoSeguimientoId ?? (tiposSeguimiento.isNotEmpty ? tiposSeguimiento.first.id : null);
    _unidadProductoId = p?.unidadProductoId ?? (unidadesProducto.isNotEmpty ? unidadesProducto.first.id : null);

    _asegurarCatalogosCargados();
  }

  String _formatearNumero(double n) {
    if (n % 1 == 0) return n.toInt().toString();
    return n.toString();
  }

  Future<void> _asegurarCatalogosCargados() async {
    bool recargar = false;
    if (tiposProducto.isEmpty) {
      await CatalogService.instance.cargarTiposProducto();
      recargar = true;
    }
    if (tiposSeguimiento.isEmpty) {
      await CatalogService.instance.cargarTiposSeguimiento();
      recargar = true;
    }
    if (unidadesProducto.isEmpty) {
      await CatalogService.instance.cargarUnidadesProducto();
      recargar = true;
    }
    if (recargar && mounted) {
      setState(() {
        _tipoProductoId ??= tiposProducto.isNotEmpty ? tiposProducto.first.id : null;
        _tipoSeguimientoId ??= tiposSeguimiento.isNotEmpty ? tiposSeguimiento.first.id : null;
        _unidadProductoId ??= unidadesProducto.isNotEmpty ? unidadesProducto.first.id : null;
      });
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _stockActualController.dispose();
    _stockMinimoController.dispose();
    _costoReposicionController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_tipoProductoId == null || _tipoProductoId!.isEmpty) {
      showAppToast(context, 'Selecciona un tipo de producto', type: ToastType.error);
      return;
    }
    if (_tipoSeguimientoId == null || _tipoSeguimientoId!.isEmpty) {
      showAppToast(context, 'Selecciona un tipo de seguimiento', type: ToastType.error);
      return;
    }
    if (_unidadProductoId == null || _unidadProductoId!.isEmpty) {
      showAppToast(context, 'Selecciona una unidad de medida', type: ToastType.error);
      return;
    }

    final stockAct = double.tryParse(_stockActualController.text.trim()) ?? 0.0;
    if (stockAct < 0) {
      showAppToast(context, 'El stock actual no puede ser menor a 0', type: ToastType.error);
      return;
    }

    final stockMin = double.tryParse(_stockMinimoController.text.trim()) ?? 0.0;
    if (stockMin < 0) {
      showAppToast(context, 'El stock mínimo no puede ser menor a 0', type: ToastType.error);
      return;
    }

    double? costoRepo;
    if (_costoReposicionController.text.trim().isNotEmpty) {
      costoRepo = double.tryParse(_costoReposicionController.text.trim());
      if (costoRepo == null || costoRepo < 0) {
        showAppToast(context, 'El costo de reposición debe ser un número mayor o igual a 0', type: ToastType.error);
        return;
      }
    }

    setState(() => _guardando = true);

    try {
      final user = AuthService.instance.usuarioActual;
      final nuevoId = widget.producto?.id ?? UuidHelper.v7();

      final producto = ProductoInventario(
        id: nuevoId,
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim().isEmpty ? null : _descripcionController.text.trim(),
        tipoProductoId: _tipoProductoId!,
        tipoSeguimientoId: _tipoSeguimientoId!,
        unidadProductoId: _unidadProductoId!,
        stockActual: stockAct,
        stockMinimo: stockMin,
        costoReposicion: costoRepo,
        notas: _notasController.text.trim().isEmpty ? null : _notasController.text.trim(),
        estado: _estado,
        sedeId: widget.producto?.sedeId ?? user?.sedeId,
      );

      ProductoInventario guardado;
      if (_esEdicion) {
        guardado = await CatalogService.instance.actualizarProductoInventario(producto);
        if (!mounted) return;
        showAppToast(context, 'Producto actualizado en inventario', type: ToastType.success);
      } else {
        guardado = await CatalogService.instance.crearProductoInventario(producto);
        if (!mounted) return;
        showAppToast(context, 'Producto registrado en inventario', type: ToastType.success);
      }

      Navigator.of(context).pop(guardado);
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Error al guardar producto: $e', type: ToastType.error);
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final esMobile = ancho < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: esMobile ? ancho * 0.95 : 540,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecera idéntica al diseño oficial
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.boxes,
                        color: AppColors.primaryGreen,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _esEdicion ? 'Editar producto de inventario' : 'Nuevo producto en inventario',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Configura los datos del producto según el inventario oficial',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 22),
                      splashRadius: 20,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Formulario con scroll
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Nombre del producto * (max 20 caracteres según BD.txt)
                        TextFormField(
                          controller: _nombreController,
                          maxLength: 20,
                          decoration: InputDecoration(
                            labelText: 'Nombre del producto *',
                            hintText: 'Ej. Plato Hondo, Copa, Arroz...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(LucideIcons.package2, size: 18),
                            counterText: '${_nombreController.text.length}/20',
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'El nombre es obligatorio';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // 2. Tipo de producto * (selector)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tipo de producto *',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                            ),
                            const SizedBox(height: 6),
                            AppSelect<String>(
                              hint: 'Selecciona tipo de producto',
                              value: _tipoProductoId,
                              items: tiposProducto
                                  .map((t) => AppSelectItem(value: t.id, label: t.tipoProducto))
                                  .toList(),
                              onChanged: (v) => setState(() => _tipoProductoId = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 3. Descripción (textarea)
                        TextFormField(
                          controller: _descripcionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Descripción',
                            hintText: 'Detalles, especificaciones o uso...',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 4. Tipo de seguimiento & Unidad de medida en fila
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tipo de seguimiento *',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                                  ),
                                  const SizedBox(height: 6),
                                  AppSelect<String>(
                                    hint: 'Seguimiento',
                                    value: _tipoSeguimientoId,
                                    items: tiposSeguimiento
                                        .map((s) => AppSelectItem(value: s.id, label: s.tipoSeguimiento))
                                        .toList(),
                                    onChanged: (v) => setState(() => _tipoSeguimientoId = v),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Unidad de medida *',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                                  ),
                                  const SizedBox(height: 6),
                                  AppSelect<String>(
                                    hint: 'Unidad',
                                    value: _unidadProductoId,
                                    items: unidadesProducto
                                        .map((u) => AppSelectItem(value: u.id, label: u.unidad))
                                        .toList(),
                                    onChanged: (v) => setState(() => _unidadProductoId = v),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 5. Stock Actual, Stock Mínimo y Costo de reposición
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _stockActualController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Stock actual *',
                                  hintText: '0',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Requerido';
                                  final numVal = double.tryParse(v.trim());
                                  if (numVal == null || numVal < 0) return '>= 0';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _stockMinimoController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Stock mínimo',
                                  hintText: '0',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) {
                                  if (v != null && v.trim().isNotEmpty) {
                                    final numVal = double.tryParse(v.trim());
                                    if (numVal == null || numVal < 0) return '>= 0';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _costoReposicionController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Costo repos. (S/)',
                                  hintText: '0.00',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) {
                                  if (v != null && v.trim().isNotEmpty) {
                                    final numVal = double.tryParse(v.trim());
                                    if (numVal == null || numVal < 0) return '>= 0';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 6. Notas (opcional)
                        TextFormField(
                          controller: _notasController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Notas adicionales (opcional)',
                            hintText: 'Proveedor habitual, ubicación o lote...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 7. Estado del producto (exacto al diseño de la imagen)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estado en el inventario',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _estado = true),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _estado
                                            ? AppColors.primaryGreen.withValues(alpha: 0.08)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _estado ? AppColors.primaryGreen : Colors.grey.shade300,
                                          width: _estado ? 1.8 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            size: 18,
                                            color: _estado ? AppColors.primaryGreen : Colors.grey.shade400,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Disponible',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                              color: _estado ? AppColors.primaryGreen : Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _estado = false),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: !_estado
                                            ? Colors.grey.shade100
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: !_estado ? Colors.grey.shade700 : Colors.grey.shade300,
                                          width: !_estado ? 1.8 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.remove_circle_outline,
                                            size: 18,
                                            color: !_estado ? Colors.grey.shade800 : Colors.grey.shade400,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Agotado',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                              color: !_estado ? Colors.grey.shade900 : Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 24),

                // 8. Botones de acción inferiores
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      ),
                      icon: _guardando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(
                        _esEdicion ? 'Guardar cambios' : 'Crear producto',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
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

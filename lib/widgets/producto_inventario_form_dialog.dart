import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/catalogos_store.dart';
import '../data/inventario_store.dart';
import '../models/producto_inventario.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/uuid_helper.dart';
import 'app_select.dart';
import 'app_toast.dart';
import 'dialogo_app.dart';
import 'campo_texto.dart';
import 'seccion_venta_producto.dart';

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
  final _ventaKey = GlobalKey<SeccionVentaProductoState>();

  late final TextEditingController _nombreController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _stockActualController;
  late final TextEditingController _stockMinimoController;
  late final TextEditingController _costoReposicionController;
  late final TextEditingController _notasController;

  String? _tipoProductoId;
  String _seguimiento = 'granel';
  String? _unidadProductoId;
  late bool _estado; // true = Activo/Disponible, false = Inactivo/Agotado
  bool _guardando = false;

  bool get _esEdicion => widget.producto != null;

  // Cómo se vende un producto nuevo. Si se vende (carta o táper), el formulario
  // se acorta: solo nombre, stock y mínimo; lo demás toma valores por defecto.
  ModoVentaProducto _modoVenta = ModoVentaProducto.noSeVende;
  // Último nombre puesto automáticamente desde la carta (para no pisar lo que
  // el usuario escribió a mano).
  String _nombreAuto = '';

  bool get _compacto =>
      !_esEdicion && _modoVenta != ModoVentaProducto.noSeVende;

  void _alCambiarVenta(ModoVentaProducto modo, String? cartaNombre) {
    if (_esEdicion) return;
    setState(() {
      _modoVenta = modo;
      if (modo == ModoVentaProducto.noSeVende) return;
      // Lo que se vende por unidad: pieza o botella, en "Unidad".
      _seguimiento = 'unidad';
      final unidad = unidadesProducto
          .where((u) => u.unidad.trim().toLowerCase() == 'unidad')
          .firstOrNull;
      if (unidad != null) _unidadProductoId = unidad.id;
      // Un tipo de bebida, si existe y todavía no se eligió otro.
      final porDefecto = tiposProducto.isNotEmpty
          ? tiposProducto.first.id
          : null;
      if (_tipoProductoId == null || _tipoProductoId == porDefecto) {
        final bebida = tiposProducto.where((t) {
          final n = t.tipoProducto.toLowerCase();
          return n.contains('gaseosa') || n.contains('bebida');
        }).firstOrNull;
        if (bebida != null) _tipoProductoId = bebida.id;
      }
      // El nombre sale de la carta si el usuario no escribió otro.
      if (cartaNombre != null &&
          (_nombreController.text.trim().isEmpty ||
              _nombreController.text == _nombreAuto)) {
        final n = cartaNombre.length > 20
            ? cartaNombre.substring(0, 20)
            : cartaNombre;
        _nombreController.text = n;
        _nombreAuto = n;
      }
    });
  }

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
      text: p?.costoReposicion != null
          ? p!.costoReposicion!.toStringAsFixed(2)
          : '',
    );
    _notasController = TextEditingController(text: p?.notas ?? '');

    _estado = p?.estado ?? true;

    // Inicializar IDs seleccionados
    _tipoProductoId =
        p?.tipoProductoId ??
        (tiposProducto.isNotEmpty ? tiposProducto.first.id : null);
    _seguimiento = p?.seguimiento ?? 'granel';
    _unidadProductoId =
        p?.unidadProductoId ??
        (unidadesProducto.isNotEmpty ? unidadesProducto.first.id : null);

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
    if (unidadesProducto.isEmpty) {
      await CatalogService.instance.cargarUnidadesProducto();
      recargar = true;
    }
    if (recargar && mounted) {
      setState(() {
        _tipoProductoId ??= tiposProducto.isNotEmpty
            ? tiposProducto.first.id
            : null;
        _unidadProductoId ??= unidadesProducto.isNotEmpty
            ? unidadesProducto.first.id
            : null;
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
      showAppToast(
        context,
        'Selecciona un tipo de producto',
        type: ToastType.error,
      );
      return;
    }
    if (_unidadProductoId == null || _unidadProductoId!.isEmpty) {
      showAppToast(
        context,
        'Selecciona una unidad de medida',
        type: ToastType.error,
      );
      return;
    }

    final stockAct = double.tryParse(_stockActualController.text.trim()) ?? 0.0;
    if (stockAct < 0) {
      showAppToast(
        context,
        'El stock actual no puede ser menor a 0',
        type: ToastType.error,
      );
      return;
    }

    final stockMin = double.tryParse(_stockMinimoController.text.trim()) ?? 0.0;
    if (stockMin < 0) {
      showAppToast(
        context,
        'El stock mínimo no puede ser menor a 0',
        type: ToastType.error,
      );
      return;
    }

    double? costoRepo;
    if (_costoReposicionController.text.trim().isNotEmpty) {
      costoRepo = double.tryParse(_costoReposicionController.text.trim());
      if (costoRepo == null || costoRepo < 0) {
        showAppToast(
          context,
          'El costo de reposición debe ser un número mayor o igual a 0',
          type: ToastType.error,
        );
        return;
      }
    }

    // La venta (carta o táper) se revisa antes de guardar nada.
    final errorVenta = _ventaKey.currentState?.validar();
    if (errorVenta != null) {
      showAppToast(context, errorVenta, type: ToastType.error);
      return;
    }

    setState(() => _guardando = true);

    try {
      final user = AuthService.instance.usuarioActual;
      final nuevoId = widget.producto?.id ?? UuidHelper.v7();

      final producto = ProductoInventario(
        id: nuevoId,
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim().isEmpty
            ? null
            : _descripcionController.text.trim(),
        tipoProductoId: _tipoProductoId!,
        seguimiento: _seguimiento,
        unidadProductoId: _unidadProductoId!,
        stockActual: stockAct,
        stockMinimo: stockMin,
        costoReposicion: costoRepo,
        costoPromedio: widget.producto?.costoPromedio ?? 0.0,
        notas: _notasController.text.trim().isEmpty
            ? null
            : _notasController.text.trim(),
        estado: _estado,
        sedeId: widget.producto?.sedeId ?? user?.sedeId,
      );

      ProductoInventario guardado;
      final venta = _ventaKey.currentState;
      if (!_esEdicion && venta != null && venta.esTaperNuevo) {
        // Un táper se crea con su servicio: el backend crea también su producto
        // de inventario y los enlaza.
        final taper = await CatalogService.instance.crearTaper(
          nombre: producto.nombre,
          precio: venta.precioTaper ?? 0,
          sedeId: producto.sedeId,
          stockInicial: stockAct,
          stockMinimo: stockMin,
        );
        await CatalogService.instance.cargarProductosInventario();
        final creado = productosInventario
            .where((p) => p.id == taper.productoInventarioId)
            .firstOrNull;
        if (!mounted) return;
        showAppToast(
          context,
          'Táper registrado en inventario',
          type: ToastType.success,
        );
        Navigator.of(context).pop(creado ?? producto);
        return;
      }
      if (_esEdicion) {
        guardado = await CatalogService.instance.actualizarProductoInventario(
          producto,
        );
        if (!mounted) return;
        showAppToast(
          context,
          'Producto actualizado en inventario',
          type: ToastType.success,
        );
      } else {
        guardado = await CatalogService.instance.crearProductoInventario(
          producto,
        );
        if (!mounted) return;
        showAppToast(
          context,
          'Producto registrado en inventario',
          type: ToastType.success,
        );
      }

      // Después del producto, su venta: qué producto de la carta lo descuenta o,
      // si es un táper, su precio. Si falla, el producto ya quedó guardado.
      final fallaVenta = await _ventaKey.currentState?.guardar(guardado.id);
      if (!mounted) return;
      if (fallaVenta != null) {
        showAppToast(
          context,
          'El producto se guardó, pero no se pudo guardar su venta: '
          '$fallaVenta',
          type: ToastType.error,
          duration: const Duration(seconds: 7),
        );
      }

      Navigator.of(context).pop(guardado);
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'Error al guardar producto: $e',
          type: ToastType.error,
        );
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DialogoApp(
      titulo: _esEdicion ? 'Editar producto' : 'Nuevo producto',
      ancho: 540,
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
              : Text(_esEdicion ? 'Guardar cambios' : 'Crear producto'),
        ),
      ],
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 0. Venta primero: carta (descuenta stock) o táper (precio).
              SeccionVentaProducto(
                key: _ventaKey,
                producto: widget.producto,
                onCambio: _alCambiarVenta,
              ),

              // 1. Nombre del producto * (max 20 caracteres según BD.txt)
              CampoTexto(
                controller: _nombreController,
                maxLength: 20,
                decoration: InputDecoration(
                  labelText: 'Nombre del producto *',
                  hintText: 'Ej. Plato Hondo, Copa, Arroz...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AppSelect<String>(
                    hint: 'Selecciona tipo de producto',
                    value: _tipoProductoId,
                    items: tiposProducto
                        .map(
                          (t) =>
                              AppSelectItem(value: t.id, label: t.tipoProducto),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _tipoProductoId = v),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. Descripción (textarea)
              if (!_compacto) ...[
                CampoTexto(
                  controller: _descripcionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Detalles, especificaciones o uso...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 4. Tipo de seguimiento & Unidad de medida: en fila si caben.
              LayoutBuilder(
                builder: (context, c) {
                  final angosto = c.maxWidth < 440;
                  final w = angosto ? c.maxWidth : (c.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: w,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tipo de seguimiento *',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            AppSelect<String>(
                              hint: 'Seguimiento',
                              value: _seguimiento,
                              items: const [
                                AppSelectItem(
                                  value: 'granel',
                                  label: 'Granel (Kg, Lt)',
                                ),
                                AppSelectItem(
                                  value: 'unidad',
                                  label: 'Unidad (Pieza, Bot)',
                                ),
                                AppSelectItem(
                                  value: 'individual',
                                  label: 'Individual (Pescado)',
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _seguimiento = v ?? 'granel'),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: w,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unidad de medida *',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            AppSelect<String>(
                              hint: 'Unidad',
                              value: _unidadProductoId,
                              items: unidadesProducto
                                  .map(
                                    (u) => AppSelectItem(
                                      value: u.id,
                                      label: u.unidad,
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _unidadProductoId = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // 5. Stock Actual, Stock Mínimo y Costo de reposición: tres en
              // fila si caben; en pantallas angostas, dos y uno.
              LayoutBuilder(
                builder: (context, c) {
                  final angosto = c.maxWidth < 440;
                  final w = (angosto || _compacto)
                      ? (c.maxWidth - 10) / 2
                      : (c.maxWidth - 20) / 3;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: w,
                        child: CampoTexto(
                          controller: _stockActualController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Stock actual *',
                            hintText: '0',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Requerido';
                            }
                            final numVal = double.tryParse(v.trim());
                            if (numVal == null || numVal < 0) return '>= 0';
                            return null;
                          },
                        ),
                      ),
                      SizedBox(
                        width: w,
                        child: CampoTexto(
                          controller: _stockMinimoController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Stock mínimo',
                            hintText: '0',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                      if (!_compacto)
                        SizedBox(
                          width: angosto ? c.maxWidth : w,
                          child: CampoTexto(
                            controller: _costoReposicionController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Costo repos. (S/)',
                              hintText: '0.00',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                  );
                },
              ),
              const SizedBox(height: 14),

              // 6. Notas (opcional)
              if (!_compacto) ...[
                CampoTexto(
                  controller: _notasController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notas adicionales (opcional)',
                    hintText: 'Proveedor habitual, ubicación o lote...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 8. Estado del producto (exacto al diseño de la imagen)
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
                                  ? AppColors.primaryGreen.withValues(
                                      alpha: 0.08,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _estado
                                    ? AppColors.primaryGreen
                                    : Colors.grey.shade300,
                                width: _estado ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                  color: _estado
                                      ? AppColors.primaryGreen
                                      : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Disponible',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: _estado
                                          ? AppColors.primaryGreen
                                          : Colors.grey.shade700,
                                    ),
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
                                color: !_estado
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                                width: !_estado ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.remove_circle_outline,
                                  size: 18,
                                  color: !_estado
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Agotado',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: !_estado
                                          ? Colors.grey.shade900
                                          : Colors.grey.shade700,
                                    ),
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
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

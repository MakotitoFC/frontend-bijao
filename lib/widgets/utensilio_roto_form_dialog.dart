import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/inventario_store.dart';
import '../models/producto_inventario.dart';
import '../models/rbac.dart';
import '../models/utensilio_roto.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/uuid_helper.dart';
import 'app_toast.dart';

class UtensilioRotoFormDialog extends StatefulWidget {
  const UtensilioRotoFormDialog({super.key});

  @override
  State<UtensilioRotoFormDialog> createState() =>
      _UtensilioRotoFormDialogState();
}

class _UtensilioRotoFormDialogState extends State<UtensilioRotoFormDialog> {
  final _formKey = GlobalKey<FormState>();

  final _productoSearchController = TextEditingController();
  final _empleadoSearchController = TextEditingController();
  final _cantidadController = TextEditingController(text: '1');
  final _costoReposicionController = TextEditingController();
  final _costoTotalController = TextEditingController();
  final _notasController = TextEditingController();

  final FocusNode _productoFocusNode = FocusNode();
  final FocusNode _empleadoFocusNode = FocusNode();

  List<ProductoInventario> _productos = [];
  List<UserRBACModel> _empleados = [];

  ProductoInventario? _productoSeleccionado;
  UserRBACModel? _empleadoSeleccionado;

  bool _mostrarDropdownProducto = false;
  bool _mostrarDropdownEmpleado = false;

  bool _isPagado = true;
  bool _isRepuesto = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();

    _productoFocusNode.addListener(() {
      if (_productoFocusNode.hasFocus) {
        setState(() => _mostrarDropdownProducto = true);
      }
    });

    _empleadoFocusNode.addListener(() {
      if (_empleadoFocusNode.hasFocus) {
        setState(() => _mostrarDropdownEmpleado = true);
      }
    });
  }

  Future<void> _cargarDatos() async {
    if (productosInventario.isEmpty) {
      await CatalogService.instance.cargarProductosInventario();
    }
    final emps = await CatalogService.instance.cargarUsuariosRBAC();
    if (mounted) {
      setState(() {
        _productos = List.from(productosInventario);
        _empleados = emps;
      });
    }
  }

  @override
  void dispose() {
    _productoSearchController.dispose();
    _empleadoSearchController.dispose();
    _cantidadController.dispose();
    _costoReposicionController.dispose();
    _costoTotalController.dispose();
    _notasController.dispose();
    _productoFocusNode.dispose();
    _empleadoFocusNode.dispose();
    super.dispose();
  }

  void _seleccionarProducto(ProductoInventario p) {
    setState(() {
      _productoSeleccionado = p;
      _productoSearchController.text = p.nombre;
      _mostrarDropdownProducto = false;

      final costoRepo = p.costoReposicion ?? 0.0;
      if (costoRepo > 0) {
        _costoReposicionController.text = costoRepo.toStringAsFixed(2);
      } else {
        _costoReposicionController.clear();
      }
      _recalcularCostoTotal();
    });
    _productoFocusNode.unfocus();
  }

  void _seleccionarEmpleado(UserRBACModel e) {
    setState(() {
      _empleadoSeleccionado = e;
      _empleadoSearchController.text = '${e.usuario} (${e.rolNombre})';
      _mostrarDropdownEmpleado = false;
    });
    _empleadoFocusNode.unfocus();
  }

  void _recalcularCostoTotal() {
    final cantidad = int.tryParse(_cantidadController.text.trim()) ?? 0;
    final costoUnitario = double.tryParse(_costoReposicionController.text.trim()) ?? 0.0;
    final total = (cantidad > 0 && costoUnitario > 0) ? (cantidad * costoUnitario) : 0.0;
    _costoTotalController.text = total.toStringAsFixed(2);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_productoSeleccionado == null) {
      showAppToast(context, 'Selecciona un producto del inventario', type: ToastType.error);
      return;
    }
    if (_empleadoSeleccionado == null) {
      showAppToast(context, 'Selecciona al empleado responsable', type: ToastType.error);
      return;
    }

    final cantidad = int.tryParse(_cantidadController.text.trim()) ?? 0;
    if (cantidad <= 0) {
      showAppToast(context, 'La cantidad debe ser mayor a cero (0)', type: ToastType.error);
      return;
    }

    final costoRepo = double.tryParse(_costoReposicionController.text.trim()) ?? 0.0;
    if (costoRepo <= 0) {
      showAppToast(context, 'Ingresa un costo de reposición válido mayor a cero', type: ToastType.error);
      return;
    }

    final costoTotal = cantidad * costoRepo;

    setState(() => _guardando = true);

    try {
      final userActual = AuthService.instance.usuarioActual;

      // Si el producto no tenía costo de reposición o cambió, actualizarlo en producto_inventario
      if (_productoSeleccionado!.costoReposicion != costoRepo) {
        await CatalogService.instance.actualizarCostoReposicion(_productoSeleccionado!.id, costoRepo);
      }

      final nuevoId = UuidHelper.v7();
      final rotura = UtensilioRoto(
        id: nuevoId,
        productoInventarioId: _productoSeleccionado!.id,
        productoNombre: _productoSeleccionado!.nombre,
        empleadoId: _empleadoSeleccionado!.id,
        empleadoNombre: _empleadoSeleccionado!.usuario,
        cantidad: cantidad,
        costoTotal: costoTotal,
        usuarioId: userActual?.id,
        usuarioNombre: userActual?.nombre,
        fecha: DateTime.now(),
        notas: _notasController.text.trim().isEmpty ? null : _notasController.text.trim(),
        isPagado: _isPagado,
        isRepuesto: _isRepuesto,
        done: false, // Inicia sin pagar/reponer
      );

      final creado = await CatalogService.instance.crearUtensilioRoto(rotura);
      if (!mounted) return;
      showAppToast(context, 'Rotura de utensilio registrada exitosamente', type: ToastType.success);
      Navigator.of(context).pop(creado);
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Error al registrar rotura: $e', type: ToastType.error);
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final esMobile = ancho < 600;

    final qProd = _productoSearchController.text.trim().toLowerCase();
    final prodsFiltrados = _productos.where((p) {
      if (qProd.isEmpty) return true;
      return p.nombre.toLowerCase().contains(qProd);
    }).toList();

    final qEmp = _empleadoSearchController.text.trim().toLowerCase();
    final empsFiltrados = _empleados.where((e) {
      if (qEmp.isEmpty) return true;
      return e.usuario.toLowerCase().contains(qEmp) || e.rolNombre.toLowerCase().contains(qEmp);
    }).toList();

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
                // Cabecera
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.utensilsCrossed,
                        color: Colors.redAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Registrar Utensilio Roto',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Control de menaje/utensilios averiados o rotos',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 22),
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
                        // 1. Buscador de Producto de Inventario
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Producto de inventario *',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _productoSearchController,
                              focusNode: _productoFocusNode,
                              decoration: InputDecoration(
                                hintText: 'Buscar producto (ej. Copa, Plato, Vaso)...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                suffixIcon: _productoSeleccionado != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            _productoSeleccionado = null;
                                            _productoSearchController.clear();
                                            _costoReposicionController.clear();
                                            _recalcularCostoTotal();
                                            _mostrarDropdownProducto = true;
                                          });
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (_) {
                                setState(() {
                                  _productoSeleccionado = null;
                                  _mostrarDropdownProducto = true;
                                });
                              },
                            ),
                            if (_mostrarDropdownProducto && _productoSeleccionado == null)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                constraints: const BoxConstraints(maxHeight: 180),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: prodsFiltrados.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text(
                                          'No se encontraron productos coincidentes',
                                          style: TextStyle(fontSize: 13, color: Colors.grey),
                                        ),
                                      )
                                    : ListView.separated(
                                        shrinkWrap: true,
                                        itemCount: prodsFiltrados.length,
                                        separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade200),
                                        itemBuilder: (context, idx) {
                                          final p = prodsFiltrados[idx];
                                          final costo = p.costoReposicion != null
                                              ? ' · S/ ${p.costoReposicion!.toStringAsFixed(2)}'
                                              : ' · Sin costo fijado';
                                          return ListTile(
                                            dense: true,
                                            leading: const Icon(LucideIcons.package2, size: 18, color: AppColors.primaryGreen),
                                            title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                                            subtitle: Text('Stock: ${p.stockActual}$costo', style: const TextStyle(fontSize: 11.5)),
                                            onTap: () => _seleccionarProducto(p),
                                          );
                                        },
                                      ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 2. Buscador de Empleado Responsable
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Empleado responsable *',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _empleadoSearchController,
                              focusNode: _empleadoFocusNode,
                              decoration: InputDecoration(
                                hintText: 'Buscar empleado o mozo...',
                                prefixIcon: const Icon(Icons.person_search, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                suffixIcon: _empleadoSeleccionado != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            _empleadoSeleccionado = null;
                                            _empleadoSearchController.clear();
                                            _mostrarDropdownEmpleado = true;
                                          });
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (_) {
                                setState(() {
                                  _empleadoSeleccionado = null;
                                  _mostrarDropdownEmpleado = true;
                                });
                              },
                            ),
                            if (_mostrarDropdownEmpleado && _empleadoSeleccionado == null)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                constraints: const BoxConstraints(maxHeight: 180),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: empsFiltrados.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text(
                                          'No se encontraron empleados coincidentes',
                                          style: TextStyle(fontSize: 13, color: Colors.grey),
                                        ),
                                      )
                                    : ListView.separated(
                                        shrinkWrap: true,
                                        itemCount: empsFiltrados.length,
                                        separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade200),
                                        itemBuilder: (context, idx) {
                                          final e = empsFiltrados[idx];
                                          return ListTile(
                                            dense: true,
                                            leading: const Icon(Icons.badge_outlined, size: 18, color: Colors.blueGrey),
                                            title: Text(e.usuario, style: const TextStyle(fontWeight: FontWeight.w600)),
                                            subtitle: Text('Rol: ${e.rolNombre} · ${e.email}', style: const TextStyle(fontSize: 11.5)),
                                            onTap: () => _seleccionarEmpleado(e),
                                          );
                                        },
                                      ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 3. Cantidad, Costo Unitario y Costo Total
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _cantidadController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(
                                  labelText: 'Cantidad *',
                                  hintText: '1',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onChanged: (_) => setState(_recalcularCostoTotal),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Requerido';
                                  final numVal = int.tryParse(v.trim());
                                  if (numVal == null || numVal <= 0) return '> 0';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 4,
                              child: TextFormField(
                                controller: _costoReposicionController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                decoration: InputDecoration(
                                  labelText: 'Costo unit. (S/) *',
                                  hintText: '0.00',
                                  helperText: (_productoSeleccionado?.costoReposicion == null || _productoSeleccionado?.costoReposicion == 0)
                                      ? 'Se actualizará en inventario'
                                      : 'Fijado en inventario',
                                  helperStyle: const TextStyle(fontSize: 10.5),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onChanged: (_) => setState(_recalcularCostoTotal),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Requerido';
                                  final numVal = double.tryParse(v.trim());
                                  if (numVal == null || numVal <= 0) return '> 0';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 4,
                              child: TextFormField(
                                controller: _costoTotalController,
                                readOnly: true,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.redAccent),
                                decoration: InputDecoration(
                                  labelText: 'Costo Total (S/)',
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 4. Notas (textarea)
                        TextFormField(
                          controller: _notasController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Notas / Motivo de la rotura',
                            hintText: 'Describa cómo o en qué área ocurrió la rotura...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 5. Botones toggle de Modo de Resolución: ¿Pagar o Reponer?
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Compromiso de resolución del empleado',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isPagado
                                  ? 'El empleado pagará el costo del producto (se podrá descontar de su sueldo o abonar en caja).'
                                  : 'El empleado repondrá el producto físicamente (no genera descuento económico).',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // Botón Pagado
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _isPagado = true;
                                        _isRepuesto = false;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _isPagado
                                            ? Colors.amber.shade50
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _isPagado ? Colors.amber.shade800 : Colors.grey.shade300,
                                          width: _isPagado ? 1.8 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _isPagado ? Icons.monetization_on : Icons.monetization_on_outlined,
                                            size: 18,
                                            color: _isPagado ? Colors.amber.shade900 : Colors.grey.shade500,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Pagar / Descontar',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: _isPagado ? Colors.amber.shade900 : Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Botón Reponer
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _isPagado = false;
                                        _isRepuesto = true;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _isRepuesto
                                            ? Colors.blue.shade50
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _isRepuesto ? Colors.blue.shade700 : Colors.grey.shade300,
                                          width: _isRepuesto ? 1.8 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _isRepuesto ? Icons.inventory_2 : Icons.inventory_2_outlined,
                                            size: 18,
                                            color: _isRepuesto ? Colors.blue.shade800 : Colors.grey.shade500,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Reponer en físico',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: _isRepuesto ? Colors.blue.shade800 : Colors.grey.shade700,
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

                // Botones de acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text('Cancelar'),
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
                      label: const Text('Registrar rotura', style: TextStyle(fontWeight: FontWeight.w700)),
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

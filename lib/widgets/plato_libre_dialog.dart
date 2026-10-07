import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/pedido_line.dart';
import '../models/taper.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/uuid_helper.dart';

class PlatoLibreDialog extends StatefulWidget {
  const PlatoLibreDialog({super.key});

  @override
  State<PlatoLibreDialog> createState() => _PlatoLibreDialogState();
}

class _PlatoLibreDialogState extends State<PlatoLibreDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _precioController = TextEditingController();

  int _cantidad = 1;
  String _tipoEntrega = 'mesa'; // 'mesa', 'llevar', 'delivery'
  bool _llevaTaper = false;
  Taper? _taperSeleccionado;

  @override
  void initState() {
    super.initState();
    final tapers = CatalogService.instance.tapers.where((t) => t.estado).toList();
    if (tapers.isNotEmpty) {
      _taperSeleccionado = tapers.first;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  double get _precioBase => double.tryParse(_precioController.text.trim().replaceAll(',', '.')) ?? 0.0;
  double get _precioTaper => (_llevaTaper && _taperSeleccionado != null) ? _taperSeleccionado!.precio : 0.0;
  double get _precioUnitario => _precioBase + _precioTaper;
  double get _total => _precioUnitario * _cantidad;

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;

    final nombre = _nombreController.text.trim();
    final notas = _descripcionController.text.trim().isEmpty ? null : _descripcionController.text.trim();

    final linea = PedidoLine(
      id: UuidHelper.v7(),
      cartaId: '',
      nombrePlato: nombre,
      cantidad: _cantidad,
      modificadores: const [],
      presentacion: null,
      promocion: null,
      comentario: notas,
      precioUnitario: _precioUnitario,
      descuentoAplicado: 0,
      precioTotalLinea: _total,
      tipoEntrega: _tipoEntrega,
      aplicaTaper: _llevaTaper,
      taperId: _llevaTaper ? _taperSeleccionado?.id : null,
      precioTaper: _precioTaper,
      esLibre: true,
      nombreLibre: nombre,
      descripcionLibre: notas,
      precioBase: _precioBase,
    );

    Navigator.of(context).pop<PedidoLine>(linea);
  }

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final tapers = CatalogService.instance.tapers.where((t) => t.estado).toList();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: esMobile ? MediaQuery.sizeOf(context).width * 0.95 : 460,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    const Icon(LucideIcons.sparkles, color: AppColors.primaryGreen, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Plato libre / Pedido rápido',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Contenido con scroll
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre del plato
                      const Text(
                        'Nombre del plato / pedido *',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nombreController,
                        decoration: InputDecoration(
                          hintText: 'Ej. Arroz a la cubana, Ensalada especial...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Ingresa el nombre del plato';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Precio base
                      const Text(
                        'Precio acordado (S/) *',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _precioController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText: 'S/ ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Ingresa el precio del plato';
                          }
                          final p = double.tryParse(val.trim().replaceAll(',', '.'));
                          if (p == null || p <= 0) {
                            return 'Ingresa un precio mayor a 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Tipo de entrega
                      const Text(
                        'Tipo de entrega',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _chipTipo('mesa', 'En mesa', LucideIcons.utensils),
                          const SizedBox(width: 8),
                          _chipTipo('llevar', 'Para llevar', LucideIcons.packageCheck),
                          const SizedBox(width: 8),
                          _chipTipo('delivery', 'Delivery', LucideIcons.bike),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Táper
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _llevaTaper ? const Color(0xFFF0FDF4) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _llevaTaper ? AppColors.primaryGreen.withValues(alpha: 0.4) : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(LucideIcons.package, size: 18, color: _llevaTaper ? AppColors.primaryGreenDark : Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '¿Llevar en táper descartable?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _llevaTaper ? AppColors.primaryGreenDark : Colors.black87,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: _llevaTaper,
                                  activeThumbColor: Colors.white,
                                  activeTrackColor: AppColors.primaryGreen,
                                  onChanged: (val) {
                                    setState(() => _llevaTaper = val);
                                  },
                                ),
                              ],
                            ),
                            if (_llevaTaper) ...[
                              const SizedBox(height: 8),
                              if (tapers.isEmpty)
                                Text(
                                  'No hay táperes registrados en inventario.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                )
                              else
                                DropdownButtonFormField<String>(
                                  initialValue: _taperSeleccionado?.id,
                                  decoration: InputDecoration(
                                    labelText: 'Seleccionar tipo de táper',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: [
                                    for (final t in tapers)
                                      DropdownMenuItem(
                                        value: t.id,
                                        child: Text('${t.nombre} (+S/ ${t.precio.toStringAsFixed(2)})'),
                                      ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _taperSeleccionado = tapers.firstWhere((t) => t.id == val);
                                      });
                                    }
                                  },
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notas para cocina
                      const Text(
                        'Indicaciones para cocina (opcional)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descripcionController,
                        maxLines: 2,
                        maxLength: 100,
                        decoration: InputDecoration(
                          hintText: 'Ej. Bien cocido, sin picante, etc.',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Pie con contador de cantidad y botón Agregar
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    _botonCantidad(
                      Icons.remove,
                      _cantidad > 1 ? () => setState(() => _cantidad--) : null,
                    ),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '$_cantidad',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    _botonCantidad(
                      Icons.add,
                      () => setState(() => _cantidad++),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton(
                        onPressed: _confirmar,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Agregar · S/ ${_total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipTipo(String tipo, String etiqueta, IconData icono) {
    final activo = _tipoEntrega == tipo;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _tipoEntrega = tipo;
            if (tipo == 'llear' || tipo == 'delivery') {
              _llevaTaper = true;
            }
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activo ? AppColors.primaryGreen.withValues(alpha: 0.12) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: activo ? AppColors.primaryGreen : Colors.grey.shade300,
              width: activo ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 14, color: activo ? AppColors.primaryGreenDark : Colors.grey.shade700),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  etiqueta,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                    color: activo ? AppColors.primaryGreenDark : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botonCantidad(IconData icono, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
          color: onTap == null ? Colors.grey.shade100 : Colors.white,
        ),
        child: Icon(icono, size: 16, color: onTap == null ? Colors.grey.shade400 : Colors.black87),
      ),
    );
  }
}

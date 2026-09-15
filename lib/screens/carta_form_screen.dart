import 'package:flutter/material.dart';

import '../data/mock_categorias.dart';
import '../data/mock_tapers.dart';
import '../models/carta_item.dart';
import '../models/categoria_comida.dart';
import '../models/taper.dart';
import '../theme/app_theme.dart';
import '../widgets/app_select.dart';

// Alta/edición de un plato de la carta (solo Administrador). Se muestra como
// modal centrado (ver showBlurDialog en carta_screen.dart), no a pantalla
// completa: el ancho se adapta al contenido en vez de ocupar todo el ancho.
// TODO: al conectar el backend, esto pasa a insertar/actualizar `carta` real.
class CartaFormScreen extends StatefulWidget {
  final CartaItem? item; // null = crear nuevo

  const CartaFormScreen({super.key, this.item});

  @override
  State<CartaFormScreen> createState() => _CartaFormScreenState();
}

class _CartaFormScreenState extends State<CartaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nombreController = TextEditingController(
    text: widget.item?.nombrePlato ?? '',
  );
  late final _descripcionController = TextEditingController(
    text: widget.item?.descripcion ?? '',
  );
  late final _precioClienteController = TextEditingController(
    text: widget.item?.precioCliente?.toStringAsFixed(2) ?? '',
  );
  late final _precioPersonalController = TextEditingController(
    text: widget.item?.precioPersonal?.toStringAsFixed(2) ?? '',
  );

  late CategoriaComida _categoria = mockCategorias.firstWhere(
    (c) => c.id == widget.item?.categoriaId,
    orElse: () => mockCategorias.first,
  );
  late Taper? _taper = widget.item?.taperId == null
      ? null
      : mockTapers.where((t) => t.id == widget.item!.taperId).firstOrNull;
  late bool _activo = widget.item?.estado != 'inactivo';

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioClienteController.dispose();
    _precioPersonalController.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;

    final resultado = CartaItem(
      id: widget.item?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      nombrePlato: _nombreController.text.trim(),
      descripcion: _descripcionController.text.trim(),
      categoriaId: _categoria.id,
      taperId: _taper?.id,
      precioCliente: double.parse(_precioClienteController.text.trim()),
      precioPersonal: _precioPersonalController.text.trim().isEmpty
          ? null
          : double.parse(_precioPersonalController.text.trim()),
      estado: _activo ? 'activo' : 'inactivo',
    );
    Navigator.of(context).pop(resultado);
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.item != null;
    final esMobile = AppBreakpoints.esMobile(context);
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: esMobile
            ? BoxConstraints(
                minWidth: anchoPantalla,
                maxWidth: anchoPantalla,
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              )
            : const BoxConstraints(
                minWidth: 460,
                maxWidth: 460,
                maxHeight: 640,
              ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(24, esMobile ? 28 : 20, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        editando ? 'Editar plato' : 'Nuevo plato',
                        style: const TextStyle(
                          fontSize: 18,
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
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nombreController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del plato',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingresa el nombre'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descripcionController,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                        ),
                        maxLines: 2,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingresa la descripción'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      AppSelect<CategoriaComida>(
                        label: 'Categoría',
                        value: _categoria,
                        items: mockCategorias
                            .map(
                              (c) =>
                                  AppSelectItem(value: c, label: c.categoria),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _categoria = value!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _precioClienteController,
                        decoration: const InputDecoration(
                          labelText: 'Precio cliente (S/)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Ingresa el precio';
                          if (double.tryParse(v.trim()) == null)
                            return 'Precio inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _precioPersonalController,
                        decoration: const InputDecoration(
                          labelText: 'Precio personal (S/, opcional)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (double.tryParse(v.trim()) == null)
                            return 'Precio inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AppSelect<Taper?>(
                        label: 'Taper (opcional)',
                        value: _taper,
                        hint: 'Ninguno',
                        items: [
                          const AppSelectItem<Taper?>(
                            value: null,
                            label: 'Ninguno',
                          ),
                          ...mockTapers.map(
                            (t) => AppSelectItem<Taper?>(
                              value: t,
                              label: t.nombre,
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() => _taper = value),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Activo'),
                        subtitle: const Text(
                          'Visible en la carta para meseros y clientes',
                        ),
                        value: _activo,
                        onChanged: (value) => setState(() => _activo = value),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _guardar,
                        child: Text(
                          editando ? 'Guardar cambios' : 'Crear plato',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/categorias_store.dart';
import '../models/carta_item.dart';
import '../models/categoria_comida.dart';
import '../theme/app_theme.dart';
import '../utils/agregados_utils.dart';
import '../utils/carta_visuals.dart';
import '../widgets/app_select.dart';

// Alta/edición de un producto (tabla `productos`), solo Administrador.
// TODO backend: insertar/actualizar `productos`.
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
  late final _precioController = TextEditingController(
    text: widget.item?.precioCliente?.toStringAsFixed(2) ?? '',
  );
  late final _costoController = TextEditingController(
    text: widget.item?.costo?.toStringAsFixed(2) ?? '',
  );
  late final _stockController = TextEditingController(
    text: '${widget.item?.stock ?? 0}',
  );
  late final _skuController = TextEditingController(
    text: widget.item?.sku ?? '',
  );
  late final _limiteController = TextEditingController(
    text: widget.item?.limiteAgregados?.toString() ?? '',
  );
  final _agregadoNombreController = TextEditingController();
  final _agregadoPrecioController = TextEditingController();

  late CategoriaComida _categoria = mockCategorias.firstWhere(
    (c) => c.id == widget.item?.categoriaId,
    orElse: () => mockCategorias.first,
  );
  late bool _activo = widget.item?.estado != 'inactivo';
  late final List<Map<String, dynamic>> _agregados = List.of(
    agregadosSimples(widget.item?.agregados ?? const []),
  );
  late final List<_GrupoEditable> _grupos = [
    for (final g in gruposDeAgregados(widget.item?.agregados ?? const []))
      _GrupoEditable(
        nombre: nombreGrupo(g),
        cantidadMaxima: cantidadMaximaGrupo(g) ?? 1,
        items: List.of(itemsDeGrupo(g)),
      ),
  ];
  Uint8List? _imagenBytes;

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    _costoController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    _limiteController.dispose();
    _agregadoNombreController.dispose();
    _agregadoPrecioController.dispose();
    for (final g in _grupos) {
      g.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirImagen() async {
    final archivo = await FilePicker.pickFile(type: FileType.image);
    if (archivo == null) return;
    final bytes = await archivo.readAsBytes();
    if (!mounted) return;
    setState(() => _imagenBytes = bytes);
  }

  void _agregarAgregado() {
    final nombre = _agregadoNombreController.text.trim();
    if (nombre.isEmpty) return;
    final precio = double.tryParse(_agregadoPrecioController.text.trim());
    setState(() {
      _agregados.add({'nombre': nombre, 'precio': ?precio});
      _agregadoNombreController.clear();
      _agregadoPrecioController.clear();
    });
  }

  void _agregarItemAGrupo(int grupoIndex) {
    final g = _grupos[grupoIndex];
    final nombre = g.nombreItemController.text.trim();
    if (nombre.isEmpty) return;
    final precio = double.tryParse(g.precioItemController.text.trim());
    setState(() {
      g.items.add({'nombre': nombre, 'precio': ?precio});
      g.nombreItemController.clear();
      g.precioItemController.clear();
    });
  }

  // Modal para crear o editar un grupo de extras (nombre/cantidad máxima).
  Future<void> _crearOEditarGrupo({int? indexExistente}) async {
    final existente = indexExistente != null ? _grupos[indexExistente] : null;
    final nombreController = TextEditingController(text: existente?.nombre);
    final cantidadController = TextEditingController(
      text: '${existente?.cantidadMaxima ?? 1}',
    );
    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existente == null ? 'Nuevo grupo de extras' : 'Editar grupo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre del grupo (ej. Salsas)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cantidadController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad máxima que puede elegir el cliente',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(existente == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    );
    if (resultado != true || nombreController.text.trim().isEmpty) return;
    final cantidad = int.tryParse(cantidadController.text.trim()) ?? 1;
    setState(() {
      if (existente != null) {
        existente.nombre = nombreController.text.trim();
        existente.cantidadMaxima = cantidad;
      } else {
        _grupos.add(
          _GrupoEditable(
            nombre: nombreController.text.trim(),
            cantidadMaxima: cantidad,
          ),
        );
      }
    });
  }

  Future<void> _eliminarGrupo(int index) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: Text(
          '¿Eliminar el grupo "${_grupos[index].nombre}" y sus extras?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true) setState(() => _grupos.removeAt(index));
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;

    final resultado = CartaItem(
      id: widget.item?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      nombrePlato: _nombreController.text.trim(),
      descripcion: _descripcionController.text.trim(),
      categoriaId: _categoria.id,
      precioCliente: double.parse(_precioController.text.trim()),
      estado: _activo ? 'activo' : 'inactivo',
      costo: _costoController.text.trim().isEmpty
          ? null
          : double.parse(_costoController.text.trim()),
      sku: _skuController.text.trim().isEmpty
          ? null
          : _skuController.text.trim(),
      stock: int.tryParse(_stockController.text.trim()) ?? 0,
      agregados: [
        ..._agregados,
        for (final g in _grupos)
          {
            'grupo': g.nombre,
            'cantidadMaxima': g.cantidadMaxima,
            'items': List.of(g.items),
          },
      ],
      limiteAgregados: int.tryParse(_limiteController.text.trim()),
      creadoEn: widget.item?.creadoEn ?? DateTime.now(),
      imagenBytes: _imagenBytes ?? widget.item?.imagenBytes,
    );
    Navigator.of(context).pop(resultado);
  }

  Widget _imagen(double lado) {
    final bytes = _imagenBytes ?? widget.item?.imagenBytes;
    final asset = widget.item == null ? null : imagenDeCarta(widget.item!.id);
    Widget contenido;
    if (bytes != null) {
      contenido = Image.memory(bytes, fit: BoxFit.cover);
    } else if (asset != null) {
      contenido = Image.asset(asset, fit: BoxFit.cover);
    } else {
      contenido = Icon(
        Icons.image_outlined,
        size: 40,
        color: Colors.grey.shade400,
      );
    }
    return SizedBox(
      width: lado,
      height: lado,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColoredBox(
                color: const Color(0xFFF1F3F0),
                child: Opacity(
                  opacity: _activo ? 1 : 0.4,
                  child: Center(child: SizedBox.expand(child: contenido)),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: _botonRedondo(
              icono: _activo ? Icons.visibility : Icons.visibility_off,
              tooltip: _activo
                  ? 'Activo: toca para desactivar'
                  : 'Inactivo: toca para activar',
              color: _activo ? AppColors.primaryGreen : Colors.grey.shade600,
              onTap: () => setState(() => _activo = !_activo),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: _botonRedondo(
              icono: Icons.photo_camera_outlined,
              tooltip: 'Subir imagen',
              color: Colors.grey.shade800,
              onTap: _elegirImagen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonRedondo({
    required IconData icono,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icono, size: 18, color: color),
          ),
        ),
      ),
    );
  }

  Widget _numero(
    TextEditingController c,
    String label, {
    bool decimal = false,
    bool requerido = false,
  }) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      validator: (v) {
        final t = v?.trim() ?? '';
        if (t.isEmpty) return requerido ? 'Requerido' : null;
        if ((decimal ? double.tryParse(t) : int.tryParse(t)) == null) {
          return 'Valor inválido';
        }
        return null;
      },
    );
  }

  Widget _fila(Widget a, Widget b) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 16),
        Expanded(child: b),
      ],
    );
  }

  String _textoAgregado(Map<String, dynamic> a) {
    final precio = a['precio'];
    return precio is num
        ? '${a['nombre']} · S/ ${precio.toStringAsFixed(2)}'
        : '${a['nombre']}';
  }

  Widget _chipExtra(String texto, VoidCallback onQuitar) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 5, 8, 5),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            texto,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onQuitar,
            child: const Icon(Icons.close, size: 14, color: AppColors.primaryGreen),
          ),
        ],
      ),
    );
  }

  // Tarjeta de un grupo de extras: nombre, cantidad máxima y sus extras.
  Widget _tarjetaGrupo(int index) {
    final g = _grupos[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${g.nombre} · máx. ${g.cantidadMaxima}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              IconButton(
                tooltip: 'Editar grupo',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.edit_outlined, size: 17),
                onPressed: () => _crearOEditarGrupo(indexExistente: index),
              ),
              IconButton(
                tooltip: 'Eliminar grupo',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.delete_outline, size: 17, color: AppColors.error),
                onPressed: () => _eliminarGrupo(index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (g.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var j = 0; j < g.items.length; j++)
                    _chipExtra(
                      _textoAgregado(g.items[j]),
                      () => setState(() => g.items.removeAt(j)),
                    ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: g.nombreItemController,
                  decoration: const InputDecoration(
                    hintText: 'Nombre del extra',
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                  onSubmitted: (_) => _agregarItemAGrupo(index),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: g.precioItemController,
                  decoration: const InputDecoration(
                    hintText: 'Precio (S/)',
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onSubmitted: (_) => _agregarItemAGrupo(index),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Agregar',
                onPressed: () => _agregarItemAGrupo(index),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.item != null;
    final esMobile = AppBreakpoints.esMobile(context);
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    final lado = esMobile ? 116.0 : 156.0;
    final tema = Theme.of(context);
    return Theme(
      data: tema.copyWith(
        textTheme: tema.textTheme.copyWith(
          bodyLarge: tema.textTheme.bodyLarge?.copyWith(fontSize: 13),
        ),
        inputDecorationTheme: tema.inputDecorationTheme.copyWith(
          labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          floatingLabelStyle: const TextStyle(fontSize: 13),
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
      child: _contenido(context, editando, esMobile, anchoPantalla, lado),
    );
  }

  Widget _contenido(
    BuildContext context,
    bool editando,
    bool esMobile,
    double anchoPantalla,
    double lado,
  ) {
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
                maxHeight: MediaQuery.sizeOf(context).height * 0.9,
              )
            : const BoxConstraints(
                minWidth: 660,
                maxWidth: 660,
                maxHeight: 700,
              ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(28, esMobile ? 28 : 22, 14, 0),
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
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: lado,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _imagen(lado),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _nombreController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nombre del plato',
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'Ingresa el nombre'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _descripcionController,
                                      expands: true,
                                      maxLines: null,
                                      minLines: null,
                                      textAlignVertical: TextAlignVertical.top,
                                      decoration: const InputDecoration(
                                        labelText: 'Descripción',
                                        alignLabelWithHint: true,
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                          ? 'Ingresa la descripción'
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Divider(height: 1, color: Colors.grey.shade300),
                      const SizedBox(height: 24),
                      _fila(
                        AppSelect<CategoriaComida>(
                          label: 'Categoría',
                          flotante: true,
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
                        _numero(
                          _precioController,
                          'Precio (S/)',
                          decimal: true,
                          requerido: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _fila(
                        _numero(_costoController, 'Costo (S/)', decimal: true),
                        _numero(_stockController, 'Stock'),
                      ),
                      const SizedBox(height: 16),
                      _fila(
                        TextFormField(
                          controller: _skuController,
                          decoration: const InputDecoration(labelText: 'SKU'),
                        ),
                        _numero(_limiteController, 'Límite de agregados'),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Agregados',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Extras sueltos',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_agregados.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (var i = 0; i < _agregados.length; i++)
                                      _chipExtra(
                                        _textoAgregado(_agregados[i]),
                                        () => setState(
                                          () => _agregados.removeAt(i),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _agregadoNombreController,
                                    decoration: const InputDecoration(
                                      hintText: 'Nombre del extra',
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    onSubmitted: (_) => _agregarAgregado(),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _agregadoPrecioController,
                                    decoration: const InputDecoration(
                                      hintText: 'Precio (S/)',
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onSubmitted: (_) => _agregarAgregado(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  tooltip: 'Agregar',
                                  onPressed: _agregarAgregado,
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                            if (_grupos.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              Divider(height: 1, color: Colors.grey.shade300),
                              const SizedBox(height: 14),
                            ],
                            for (var i = 0; i < _grupos.length; i++) ...[
                              _tarjetaGrupo(i),
                              const SizedBox(height: 12),
                            ],
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _crearOEditarGrupo(),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Nuevo grupo de extras'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _guardar,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            editando ? 'Guardar cambios' : 'Crear plato',
                          ),
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

// Estado editable de un grupo de extras dentro del formulario.
class _GrupoEditable {
  String nombre;
  int cantidadMaxima;
  final List<Map<String, dynamic>> items;
  final nombreItemController = TextEditingController();
  final precioItemController = TextEditingController();

  _GrupoEditable({
    required this.nombre,
    required this.cantidadMaxima,
    List<Map<String, dynamic>>? items,
  }) : items = items ?? [];

  void dispose() {
    nombreItemController.dispose();
    precioItemController.dispose();
  }
}

import 'package:flutter/material.dart';

import '../data/categorias_store.dart';
import '../models/carta_item.dart';
import '../models/categoria_comida.dart';
import '../models/taper.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/uuid_helper.dart';
import '../widgets/app_select.dart';
import '../widgets/app_toast.dart';

/// Formulario para Crear / Editar un plato en la `carta` (según BD.txt).
/// Campos en tabla `carta`:
/// - id (uuid)
/// - nombre_plato (varchar 50)
/// - descripcion (text)
/// - categoria_id (uuid)
/// - taper_id (uuid, nullable)
/// - estado ('disponible' | 'agotado')
/// - precio_cliente (decimal)
/// - precio_personal (decimal, opcional)
/// - sede_id (uuid)
class CartaFormScreen extends StatefulWidget {
  final CartaItem? item; // null = crear nuevo
  final String? categoriaInicialId;

  const CartaFormScreen({
    super.key,
    this.item,
    this.categoriaInicialId,
  });

  @override
  State<CartaFormScreen> createState() => _CartaFormScreenState();
}

class _CartaFormScreenState extends State<CartaFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _precioClienteController;
  late final TextEditingController _precioPersonalController;
  late final TextEditingController _taperSearchController;
  late final FocusNode _taperFocusNode;

  CategoriaComida? _categoria;
  String? _selectedTaperId;
  String? _selectedTaperNombre;
  String _estado = 'disponible';
  bool _mostrarListaTapers = false;
  bool _cargandoTapers = false;

  @override
  void initState() {
    super.initState();

    final item = widget.item;
    _nombreController = TextEditingController(text: item?.nombrePlato ?? '');
    _descripcionController = TextEditingController(text: item?.descripcion ?? '');
    _precioClienteController = TextEditingController(
      text: item?.precioCliente != null ? item!.precioCliente!.toStringAsFixed(2) : '',
    );
    _precioPersonalController = TextEditingController(
      text: item?.precioPersonal != null ? item!.precioPersonal!.toStringAsFixed(2) : '',
    );

    // Categoría preseleccionada
    final catId = item?.categoriaId ?? widget.categoriaInicialId;
    _categoria = categorias.where((c) => c.id == catId).firstOrNull;
    if (_categoria == null && categorias.isNotEmpty && catId == null) {
      _categoria = categorias.first;
    }

    _estado = (item?.estado == 'agotado') ? 'agotado' : 'disponible';
    _selectedTaperId = item?.taperId;

    _taperSearchController = TextEditingController();
    _taperFocusNode = FocusNode();

    _taperFocusNode.addListener(() {
      if (_taperFocusNode.hasFocus) {
        setState(() => _mostrarListaTapers = true);
      }
    });

    _inicializarTapers();
  }

  Future<void> _inicializarTapers() async {
    if (CatalogService.instance.tapers.isEmpty) {
      setState(() => _cargandoTapers = true);
      await CatalogService.instance.cargarTapers();
      if (!mounted) return;
      setState(() => _cargandoTapers = false);
    }

    // Si hay un taperId inicial, buscar su nombre y precio
    if (_selectedTaperId != null && _selectedTaperId!.isNotEmpty) {
      final encontrado = CatalogService.instance.tapers
          .where((t) => t.id == _selectedTaperId)
          .firstOrNull;
      if (encontrado != null) {
        _selectedTaperNombre = encontrado.nombre;
        _taperSearchController.text =
            '${encontrado.nombre} · S/ ${encontrado.precio.toStringAsFixed(2)}';
      } else if (widget.item?.taperNombre != null) {
        _selectedTaperNombre = widget.item!.taperNombre;
        _taperSearchController.text = widget.item!.taperNombre!;
      }
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioClienteController.dispose();
    _precioPersonalController.dispose();
    _taperSearchController.dispose();
    _taperFocusNode.dispose();
    super.dispose();
  }

  void _seleccionarTaper(Taper? taper) {
    setState(() {
      if (taper == null) {
        _selectedTaperId = null;
        _selectedTaperNombre = null;
        _taperSearchController.clear();
      } else {
        _selectedTaperId = taper.id;
        _selectedTaperNombre = taper.nombre;
        _taperSearchController.text =
            '${taper.nombre} · S/ ${taper.precio.toStringAsFixed(2)}';
      }
      _mostrarListaTapers = false;
    });
    _taperFocusNode.unfocus();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;

    if (_categoria == null) {
      showAppToast(context, 'Selecciona una categoría para el plato',
          type: ToastType.error);
      return;
    }

    final pCliente = double.tryParse(_precioClienteController.text.trim());
    if (pCliente == null || pCliente < 0) {
      showAppToast(context, 'Ingresa un precio de cliente válido',
          type: ToastType.error);
      return;
    }

    double? pPersonal;
    final pPersText = _precioPersonalController.text.trim();
    if (pPersText.isNotEmpty) {
      pPersonal = double.tryParse(pPersText);
      if (pPersonal == null || pPersonal < 0) {
        showAppToast(context, 'Ingresa un precio de personal válido',
            type: ToastType.error);
        return;
      }
    }

    final sedeActual = widget.item?.sedeId ??
        AuthService.instance.currentUser?.sedeId;

    final resultado = CartaItem(
      id: widget.item?.id ?? UuidHelper.v7(),
      nombrePlato: _nombreController.text.trim(),
      descripcion: _descripcionController.text.trim(),
      categoriaId: _categoria!.id,
      categoriaNombre: _categoria!.categoria,
      taperId: _selectedTaperId,
      taperNombre: _selectedTaperNombre,
      estado: _estado,
      precioCliente: pCliente,
      precioPersonal: pPersonal,
      sedeId: sedeActual,
      creadoEn: widget.item?.creadoEn ?? DateTime.now(),
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
                maxHeight: MediaQuery.sizeOf(context).height * 0.92,
              )
            : const BoxConstraints(
                minWidth: 580,
                maxWidth: 620,
                maxHeight: 740,
              ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera del modal
              _buildHeader(editando),

              // Contenido con scroll
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Nombre del plato
                      TextFormField(
                        controller: _nombreController,
                        maxLength: 50,
                        decoration: InputDecoration(
                          labelText: 'Nombre del plato *',
                          hintText: 'Ej. Arroz Chaufa Especial',
                          prefixIcon: const Icon(Icons.restaurant_menu, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'El nombre del plato es obligatorio';
                          }
                          if (v.trim().length > 50) {
                            return 'Máximo 50 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // 2. Categoría (selector interno extrae categoria_id)
                      AppSelect<CategoriaComida>(
                        label: 'Categoría *',
                        value: _categoria,
                        items: categorias
                            .map(
                              (c) => AppSelectItem(value: c, label: c.categoria),
                            )
                            .toList(),
                        onChanged: (cat) => setState(() => _categoria = cat),
                      ),
                      const SizedBox(height: 16),

                      // 3. Descripción
                      TextFormField(
                        controller: _descripcionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Descripción *',
                          hintText: 'Ingredientes, detalles de preparación o porción...',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'La descripción es obligatoria';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 4. Selector interactivo de Táper con ventana de 4-5 opciones
                      _buildTaperSelector(),
                      const SizedBox(height: 16),

                      // 5. Precios (Cliente y Personal)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _precioClienteController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Precio público (S/) *',
                                hintText: '0.00',
                                prefixText: 'S/ ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Precio requerido';
                                }
                                final p = double.tryParse(v.trim());
                                if (p == null || p < 0) {
                                  return 'Precio inválido';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _precioPersonalController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Precio personal (S/)',
                                hintText: 'Opcional',
                                prefixText: 'S/ ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              validator: (v) {
                                final text = v?.trim() ?? '';
                                if (text.isNotEmpty) {
                                  final p = double.tryParse(text);
                                  if (p == null || p < 0) {
                                    return 'Precio inválido';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 6. Selector de Estado (disponible / agotado)
                      _buildEstadoSelector(),
                      const SizedBox(height: 24),

                      // Botones de acción
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                            ),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _guardar,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(Icons.check, size: 18),
                            label: Text(
                              editando ? 'Guardar cambios' : 'Crear plato',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
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

  Widget _buildHeader(bool editando) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 16, 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.restaurant_menu,
              color: AppColors.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editando ? 'Editar plato de la carta' : 'Nuevo plato en la carta',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Configura los datos del plato según la carta oficial',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  /// Selector de táper con campo de búsqueda interactivo y dropdown deslizante de 4-5 opciones.
  Widget _buildTaperSelector() {
    final todosTapers = CatalogService.instance.tapers;
    final query = _taperSearchController.text.trim().toLowerCase();

    final tapersFiltrados = todosTapers.where((t) {
      if (query.isEmpty) return true;
      final format = '${t.nombre} · s/ ${t.precio.toStringAsFixed(2)}'.toLowerCase();
      return format.contains(query) || t.nombre.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Input para buscar táper
        TextField(
          controller: _taperSearchController,
          focusNode: _taperFocusNode,
          onTap: () {
            setState(() => _mostrarListaTapers = true);
          },
          onChanged: (_) {
            setState(() => _mostrarListaTapers = true);
          },
          decoration: InputDecoration(
            labelText: 'Táper para llevar (opcional)',
            hintText: 'Haz clic para buscar táper...',
            prefixIcon: const Icon(Icons.takeout_dining_outlined, size: 20),
            suffixIcon: _selectedTaperId != null || _taperSearchController.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Quitar táper (Sin táper)',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _seleccionarTaper(null),
                  )
                : const Icon(Icons.arrow_drop_down),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),

        // Dropdown deslizable con altura de 4 a 5 items
        if (_mostrarListaTapers) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 190),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _cargandoTapers
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : todosTapers.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 28, color: Colors.grey.shade400),
                            const SizedBox(height: 6),
                            Text(
                              'Aún no hay tápers registrados en inventario.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Scrollbar(
                        thumbVisibility: true,
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: [
                            // Opción explícita: "Sin táper"
                            ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.block,
                                size: 18,
                                color: Colors.grey,
                              ),
                              title: const Text(
                                'Sin táper',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                              subtitle: const Text(
                                'Este plato no requiere táper por defecto',
                                style: TextStyle(fontSize: 11),
                              ),
                              selected: _selectedTaperId == null,
                              selectedTileColor: Colors.grey.shade100,
                              onTap: () => _seleccionarTaper(null),
                            ),
                            const Divider(height: 1),

                            // Lista filtrada de tápers
                            for (final t in tapersFiltrados)
                              ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.takeout_dining,
                                  size: 18,
                                  color: _selectedTaperId == t.id
                                      ? AppColors.primaryGreen
                                      : Colors.grey.shade700,
                                ),
                                title: Text(
                                  t.nombre,
                                  style: TextStyle(
                                    fontWeight: _selectedTaperId == t.id
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'S/ ${t.precio.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                ),
                                selected: _selectedTaperId == t.id,
                                selectedTileColor:
                                    AppColors.primaryGreen.withValues(alpha: 0.08),
                                onTap: () => _seleccionarTaper(t),
                              ),
                            if (tapersFiltrados.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'No se encontró ningún táper con "$query"',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
          ),
        ],
      ],
    );
  }

  /// Selector visual de Estado ('disponible' vs 'agotado')
  Widget _buildEstadoSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estado en la carta',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _estado = 'disponible'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: _estado == 'disponible'
                        ? AppColors.primaryGreen.withValues(alpha: 0.12)
                        : Colors.white,
                    border: Border.all(
                      color: _estado == 'disponible'
                          ? AppColors.primaryGreen
                          : Colors.grey.shade300,
                      width: _estado == 'disponible' ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: _estado == 'disponible'
                            ? AppColors.primaryGreen
                            : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Disponible',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _estado == 'disponible'
                              ? AppColors.primaryGreen
                              : Colors.grey.shade700,
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
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _estado = 'agotado'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: _estado == 'agotado'
                        ? AppColors.error.withValues(alpha: 0.12)
                        : Colors.white,
                    border: Border.all(
                      color: _estado == 'agotado'
                          ? AppColors.error
                          : Colors.grey.shade300,
                      width: _estado == 'agotado' ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.remove_circle_outline,
                        size: 18,
                        color: _estado == 'agotado'
                            ? AppColors.error
                            : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Agotado',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _estado == 'agotado'
                              ? AppColors.error
                              : Colors.grey.shade700,
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
    );
  }
}

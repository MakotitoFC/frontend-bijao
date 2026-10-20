import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/categorias_store.dart';
import '../data/subcategorias_store.dart';
import '../data/variantes_store.dart';
import '../models/carta_item.dart';
import '../models/carta_variante.dart';
import '../models/categoria_comida.dart';
import '../models/taper.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/uuid_helper.dart';
import '../widgets/app_select.dart';
import '../widgets/app_switch.dart';
import '../widgets/app_toast.dart';
import '../widgets/subcategorias_acordeon.dart';
import '../widgets/campo_texto.dart';
import '../widgets/imagen_plato.dart';

// Lo que devuelve el formulario: el plato y, si se eligió una foto nueva, sus
// bytes y nombre (se suben al guardar el plato).
typedef ResultadoPlato = ({
  CartaItem item,
  Uint8List? foto,
  String? nombreFoto,
  // Tamaños del plato para guardar junto con él (null = no tocarlos).
  List<CartaVariante>? variantes,
});

// Una fila de la lista "Tamaños" del formulario. Con [id] es un tamaño que ya
// existe en el servidor; sin [id], uno nuevo.
class _FilaTamano {
  final String? id;
  final TextEditingController nombre;
  final TextEditingController precio;
  final TextEditingController personal;
  final TextEditingController pesoMin;
  final TextEditingController pesoMax;
  bool activo;

  _FilaTamano({
    this.id,
    String nombre = '',
    String precio = '',
    String personal = '',
    String pesoMin = '',
    String pesoMax = '',
    this.activo = true,
  }) : nombre = TextEditingController(text: nombre),
       precio = TextEditingController(text: precio),
       personal = TextEditingController(text: personal),
       pesoMin = TextEditingController(text: pesoMin),
       pesoMax = TextEditingController(text: pesoMax);

  factory _FilaTamano.de(CartaVariante v) => _FilaTamano(
    id: v.id,
    nombre: v.nombre,
    precio: v.precioCliente.toStringAsFixed(2),
    // Solo se muestra si es distinto del precio público.
    personal: (v.precioPersonal - v.precioCliente).abs() < 0.005
        ? ''
        : v.precioPersonal.toStringAsFixed(2),
    pesoMin: v.pesoMinKg?.toString() ?? '',
    pesoMax: v.pesoMaxKg?.toString() ?? '',
    activo: v.estado,
  );

  void liberar() {
    nombre.dispose();
    precio.dispose();
    personal.dispose();
    pesoMin.dispose();
    pesoMax.dispose();
  }
}

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

  const CartaFormScreen({super.key, this.item, this.categoriaInicialId});

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
  Set<String> _subcategoriaIds = {};
  String? _selectedTaperId;
  String? _selectedTaperNombre;
  String _estado = 'disponible';
  bool _mostrarListaTapers = false;
  bool _cargandoTapers = false;
  // Foto elegida en este formulario (aún no subida).
  Uint8List? _fotoBytes;
  String? _fotoNombre;
  String? _errorFoto;
  // Tamaños: el interruptor "Tiene tamaños" y sus filas.
  bool _tieneTamanos = false;
  bool _tamanosAvanzado = false;
  final List<_FilaTamano> _filas = [];

  @override
  void initState() {
    super.initState();

    final item = widget.item;
    if (item != null) {
      for (final v in variantesDeCarta(item.id)) {
        _filas.add(_FilaTamano.de(v));
      }
      _tieneTamanos = _filas.any((f) => f.activo);
    }
    _nombreController = TextEditingController(text: item?.nombrePlato ?? '');
    _descripcionController = TextEditingController(
      text: item?.descripcion ?? '',
    );
    _precioClienteController = TextEditingController(
      text: item?.precioCliente != null
          ? item!.precioCliente!.toStringAsFixed(2)
          : '',
    );
    _precioPersonalController = TextEditingController(
      text: item?.precioPersonal != null
          ? item!.precioPersonal!.toStringAsFixed(2)
          : '',
    );

    // Categoría preseleccionada
    final catId = item?.categoriaId ?? widget.categoriaInicialId;
    _categoria = categorias.where((c) => c.id == catId).firstOrNull;
    if (_categoria == null && categorias.isNotEmpty && catId == null) {
      _categoria = categorias.first;
    }

    _subcategoriaIds = {...?item?.subcategoriaIds};
    _estado = (item?.agotado ?? false)
        ? estadoAgotado
        : ((item?.inhabilitado ?? false)
              ? estadoInhabilitado
              : estadoDisponible);
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
    for (final f in _filas) {
      f.liberar();
    }
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
      showAppToast(
        context,
        'Selecciona una categoría para el plato',
        type: ToastType.error,
      );
      return;
    }

    if (_subcategoriaIds.isEmpty) {
      final sinSubcategorias = subcategoriasDe(
        _categoria!.id,
        soloActivas: true,
      ).isEmpty;
      showAppToast(
        context,
        sinSubcategorias
            ? 'Crea primero una subcategoría para "${_categoria!.categoria}" '
                  '(Categorías > + Subcategoría)'
            : 'Selecciona al menos una subcategoría del plato',
        type: ToastType.error,
      );
      return;
    }

    // El precio es opcional: un plato por tamaños lo deja vacío y sus precios
    // van en la lista de tamaños.
    final textoPrecio = _precioClienteController.text.trim();
    final pCliente = double.tryParse(textoPrecio);
    if (textoPrecio.isNotEmpty && (pCliente == null || pCliente < 0)) {
      showAppToast(
        context,
        'Ingresa un precio de cliente válido',
        type: ToastType.error,
      );
      return;
    }

    double? pPersonal;
    final pPersText = _precioPersonalController.text.trim();
    if (pPersText.isNotEmpty) {
      pPersonal = double.tryParse(pPersText);
      if (pPersonal == null || pPersonal < 0) {
        showAppToast(
          context,
          'Ingresa un precio de personal válido',
          type: ToastType.error,
        );
        return;
      }
    }

    final sedeActual =
        widget.item?.sedeId ?? AuthService.instance.currentUser?.sedeId;
    final idPlato = widget.item?.id ?? UuidHelper.v7();

    final tamanos = _tamanosParaGuardar(idPlato);
    if (tamanos.error != null) {
      showAppToast(context, tamanos.error!, type: ToastType.error);
      return;
    }

    final resultado = CartaItem(
      id: idPlato,
      nombrePlato: _nombreController.text.trim(),
      descripcion: _descripcionController.text.trim(),
      categoriaId: _categoria!.id,
      categoriaNombre: _categoria!.categoria,
      subcategoriaIds: _subcategoriaIds.toList(),
      taperId: _selectedTaperId,
      taperNombre: _selectedTaperNombre,
      estado: _estado,
      precioCliente: pCliente,
      precioPersonal: pPersonal,
      sedeId: sedeActual,
      urlImagen: widget.item?.urlImagen,
      creadoEn: widget.item?.creadoEn ?? DateTime.now(),
    );

    final ResultadoPlato salida = (
      item: resultado,
      foto: _fotoBytes,
      nombreFoto: _fotoNombre,
      variantes: tamanos.lista,
    );
    Navigator.of(context).pop(salida);
  }

  double? _numeroDe(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  // Tamaños que se guardan con el plato. Con el interruptor apagado, los que ya
  // existían se desactivan (no se borran); los nuevos que no se llenaron se
  // descartan. Devuelve un [error] si falta algo en las filas activas.
  ({List<CartaVariante>? lista, String? error}) _tamanosParaGuardar(
    String idPlato,
  ) {
    if (!_tieneTamanos) {
      final existentes = _filas.where((f) => f.id != null && f.activo).toList();
      if (existentes.isEmpty) return (lista: null, error: null);
      return (
        lista: [
          for (final f in existentes) _variante(idPlato, f, activo: false),
        ],
        error: null,
      );
    }
    final activas = _filas.where((f) => f.activo).toList();
    if (activas.isEmpty) {
      return (
        lista: null,
        error: 'Agrega al menos un tamaño o apaga "Tiene tamaños".',
      );
    }
    for (final f in activas) {
      final precio = _numeroDe(f.precio);
      if (f.nombre.text.trim().isEmpty || precio == null || precio < 0) {
        return (
          lista: null,
          error: 'Cada tamaño necesita su nombre y un precio válido.',
        );
      }
      final personal = f.personal.text.trim();
      if (personal.isNotEmpty &&
          (_numeroDe(f.personal) == null || _numeroDe(f.personal)! < 0)) {
        return (lista: null, error: 'Un precio personal no es válido.');
      }
    }
    return (
      lista: [
        for (final f in _filas)
          // Un tamaño nuevo que quedó quitado no se envía.
          if (f.id != null || f.activo) _variante(idPlato, f, activo: f.activo),
      ],
      error: null,
    );
  }

  CartaVariante _variante(
    String idPlato,
    _FilaTamano f, {
    required bool activo,
  }) {
    final precio = _numeroDe(f.precio) ?? 0;
    return CartaVariante(
      id: f.id ?? '',
      cartaId: idPlato,
      nombre: f.nombre.text.trim(),
      precioCliente: precio,
      // Sin precio personal, vale lo mismo que el público.
      precioPersonal: _numeroDe(f.personal) ?? precio,
      pesoMinKg: _numeroDe(f.pesoMin),
      pesoMaxKg: _numeroDe(f.pesoMax),
      estado: activo,
    );
  }

  static const _tamanoMaxFoto = 5 * 1024 * 1024;
  static const _plato = CartaItem(
    id: '',
    nombrePlato: '',
    descripcion: '',
    categoriaId: '',
  );

  Future<void> _elegirFoto() async {
    try {
      final archivos = await FilePicker.pickFiles(type: FileType.image);
      if (archivos.isEmpty) return;
      final f = archivos.first;
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      if (bytes.length > _tamanoMaxFoto) {
        setState(() => _errorFoto = 'La foto pesa más de 5 MB.');
        return;
      }
      setState(() {
        _fotoBytes = Uint8List.fromList(bytes);
        _fotoNombre = f.name;
        _errorFoto = null;
      });
    } catch (e) {
      if (mounted) setState(() => _errorFoto = 'No se pudo leer la foto: $e');
    }
  }

  // Foto del plato: vista previa y botón para subirla o cambiarla.
  Widget _bloqueFoto() {
    final hayFoto = _fotoBytes != null || widget.item?.urlImagen != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 104,
                height: 72,
                child: _fotoBytes != null
                    ? Image.memory(_fotoBytes!, fit: BoxFit.cover)
                    : ImagenPlato(item: widget.item ?? _plato, tamanoIcono: 26),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Foto del plato',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fotoNombre ?? 'JPG, PNG o WEBP · máximo 5 MB',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _elegirFoto,
                    icon: const Icon(LucideIcons.camera, size: 16),
                    label: Text(hayFoto ? 'Cambiar foto' : 'Subir foto'),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_errorFoto != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _errorFoto!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
      ],
    );
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
                      // 0. Foto del plato
                      _bloqueFoto(),
                      const SizedBox(height: 16),

                      // 1. Nombre del plato
                      CampoTexto(
                        controller: _nombreController,
                        maxLength: 50,
                        decoration: InputDecoration(
                          labelText: 'Nombre del plato *',
                          hintText: 'Ej. Arroz Chaufa Especial',
                          prefixIcon: const Icon(
                            Icons.restaurant_menu,
                            size: 20,
                          ),
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
                              (c) =>
                                  AppSelectItem(value: c, label: c.categoria),
                            )
                            .toList(),
                        onChanged: (cat) => setState(() {
                          _categoria = cat;
                          // Las subcategorías deben ser de la categoría elegida.
                          _subcategoriaIds.removeWhere(
                            (id) =>
                                subcategoriaPorId(id)?.categoriaComidaId !=
                                cat?.id,
                          );
                        }),
                      ),
                      if (_categoria != null &&
                          subcategoriasDe(
                            _categoria!.id,
                            soloActivas: true,
                          ).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        SubcategoriasAcordeon(
                          opciones: subcategoriasDe(
                            _categoria!.id,
                            soloActivas: true,
                          ),
                          seleccion: _subcategoriaIds,
                          // Un plato pertenece a una sola subcategoría: al elegir
                          // otra, reemplaza a la anterior.
                          onChanged: (v) => setState(() {
                            final nuevas = v.difference(_subcategoriaIds);
                            _subcategoriaIds = nuevas.isNotEmpty
                                ? {nuevas.first}
                                : v;
                          }),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // 3. Descripción
                      CampoTexto(
                        controller: _descripcionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Descripción (opcional)',
                          hintText: 'Ingredientes, detalles de preparación o porción...',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
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
                            child: CampoTexto(
                              controller: _precioClienteController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Precio público (S/)',
                                helperText: 'Vacío si se vende por tamaños',
                                hintText: '0.00',
                                prefixText: 'S/ ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
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
                            child: CampoTexto(
                              controller: _precioPersonalController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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

                      // 6. Tamaños (interruptor y filas, se guardan con el plato)
                      _seccionTamanos(),
                      const SizedBox(height: 16),

                      // 7. Selector de Estado (disponible / agotado)
                      _buildEstadoSelector(),
                      const SizedBox(height: 24),

                      // Botones de acción
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 12,
                        runSpacing: 8,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
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
                  editando
                      ? 'Editar plato de la carta'
                      : 'Nuevo plato en la carta',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Configura los datos del plato según la carta oficial',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
      final format = '${t.nombre} · s/ ${t.precio.toStringAsFixed(2)}'
          .toLowerCase();
      return format.contains(query) || t.nombre.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Input para buscar táper
        CampoTexto(
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
            suffixIcon:
                _selectedTaperId != null ||
                    _taperSearchController.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Quitar táper (Sin táper)',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _seleccionarTaper(null),
                  )
                : const Icon(Icons.arrow_drop_down),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.5),
                width: 1.5,
              ),
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
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 28,
                          color: Colors.grey.shade400,
                        ),
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
                                color: AppColors.primaryGreen.withValues(
                                  alpha: 0.1,
                                ),
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
                            selectedTileColor: AppColors.primaryGreen
                                .withValues(alpha: 0.08),
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

  // Tamaños del plato (`carta_variante`): interruptor "Tiene tamaños" y, al
  // activarlo, una fila por tamaño con su nombre y precio. Se guardan junto con
  // el plato en una sola operación.
  Widget _seccionTamanos() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tiene tamaños',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ej. Pequeño S/ 18 y Grande S/ 28. Cada tamaño tiene su '
                      'propio precio.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AppSwitch(
                value: _tieneTamanos,
                onChanged: (v) => setState(() {
                  _tieneTamanos = v;
                  // Al activarlo por primera vez ya hay una fila lista.
                  if (v && _filas.every((f) => !f.activo)) {
                    _filas.add(_FilaTamano());
                  }
                }),
              ),
            ],
          ),
          if (!_tieneTamanos && _filas.any((f) => f.id != null && f.activo))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Al guardar, los tamaños que ya tenía este plato se '
                'desactivarán (no se borran).',
                style: TextStyle(fontSize: 12, color: AppColors.naranja),
              ),
            ),
          if (_tieneTamanos) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < _filas.length; i++) _filaTamano(i),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _filas.add(_FilaTamano())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar tamaño'),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _tamanosAvanzado = !_tamanosAvanzado),
                  child: Text(
                    _tamanosAvanzado
                        ? 'Ocultar avanzado'
                        : 'Avanzado (precio personal y peso)',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _filaTamano(int i) {
    final f = _filas[i];
    final nuevo = f.id == null;
    return Opacity(
      opacity: f.activo ? 1 : 0.5,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: CampoTexto(
                    controller: f.nombre,
                    enabled: f.activo,
                    maxLength: 50,
                    decoration: InputDecoration(
                      labelText: 'Tamaño',
                      hintText: 'Ej. Pequeño',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: CampoTexto(
                    controller: f.precio,
                    enabled: f.activo,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Precio',
                      prefixText: 'S/ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: nuevo
                      ? 'Quitar'
                      : (f.activo ? 'Desactivar tamaño' : 'Activar de nuevo'),
                  onPressed: () => setState(() {
                    if (nuevo) {
                      _filas.removeAt(i).liberar();
                    } else {
                      f.activo = !f.activo;
                    }
                  }),
                  icon: Icon(
                    nuevo
                        ? Icons.close
                        : (f.activo
                              ? Icons.visibility_off_outlined
                              : Icons.restart_alt),
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            if (_tamanosAvanzado && f.activo) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CampoTexto(
                      controller: f.personal,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Precio personal',
                        hintText: 'Igual al público',
                        prefixText: 'S/ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CampoTexto(
                      controller: f.pesoMin,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Peso mín. (kg)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CampoTexto(
                      controller: f.pesoMax,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Peso máx. (kg)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (!f.activo)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Inactivo: no se ofrece al tomar pedidos.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
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
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
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
                      Flexible(
                        child: Text(
                          'Disponible',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _estado == 'disponible'
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
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _estado = 'agotado'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
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
                      Flexible(
                        child: Text(
                          'Agotado',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _estado == 'agotado'
                                ? AppColors.error
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
    );
  }
}

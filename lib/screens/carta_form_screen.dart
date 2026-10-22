import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/categorias_store.dart';
import '../data/presentaciones_store.dart';
import '../data/subcategorias_store.dart';
import '../data/variantes_store.dart';
import '../models/carta_item.dart';
import '../models/carta_presentacion.dart';
import '../models/carta_variante.dart';
import '../models/categoria_comida.dart';
import '../models/unidad_bebida.dart';
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
  // Presentaciones del plato/bebida para guardar junto con él (null = no tocarlas).
  List<CartaPresentacion>? presentaciones,
  bool limpiarImagen,
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
  // Una variante guardada que se quitó de la lista: se desactiva al guardar.
  bool quitada = false;

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

class _FilaPresentacion {
  final String? id;
  String? unidadId;
  String unidadNombre;
  final TextEditingController volumen;
  final TextEditingController precio;
  final TextEditingController personal;
  bool activo;

  _FilaPresentacion({
    this.id,
    this.unidadId,
    this.unidadNombre = '',
    String volumen = '',
    String precio = '',
    String personal = '',
    this.activo = true,
  }) : volumen = TextEditingController(text: volumen),
       precio = TextEditingController(text: precio),
       personal = TextEditingController(text: personal);

  factory _FilaPresentacion.de(CartaPresentacion p) => _FilaPresentacion(
    id: p.id,
    unidadId: p.unidad.id,
    unidadNombre: p.unidad.unidadPresentacion,
    volumen: p.volumenMl > 0 ? p.volumenMl.toString() : '',
    precio: p.precioCliente.toStringAsFixed(2),
    personal:
        p.precioPersonal != null &&
            (p.precioPersonal! - p.precioCliente).abs() >= 0.005
        ? p.precioPersonal!.toStringAsFixed(2)
        : '',
    activo: p.estado,
  );

  void liberar() {
    volumen.dispose();
    precio.dispose();
    personal.dispose();
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
  // Tápers elegidos para el plato, en el orden en que se marcaron.
  final List<String> _tapersElegidos = [];
  String _estado = 'disponible';
  bool _mostrarListaTapers = false;
  bool _cargandoTapers = false;
  // Foto elegida en este formulario (aún no subida).
  Uint8List? _fotoBytes;
  String? _fotoNombre;
  String? _errorFoto;
  bool _quitarFotoActual = false;
  // Variantes: el interruptor "Tiene variantes" y sus filas.
  bool _tieneTamanos = false;
  bool _tamanosAvanzado = false;
  final List<_FilaTamano> _filas = [];
  // Presentaciones: el interruptor "Tiene presentaciones" y sus filas.
  bool _tienePresentaciones = false;
  final List<_FilaPresentacion> _filasPres = [];

  @override
  void initState() {
    super.initState();

    final item = widget.item;
    if (item != null) {
      for (final v in variantesDeCarta(item.id)) {
        _filas.add(_FilaTamano.de(v));
      }
      _tieneTamanos = _filas.any((f) => f.activo);

      for (final p in presentacionesDeCarta(item.id)) {
        _filasPres.add(_FilaPresentacion.de(p));
      }
      _tienePresentaciones = _filasPres.any((f) => f.activo);
    }
    if (unidadesBebida.isEmpty) {
      CatalogService.instance.cargarUnidadesBebida().then((_) {
        if (mounted) setState(() {});
      });
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
    _tapersElegidos.addAll(
      (item?.taperIds.isNotEmpty ?? false)
          ? item!.taperIds
          : [
              if (item?.taperId != null && item!.taperId!.isNotEmpty)
                item.taperId!,
            ],
    );

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

    if (mounted) setState(() {});
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
    for (final f in _filasPres) {
      f.liberar();
    }
    super.dispose();
  }

  // Marca o desmarca un táper al tocarlo; la lista queda abierta para elegir
  // más de uno.
  void _alternarTaper(String id) => setState(() {
    if (!_tapersElegidos.remove(id)) _tapersElegidos.add(id);
  });

  void _quitarTodosTapers() => setState(_tapersElegidos.clear);

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

    final presentacionesGuardar = _presentacionesParaGuardar(idPlato);
    if (presentacionesGuardar.error != null) {
      showAppToast(
        context,
        presentacionesGuardar.error!,
        type: ToastType.error,
      );
      return;
    }

    final usaOpcionesPrecio = _tieneTamanos || _tienePresentaciones;

    final resultado = CartaItem(
      id: idPlato,
      nombrePlato: _nombreController.text.trim(),
      descripcion: _descripcionController.text.trim(),
      categoriaId: _categoria!.id,
      categoriaNombre: _categoria!.categoria,
      subcategoriaIds: _subcategoriaIds.toList(),
      taperId: _tapersElegidos.firstOrNull,
      taperIds: List.of(_tapersElegidos),
      taperNombre: _tapersElegidos.isEmpty
          ? null
          : (CatalogService.instance.tapers
                    .where((x) => x.id == _tapersElegidos.first)
                    .firstOrNull
                    ?.nombre ??
                widget.item?.taperNombre),
      estado: _estado,
      precioCliente: usaOpcionesPrecio ? null : pCliente,
      precioPersonal: usaOpcionesPrecio ? null : pPersonal,
      sedeId: sedeActual,
      urlImagen: _quitarFotoActual ? null : widget.item?.urlImagen,
      creadoEn: widget.item?.creadoEn ?? DateTime.now(),
    );

    final ResultadoPlato salida = (
      item: resultado,
      foto: _fotoBytes,
      nombreFoto: _fotoNombre,
      variantes: tamanos.lista,
      presentaciones: presentacionesGuardar.lista,
      limpiarImagen: _quitarFotoActual && _fotoBytes == null,
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
        error: 'Agrega al menos una variante o apaga "Tiene variantes".',
      );
    }
    for (final f in activas) {
      final precio = _numeroDe(f.precio);
      if (f.nombre.text.trim().isEmpty || precio == null || precio < 0) {
        return (
          lista: null,
          error: 'Cada variante necesita su nombre y un precio válido.',
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

  ({List<CartaPresentacion>? lista, String? error}) _presentacionesParaGuardar(
    String idPlato,
  ) {
    if (!_tienePresentaciones) {
      final existentes = _filasPres
          .where((f) => f.id != null && f.activo)
          .toList();
      if (existentes.isEmpty) return (lista: null, error: null);
      return (
        lista: [
          for (final f in existentes) _presentacion(idPlato, f, activo: false),
        ],
        error: null,
      );
    }
    final activas = _filasPres.where((f) => f.activo).toList();
    if (activas.isEmpty) {
      return (
        lista: null,
        error:
            'Agrega al menos una presentación o apaga "Tiene presentaciones".',
      );
    }
    for (final f in activas) {
      final precio = _numeroDe(f.precio);
      if (f.unidadId == null ||
          f.unidadId!.isEmpty ||
          precio == null ||
          precio < 0) {
        return (
          lista: null,
          error: 'Cada presentación necesita su envase y un precio válido.',
        );
      }
    }
    return (
      lista: [
        for (final f in _filasPres)
          if (f.id != null || f.activo)
            _presentacion(idPlato, f, activo: f.activo),
      ],
      error: null,
    );
  }

  CartaPresentacion _presentacion(
    String idPlato,
    _FilaPresentacion f, {
    required bool activo,
  }) {
    final precio = _numeroDe(f.precio) ?? 0;
    final vol = int.tryParse(f.volumen.text.trim()) ?? 0;
    final unidad =
        unidadesBebida.where((u) => u.id == f.unidadId).firstOrNull ??
        UnidadBebida(
          id: f.unidadId ?? '',
          unidadPresentacion: f.unidadNombre.isNotEmpty
              ? f.unidadNombre
              : 'Presentación',
        );
    return CartaPresentacion(
      id: f.id ?? '',
      cartaId: idPlato,
      unidad: unidad,
      volumenMl: vol,
      precioCliente: precio,
      precioPersonal: _numeroDe(f.personal) ?? precio,
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
        _quitarFotoActual = false;
        _errorFoto = null;
      });
    } catch (e) {
      if (mounted) setState(() => _errorFoto = 'No se pudo leer la foto: $e');
    }
  }

  // Foto del plato: vista previa y botón para subirla o cambiarla.
  Widget _bloqueFoto() {
    final hayFoto =
        _fotoBytes != null ||
        (!_quitarFotoActual && widget.item?.urlImagen != null);
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
                    : ImagenPlato(
                        item: _quitarFotoActual
                            ? _plato
                            : (widget.item ?? _plato),
                        tamanoIcono: 26,
                      ),
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _elegirFoto,
                        icon: const Icon(LucideIcons.camera, size: 16),
                        label: Text(hayFoto ? 'Cambiar foto' : 'Subir foto'),
                      ),
                      if (hayFoto)
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _fotoBytes = null;
                            _fotoNombre = null;
                            _quitarFotoActual = true;
                          }),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Quitar foto'),
                        ),
                    ],
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
                                helperText: 'Vacío si se vende por variantes',
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

                      // 6b. Presentaciones (interruptor y filas para bebidas: Vaso, Jarra, etc.)
                      _seccionPresentaciones(),
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

  /// Selector múltiple de tápers: se marcan y desmarcan tocándolos, los elegidos
  /// se ven como etiquetas y un contador dice cuántos tiene el plato.
  Widget _buildTaperSelector() {
    final todos = CatalogService.instance.tapers;
    final query = _taperSearchController.text.trim().toLowerCase();
    final filtrados = todos.where((t) {
      if (query.isEmpty) return true;
      return t.nombre.toLowerCase().contains(query);
    }).toList();
    final n = _tapersElegidos.length;
    String nombreDe(String id) =>
        todos.where((t) => t.id == id).firstOrNull?.nombre ?? 'Táper';
    final contador = n == 0 ? 'Sin tápers' : (n == 1 ? '1 táper' : '$n tápers');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tápers para llevar (opcional)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: n > 0
                    ? AppColors.primaryGreen.withValues(alpha: 0.12)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                contador,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: n > 0
                      ? AppColors.primaryGreenDark
                      : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (n > 0) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in _tapersElegidos)
                Chip(
                  label: Text(
                    nombreDe(id),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                  deleteIcon: const Icon(Icons.close, size: 16),
                  deleteButtonTooltipMessage: 'Quitar este táper',
                  onDeleted: () => _alternarTaper(id),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        CampoTexto(
          controller: _taperSearchController,
          focusNode: _taperFocusNode,
          onTap: () => setState(() => _mostrarListaTapers = true),
          onChanged: (_) => setState(() => _mostrarListaTapers = true),
          decoration: InputDecoration(
            hintText: 'Busca y marca los tápers del plato...',
            prefixIcon: const Icon(Icons.takeout_dining_outlined, size: 20),
            suffixIcon: IconButton(
              tooltip: _mostrarListaTapers ? 'Cerrar lista' : 'Ver tápers',
              icon: Icon(
                _mostrarListaTapers
                    ? Icons.arrow_drop_up
                    : Icons.arrow_drop_down,
              ),
              onPressed: () =>
                  setState(() => _mostrarListaTapers = !_mostrarListaTapers),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (_mostrarListaTapers) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
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
            // El fondo blanco va en un Material propio para que las filas
            // (ListTile) muestren su selección y su efecto al tocarlas.
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 6, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            n == 0
                                ? 'Toca un táper para marcarlo'
                                : '$n seleccionado${n == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        if (n > 0)
                          TextButton(
                            onPressed: _quitarTodosTapers,
                            child: const Text('Quitar todos'),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 190),
                    child: _cargandoTapers
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        : todos.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              'Aún no hay tápers registrados en inventario.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          )
                        : Scrollbar(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              children: [
                                for (final t in filtrados)
                                  CheckboxListTile(
                                    dense: true,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    value: _tapersElegidos.contains(t.id),
                                    onChanged: (_) => _alternarTaper(t.id),
                                    activeColor: AppColors.primaryGreen,
                                    title: Text(
                                      t.nombre,
                                      style: TextStyle(
                                        fontWeight:
                                            _tapersElegidos.contains(t.id)
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                    secondary: Text(
                                      'S/ ${t.precio.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                if (filtrados.isEmpty)
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
                  const Divider(height: 1),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _mostrarListaTapers = false),
                      child: const Text('Listo'),
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

  // Variantes del plato (`carta_variante`): interruptor "Tiene variantes" y, al
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
                      'Tiene variantes',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ej. Pollo S/ 10 y Carne S/ 12. Cada variante tiene su '
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
                  if (v) {
                    _precioClienteController.clear();
                    _precioPersonalController.clear();
                  }
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
                'Al guardar, las variantes que ya tenía este plato se '
                'desactivarán (no se borran).',
                style: TextStyle(fontSize: 12, color: AppColors.naranja),
              ),
            ),
          if (_tieneTamanos) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < _filas.length; i++)
              if (!_filas[i].quitada) _filaTamano(i),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _filas.add(_FilaTamano())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar variante'),
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
                      labelText: 'Variante',
                      hintText: 'Ej. Pollo',
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
                  tooltip: 'Quitar variante',
                  onPressed: () => setState(() {
                    if (nuevo) {
                      _filas.removeAt(i).liberar();
                    } else {
                      // Una variante guardada no se borra: sale de la lista y
                      // queda desactivada al guardar.
                      f.activo = false;
                      f.quitada = true;
                    }
                  }),
                  icon: Icon(
                    Icons.close,
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

  // Presentaciones del plato (`carta_presentacion`, ej. Vaso 350 ml, Jarra 1000 ml).
  Widget _seccionPresentaciones() {
    final primeraUnidadId = unidadesBebida
        .where((u) => u.estado)
        .firstOrNull
        ?.id;
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
                      'Tiene presentaciones',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ej. Vaso (350 ml) S/ 7 y Jarra (1000 ml) S/ 16. Cada '
                      'presentación tiene su propio precio.',
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
                value: _tienePresentaciones,
                onChanged: (v) => setState(() {
                  _tienePresentaciones = v;
                  if (v) {
                    _precioClienteController.clear();
                    _precioPersonalController.clear();
                  }
                  if (v && _filasPres.every((f) => !f.activo)) {
                    _filasPres.add(
                      _FilaPresentacion(unidadId: primeraUnidadId),
                    );
                  }
                }),
              ),
            ],
          ),
          if (!_tienePresentaciones &&
              _filasPres.any((f) => f.id != null && f.activo))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Al guardar, las presentaciones que ya tenía este plato se '
                'desactivarán (no se borran).',
                style: TextStyle(fontSize: 12, color: AppColors.naranja),
              ),
            ),
          if (_tienePresentaciones) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < _filasPres.length; i++) _filaPresentacion(i),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => setState(
                    () => _filasPres.add(
                      _FilaPresentacion(unidadId: primeraUnidadId),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar presentación'),
                ),
                TextButton.icon(
                  onPressed: _crearNuevaUnidadBebidaEnFormulario,
                  icon: const Icon(Icons.local_drink_outlined, size: 16),
                  label: const Text('Nuevo envase (Vaso, Jarra...)'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _crearNuevaUnidadBebidaEnFormulario() async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo envase / unidad de bebida'),
        content: CampoTexto(
          controller: ctrl,
          autofocus: true,
          maxLength: 25,
          decoration: const InputDecoration(
            labelText: 'Nombre *',
            hintText: 'Ej. Vaso, Jarra, Copa, Botella',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty || !mounted) return;
    try {
      final creada = await CatalogService.instance.crearUnidadBebida(nombre);
      if (!mounted) return;
      setState(() {
        for (final f in _filasPres) {
          f.unidadId ??= creada.id;
        }
      });
      showAppToast(
        context,
        'Envase "${creada.unidadPresentacion}" creado.',
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'No se pudo crear el envase: $e',
        type: ToastType.error,
      );
    }
  }

  Widget _filaPresentacion(int i) {
    final f = _filasPres[i];
    final nuevo = f.id == null;
    final unidadesActivas = unidadesParaElegir(unidadesBebida);
    final unidadValida =
        idDeOpcion(unidadesActivas, unidadesBebida, f.unidadId) ??
        (unidadesActivas.isNotEmpty ? unidadesActivas.first.id : null);
    if (f.unidadId != unidadValida && unidadValida != null) {
      f.unidadId = unidadValida;
    }

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
                  flex: 4,
                  child: AppSelect<String>(
                    label: 'Presentación',
                    value: unidadValida,
                    hint: 'Elige el envase',
                    items: [
                      for (final u in unidadesActivas)
                        AppSelectItem(value: u.id, label: u.unidadPresentacion),
                    ],
                    onChanged: (v) {
                      if (!f.activo) return;
                      setState(() {
                        f.unidadId = v;
                        final u = unidadesActivas
                            .where((x) => x.id == v)
                            .firstOrNull;
                        if (u != null) f.unidadNombre = u.unidadPresentacion;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: CampoTexto(
                    controller: f.volumen,
                    enabled: f.activo,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Volumen',
                      hintText: '350',
                      suffixText: 'ml',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                      : (f.activo
                            ? 'Desactivar presentación'
                            : 'Activar de nuevo'),
                  onPressed: () => setState(() {
                    if (nuevo) {
                      _filasPres.removeAt(i).liberar();
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
            if (!f.activo)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Inactiva: no se ofrece al tomar pedidos.',
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

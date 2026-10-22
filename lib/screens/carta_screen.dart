import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/cartas_store.dart';
import '../data/categorias_store.dart';
import '../data/disponibilidad_store.dart';
import '../data/presentaciones_store.dart';
import '../data/variantes_store.dart';
import '../models/carta_item.dart';
import '../models/carta_presentacion.dart';
import '../models/carta_variante.dart';
import '../models/categoria_comida.dart';
import '../models/usuario.dart';
import '../services/catalog_service.dart';
import '../services/disponibilidad_service.dart';
import '../services/eventos_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/carta_cabecera.dart';
import '../widgets/carta_item_detail_sheet.dart';
import '../widgets/imagen_plato.dart';
import '../widgets/presentacion_rapida_dialog.dart';
import '../widgets/tamano_rapido_dialog.dart';
import 'carta_form_screen.dart';

// Filtro gris para tarjetas de productos inactivos.
const _filtroGris = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

// Catálogo de productos (tabla `carta`): administrado según permisos RBAC
class CartaScreen extends StatefulWidget {
  final bool esAdmin;
  final Usuario? usuario;
  // Categoría activa (null = Todos) y texto de búsqueda, controlados por la cabecera.
  final ValueNotifier<CategoriaComida?> seleccion;
  final ValueNotifier<String> busqueda;
  // Mobile: la pantalla pinta su propia cabecera.
  final bool cabeceraPropia;

  const CartaScreen({
    super.key,
    required this.esAdmin,
    this.usuario,
    required this.seleccion,
    required this.busqueda,
    this.cabeceraPropia = false,
  });

  @override
  State<CartaScreen> createState() => _CartaScreenState();
}

class _CartaScreenState extends State<CartaScreen> {
  bool get _puedeEditar =>
      widget.esAdmin || (widget.usuario?.tienePermiso('UPDATE.CARTA') ?? false);
  bool get _puedeEliminar =>
      widget.esAdmin || (widget.usuario?.tienePermiso('DELETE.CARTA') ?? false);
  bool get _puedeGestionar => _puedeEditar || _puedeEliminar;
  // Marcar "se acabó" hoy (cantidades diarias).
  bool get _puedeAgotar =>
      widget.esAdmin ||
      (widget.usuario?.tienePermiso('UPDATE.CARTA_DISPONIBILIDAD') ?? false);

  @override
  void initState() {
    super.initState();
    CatalogService.instance.cargarUnidadesBebida();
    CatalogService.instance.cargarCarta();
    // Los cambios de otros equipos llegan por el flujo de eventos del servidor
    // (`CARTA_ACTUALIZADA`), sin consultar cada cierto tiempo.
    EventosService.instance.revision.addListener(_alCambiarEnVivo);
  }

  @override
  void dispose() {
    EventosService.instance.revision.removeListener(_alCambiarEnVivo);
    super.dispose();
  }

  // Una categoría borrada desde otro equipo no puede seguir seleccionada.
  void _alCambiarEnVivo() {
    if (!mounted) return;
    final actual = widget.seleccion.value;
    if (actual != null && !categorias.any((c) => c.id == actual.id)) {
      widget.seleccion.value = null;
    }
    setState(() {});
  }

  List<CartaItem> get _cartaFiltrada {
    final categoria = widget.seleccion.value;
    var base = cartasNotifier.value;
    // Los productos inhabilitados solo los ve quien administra la carta: el
    // resto (mozos, cajeros) no debe poder verlos ni pedirlos.
    if (!_puedeEditar) {
      base = base.where((c) => !c.inhabilitado).toList();
    }
    if (categoria != null) {
      base = base.where((c) => c.categoriaId == categoria.id).toList();
    }
    final termino = widget.busqueda.value.trim().toLowerCase();
    if (termino.isNotEmpty) {
      base = base
          .where(
            (c) =>
                c.nombrePlato.toLowerCase().contains(termino) ||
                (c.sku?.toLowerCase().contains(termino) ?? false),
          )
          .toList();
    }
    return base;
  }

  Future<void> _editarPlato(CartaItem item) async {
    final r = await showBlurDialog<ResultadoPlato>(
      context: context,
      builder: (_) => CartaFormScreen(item: item),
    );
    if (r != null) {
      final editado = r.item;
      try {
        final guardado = await CatalogService.instance.actualizarPlato(
          editado,
          variantes: r.variantes,
          presentacionesPlato: r.presentaciones,
          limpiarImagen: r.limpiarImagen,
        );
        String? advertencia;
        String? errorFoto;
        if (r.foto != null) {
          // Si la foto falla, el plato ya quedó guardado: se avisa aparte.
          try {
            final subida = await CatalogService.instance.subirImagenPlato(
              guardado,
              r.foto!,
              r.nombreFoto ?? 'plato.jpg',
            );
            advertencia = subida.advertencia;
          } catch (e) {
            errorFoto = e.toString().replaceFirst('Exception: ', '');
          }
        }
        if (!mounted) return;
        showAppToast(
          context,
          errorFoto == null
              ? '${editado.nombrePlato} se actualizó correctamente.'
              : '${editado.nombrePlato} se actualizó, pero la foto no se '
                    'guardó: $errorFoto',
          type: errorFoto == null ? ToastType.info : ToastType.warning,
          titulo: errorFoto == null ? 'Plato actualizado' : 'Foto pendiente',
        );
        if (advertencia != null) _avisarFotoSoloLocal(advertencia);
      } catch (e) {
        if (!mounted) return;
        showAppToast(
          context,
          'Error al actualizar: $e',
          type: ToastType.error,
          titulo: 'Error',
        );
      }
    }
  }

  // Agrega un tamaño (nombre y precio) a un plato que ya existe.
  Future<void> _agregarTamano(CartaItem item) async {
    final creado = await showBlurDialog<CartaVariante>(
      context: context,
      builder: (_) => TamanoRapidoDialog(plato: item),
    );
    if (creado == null || !mounted) return;
    setState(() {});
    showAppToast(
      context,
      'Variante "${creado.nombre}" agregada a ${item.nombrePlato}.',
      type: ToastType.success,
      titulo: 'Variante creada',
    );
  }

  // Agrega una presentación (ej. Vaso, Jarra y precio) a un plato/bebida que ya existe.
  Future<void> _agregarPresentacion(CartaItem item) async {
    final creada = await showBlurDialog<CartaPresentacion>(
      context: context,
      builder: (_) => PresentacionRapidaDialog(plato: item),
    );
    if (creada == null || !mounted) return;
    setState(() {});
    showAppToast(
      context,
      'Presentación "${creada.unidad.unidadPresentacion}" agregada a ${item.nombrePlato}.',
      type: ToastType.success,
      titulo: 'Presentación creada',
    );
  }

  Future<void> _quitarFoto(CartaItem item) async {
    try {
      await CatalogService.instance.actualizarPlato(
        item.copyWith(limpiarImagen: true),
        limpiarImagen: true,
      );
      if (!mounted) return;
      showAppToast(
        context,
        'Se quitó la foto de ${item.nombrePlato}.',
        type: ToastType.info,
        titulo: 'Foto eliminada',
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'No se pudo quitar la foto: $e',
        type: ToastType.error,
        titulo: 'Error',
      );
    }
  }

  // "Se acabó" hoy / reabrir: no cambia el estado del plato, solo su
  // disponibilidad del día.
  Future<void> _alternarAgotadoHoy(CartaItem item, bool agotadoAhora) async {
    try {
      await DisponibilidadService.instance.marcarAgotado(
        item.id,
        !agotadoAhora,
      );
      if (!mounted) return;
      showAppToast(
        context,
        agotadoAhora
            ? '${item.nombrePlato} se reabrió.'
            : '${item.nombrePlato} se marcó como agotado hoy.',
        type: agotadoAhora ? ToastType.success : ToastType.info,
        titulo: agotadoAhora ? 'Plato reabierto' : 'Plato agotado',
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'No se pudo actualizar: $e',
        type: ToastType.error,
        titulo: 'Error',
      );
    }
  }

  // El servidor guardó la foto en su disco pero no en la nube: se avisa porque
  // en la nube ese disco es temporal y la foto se podría perder.
  void _avisarFotoSoloLocal(String detalle) {
    if (!mounted) return;
    showAppToast(
      context,
      'La foto quedó solo en el servidor y no en la nube: $detalle',
      type: ToastType.warning,
      titulo: 'Foto sin copia en la nube',
      duration: const Duration(seconds: 6),
    );
  }

  // Elige una imagen del equipo, la sube al servidor y la deja como foto del
  // plato.
  Future<void> _subirFoto(CartaItem item) async {
    try {
      final archivos = await FilePicker.pickFiles(type: FileType.image);
      if (archivos.isEmpty) return;
      final f = archivos.first;
      final bytes = await f.readAsBytes();
      final subida = await CatalogService.instance.subirImagenPlato(
        item,
        bytes,
        f.name,
      );
      if (!mounted) return;
      showAppToast(
        context,
        'La foto de ${item.nombrePlato} se guardó.',
        type: ToastType.success,
        titulo: 'Foto actualizada',
      );
      if (subida.advertencia != null) _avisarFotoSoloLocal(subida.advertencia!);
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'No se pudo subir la foto: ${e.toString().replaceFirst('Exception: ', '')}',
        type: ToastType.error,
        titulo: 'Error',
      );
    }
  }

  Future<void> _alternarDisponible(CartaItem item) async {
    try {
      await CatalogService.instance.alternarEstadoPlato(item);
      final nuevoDisponible = !item.disponible;
      if (!mounted) return;
      showAppToast(
        context,
        nuevoDisponible
            ? '${item.nombrePlato} está disponible.'
            : '${item.nombrePlato} se inhabilitó.',
        type: nuevoDisponible ? ToastType.success : ToastType.info,
        titulo: nuevoDisponible
            ? 'Producto habilitado'
            : 'Producto inhabilitado',
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'Error: $e',
        type: ToastType.error,
        titulo: 'Error',
      );
    }
  }

  // Modal de advertencia: la acción no se puede deshacer.
  Future<void> _eliminarPlato(CartaItem item) async {
    final confirmar = await showBlurDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final esMobile = AppBreakpoints.esMobile(dialogContext);
        final anchoPantalla = MediaQuery.sizeOf(dialogContext).width;
        return Material(
          color: Colors.white,
          borderRadius: esMobile
              ? const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.sheet),
                )
              : BorderRadius.circular(AppRadii.card),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: esMobile
                ? BoxConstraints(
                    minWidth: anchoPantalla,
                    maxWidth: anchoPantalla,
                  )
                : const BoxConstraints(minWidth: 320, maxWidth: 320),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, esMobile ? 32 : 24, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Eliminar plato',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¿Seguro que deseas eliminar "${item.nombrePlato}" de la carta? '
                    'Dejará de mostrarse, pero su historial de pedidos se conserva.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (confirmar == true) {
      try {
        await CatalogService.instance.eliminarPlato(item.id);
        if (!mounted) return;
        showAppToast(
          context,
          '${item.nombrePlato} se eliminó de la carta.',
          type: ToastType.error,
          titulo: 'Plato eliminado',
        );
      } catch (e) {
        if (!mounted) return;
        showAppToast(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          type: ToastType.error,
          titulo: 'Error',
        );
      }
    }
  }

  double _precioMinimo(String cartaId) {
    final precios = [
      ...presentacionesDeCarta(
        cartaId,
        soloActivas: true,
      ).map((p) => p.precioCliente),
      ...variantesDeCarta(
        cartaId,
        soloActivas: true,
      ).map((v) => v.precioCliente),
    ];
    if (precios.isEmpty) return 0;
    return precios.reduce((a, b) => a < b ? a : b);
  }

  String _nombreCategoria(String id) {
    for (final c in categorias) {
      if (c.id == id) return c.categoria;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final margen = esMobile ? 12.0 : 24.0;
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([
          widget.seleccion,
          widget.busqueda,
          cartasNotifier,
          disponibilidadHoyNotifier,
          configStockNotifier,
          EventosService.instance.revision,
        ]),
        builder: (context, _) {
          final items = _cartaFiltrada;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.cabeceraPropia)
                Padding(
                  padding: EdgeInsets.fromLTRB(margen, 16, margen, 0),
                  child: CartaCabecera(
                    seleccion: widget.seleccion,
                    busqueda: widget.busqueda,
                    esAdmin: widget.esAdmin,
                    usuario: widget.usuario,
                    vertical: esMobile,
                    mostrarTitulo: esMobile,
                    onCambio: () => setState(() {}),
                  ),
                ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          'Sin resultados',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(margen),
                        child: _grilla(items, esMobile),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 3 columnas en escritorio, 1 en mobile.
  Widget _grilla(List<CartaItem> items, bool esMobile) {
    const espacio = 20.0;
    final columnas = esMobile ? 1 : 3;
    final filas = <Widget>[];
    for (var i = 0; i < items.length; i += columnas) {
      final fin = (i + columnas > items.length) ? items.length : i + columnas;
      final grupo = items.sublist(i, fin);
      filas.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < columnas; j++) ...[
                if (j > 0) const SizedBox(width: espacio),
                Expanded(
                  child: j < grupo.length
                      ? KeyedSubtree(
                          key: ValueKey(grupo[j].id),
                          child: _tarjetaPlato(grupo[j]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < filas.length; i++) ...[
          if (i > 0) const SizedBox(height: espacio),
          filas[i],
        ],
      ],
    );
  }

  Widget _tarjetaPlato(CartaItem item) {
    final tarjeta = _contenidoTarjeta(item);
    if (widget.esAdmin) return tarjeta;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showBlurDialog<void>(
        context: context,
        builder: (_) => CartaItemDetailSheet(item: item),
      ),
      child: tarjeta,
    );
  }

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _contenidoTarjeta(CartaItem item) {
    final estadoDisp = estadoDisponibilidadDe(item.id);
    final varsActivas = variantesDeCarta(item.id, soloActivas: true);
    final presActivas = presentacionesDeCarta(item.id, soloActivas: true);
    final tieneOpciones = varsActivas.isNotEmpty || presActivas.isNotEmpty;
    final desdePrecio = tieneOpciones || item.precioCliente == null;
    final precio = desdePrecio ? _precioMinimo(item.id) : item.precioCliente!;
    final categoria = _nombreCategoria(item.categoriaId);
    final tarjeta = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 10,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            color: const Color(0xFFF1F3F0),
                            child: ImagenPlato(item: item, tamanoIcono: 36),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _chipEstado(item),
                            if (estadoDisp.etiqueta != null) ...[
                              const SizedBox(width: 4),
                              _chipDisponibilidad(estadoDisp),
                            ],
                          ],
                        ),
                      ),
                      if (_puedeEditar)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.urlImagen != null) ...[
                                _botonAccion(
                                  Icons.no_photography_outlined,
                                  'Quitar foto',
                                  () => _quitarFoto(item),
                                ),
                                const SizedBox(width: 6),
                              ],
                              _botonAccion(
                                LucideIcons.camera,
                                item.urlImagen == null
                                    ? 'Subir foto'
                                    : 'Cambiar foto',
                                () => _subirFoto(item),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (categoria.isNotEmpty)
                    Text(
                      categoria.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    item.nombrePlato,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (item.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Solo precio y stock (el resto se ve al editar el plato).
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _dato(
                        'Precio',
                        desdePrecio
                            ? 'Desde S/ ${precio.toStringAsFixed(2)}'
                            : 'S/ ${precio.toStringAsFixed(2)}',
                        destacado: true,
                      ),
                      _dato(
                        'Stock',
                        estadoDisp.tipo == TipoDisponibilidad.conCantidad
                            ? '${estadoDisp.quedan ?? 0}'
                            : (estadoDisp.tipo == TipoDisponibilidad.agotado
                                ? '0 (Agotado)'
                                : (item.stock > 0 ? '${item.stock}' : 'Libre')),
                      ),
                    ],
                  ),
                  if (varsActivas.isNotEmpty || presActivas.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final v in varsActivas)
                          _chipOpcionPrecio(
                            '${v.nombre} · S/ ${v.precioCliente.toStringAsFixed(2)}',
                            AppColors.primaryGreen,
                          ),
                        for (final p in presActivas)
                          _chipOpcionPrecio(
                            '${p.unidad.unidadPresentacion}${p.volumenMl > 0 ? ' (${p.volumenMl} ml)' : ''} · S/ ${p.precioCliente.toStringAsFixed(2)}',
                            AppColors.naranja,
                          ),
                      ],
                    ),
                  ],
                  if (_puedeEditar) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _agregarTamano(item),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            side: BorderSide(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            foregroundColor: AppColors.primaryGreen,
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(
                            'Variante',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _agregarPresentacion(item),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            side: BorderSide(
                              color: AppColors.naranja.withValues(alpha: 0.5),
                            ),
                            foregroundColor: AppColors.naranja,
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(
                            'Presentación',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  if (item.creadoEn != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Creado el ${_fecha(item.creadoEn!)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
    // Inactivo o agotado hoy: tarjeta gris salvo los botones de acción.
    return Stack(
      fit: StackFit.expand,
      children: [
        (item.disponible && estadoDisp.vendible)
            ? tarjeta
            : Opacity(
                opacity: 0.55,
                child: ColorFiltered(colorFilter: _filtroGris, child: tarjeta),
              ),
        if (_puedeGestionar || _puedeAgotar)
          Positioned(
            top: 18,
            right: 18,
            child: Row(
              children: [
                if (_puedeAgotar && item.disponible) ...[
                  _botonAccion(
                    estadoDisp.tipo == TipoDisponibilidad.agotado
                        ? Icons.restart_alt
                        : Icons.block,
                    estadoDisp.tipo == TipoDisponibilidad.agotado
                        ? 'Reabrir'
                        : 'Se acabó (agotado hoy)',
                    () => _alternarAgotadoHoy(
                      item,
                      estadoDisp.tipo == TipoDisponibilidad.agotado,
                    ),
                  ),
                  if (_puedeEditar) const SizedBox(width: 6),
                ],
                if (_puedeEditar)
                  _botonAccion(
                    item.disponible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    item.disponible ? 'Inhabilitar' : 'Habilitar',
                    () => _alternarDisponible(item),
                  ),
                if (_puedeEditar) const SizedBox(width: 6),
                if (_puedeEditar)
                  _botonAccion(
                    Icons.edit_outlined,
                    'Editar',
                    () => _editarPlato(item),
                  ),
                if (_puedeEliminar) const SizedBox(width: 6),
                if (_puedeEliminar)
                  _botonAccion(
                    Icons.delete_outline,
                    'Eliminar',
                    () => _eliminarPlato(item),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // Disponibilidad de hoy: "Quedan N", "Agotado hoy" o "Sin abrir hoy".
  Widget _chipDisponibilidad(EstadoDisponibilidad e) {
    final alerta = !e.vendible;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: alerta ? AppColors.error : AppColors.naranja,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        e.etiqueta!,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _chipEstado(CartaItem item) {
    final etiqueta = item.disponible
        ? 'Disponible'
        : (item.agotado ? 'Agotado' : 'Inhabilitado');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: item.disponible
            ? AppColors.primaryGreen
            : Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        etiqueta,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _botonAccion(IconData icono, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icono, size: 16, color: Colors.grey.shade800),
          ),
        ),
      ),
    );
  }

  Widget _chipOpcionPrecio(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _dato(String etiqueta, String valor, {bool destacado = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: destacado
            ? AppColors.primaryGreen.withValues(alpha: 0.1)
            : AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            etiqueta,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: destacado ? AppColors.primaryGreen : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

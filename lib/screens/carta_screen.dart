import 'package:flutter/material.dart';

import '../data/cartas_store.dart';
import '../data/categorias_store.dart';
import '../data/presentaciones_store.dart';
import '../models/carta_item.dart';
import '../models/categoria_comida.dart';
import '../theme/app_theme.dart';
import '../utils/agregados_utils.dart';
import '../utils/blur_dialog.dart';
import '../utils/carta_visuals.dart';
import '../widgets/app_toast.dart';
import '../widgets/carta_cabecera.dart';
import '../widgets/carta_item_detail_sheet.dart';
import 'carta_form_screen.dart';

// Filtro gris para tarjetas de productos inactivos.
const _filtroGris = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

// Catálogo de productos (tabla `productos`) en tarjetas; el Mesero solo
// consulta, el Administrador puede crear/editar/eliminar.
// TODO backend: reemplazar cartasNotifier por `productos`.
class CartaScreen extends StatefulWidget {
  final bool esAdmin;
  // Categoría activa (null = Todos) y texto de búsqueda, controlados por la
  // cabecera.
  final ValueNotifier<CategoriaComida?> seleccion;
  final ValueNotifier<String> busqueda;
  // Mobile: la pantalla pinta su propia cabecera.
  final bool cabeceraPropia;

  const CartaScreen({
    super.key,
    required this.esAdmin,
    required this.seleccion,
    required this.busqueda,
    this.cabeceraPropia = false,
  });

  @override
  State<CartaScreen> createState() => _CartaScreenState();
}

class _CartaScreenState extends State<CartaScreen> {
  List<CartaItem> get _cartaFiltrada {
    final categoria = widget.seleccion.value;
    var base = cartasNotifier.value;
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
    final editado = await showBlurDialog<CartaItem>(
      context: context,
      builder: (_) => CartaFormScreen(item: item),
    );
    if (editado != null) {
      cartasNotifier.value = cartasNotifier.value
          .map((c) => c.id == editado.id ? editado : c)
          .toList();
      if (!mounted) return;
      showAppToast(
        context,
        '${editado.nombrePlato} se actualizó correctamente.',
        type: ToastType.info,
        titulo: 'Plato actualizado',
      );
    }
  }

  void _alternarDisponible(CartaItem item) {
    final nuevo = item.copyWith(
      estado: item.disponible ? 'inactivo' : 'activo',
    );
    cartasNotifier.value = cartasNotifier.value
        .map((c) => c.id == item.id ? nuevo : c)
        .toList();
    showAppToast(
      context,
      nuevo.disponible
          ? '${item.nombrePlato} está disponible.'
          : '${item.nombrePlato} se desactivó.',
      type: nuevo.disponible ? ToastType.success : ToastType.info,
      titulo: nuevo.disponible ? 'Producto activado' : 'Producto desactivado',
    );
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
                    'Esta acción no se puede deshacer.',
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
      cartasNotifier.value = cartasNotifier.value
          .where((c) => c.id != item.id)
          .toList();
      if (!mounted) return;
      showAppToast(
        context,
        '${item.nombrePlato} se eliminó de la carta.',
        type: ToastType.error,
        titulo: 'Plato eliminado',
      );
    }
  }

  double _precioMinimo(String cartaId) {
    final precios = mockPresentaciones
        .where((p) => p.cartaId == cartaId)
        .map((p) => p.precioCliente);
    if (precios.isEmpty) return 0;
    return precios.reduce((a, b) => a < b ? a : b);
  }

  String _nombreCategoria(String id) {
    for (final c in mockCategorias) {
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
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => CartaItemDetailSheet(item: item),
      ),
      child: tarjeta,
    );
  }

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _contenidoTarjeta(CartaItem item) {
    final desdePrecio = item.precioCliente == null;
    final precio = desdePrecio ? _precioMinimo(item.id) : item.precioCliente!;
    final imagen = imagenDeCarta(item.id);
    final categoria = _nombreCategoria(item.categoriaId);
    final tarjeta = Container(
      padding: const EdgeInsets.all(12),
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
                    child: item.imagenBytes != null
                        ? Image.memory(item.imagenBytes!, fit: BoxFit.cover)
                        : imagen != null
                        ? Image.asset(imagen, fit: BoxFit.cover)
                        : Center(
                            child: Icon(
                              iconoDeCategoria(item.categoriaId),
                              size: 36,
                              color: Colors.grey.shade400,
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: _chipDisponible(item.disponible),
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
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          if (item.descripcion.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.descripcion,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 10),
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
                'Costo',
                item.costo == null
                    ? '—'
                    : 'S/ ${item.costo!.toStringAsFixed(2)}',
              ),
              _dato('Stock', '${item.stock}'),
              _dato('SKU', item.sku ?? '—'),
            ],
          ),
          if (item.agregados.isNotEmpty || item.limiteAgregados != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Agregados',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (item.limiteAgregados != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(máx. ${item.limiteAgregados})',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in agregadosSimples(item.agregados))
                  _chipAgregado(a),
                for (final g in gruposDeAgregados(item.agregados))
                  _chipGrupoAgregado(g),
                if (item.agregados.isEmpty)
                  Text(
                    'Sin agregados',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ],
          const Spacer(),
          if (item.creadoEn != null) ...[
            const SizedBox(height: 10),
            Text(
              'Creado el ${_fecha(item.creadoEn!)}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
    // Inactivo: tarjeta gris salvo los botones de activar/editar/eliminar.
    return Stack(
      fit: StackFit.expand,
      children: [
        item.disponible
            ? tarjeta
            : Opacity(
                opacity: 0.55,
                child: ColorFiltered(colorFilter: _filtroGris, child: tarjeta),
              ),
        if (widget.esAdmin)
          Positioned(
            top: 18,
            right: 18,
            child: Row(
              children: [
                _botonAccion(
                  item.disponible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  item.disponible ? 'Desactivar' : 'Activar',
                  () => _alternarDisponible(item),
                ),
                const SizedBox(width: 6),
                _botonAccion(
                  Icons.edit_outlined,
                  'Editar',
                  () => _editarPlato(item),
                ),
                const SizedBox(width: 6),
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

  Widget _chipDisponible(bool disponible) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: disponible
            ? AppColors.primaryGreen
            : Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        disponible ? 'Disponible' : 'No disponible',
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

  Widget _chipAgregado(Map<String, dynamic> agregado) {
    final nombre = '${agregado['nombre'] ?? agregado.values.firstOrNull ?? ''}';
    final precio = agregado['precio'];
    final texto = precio is num
        ? '$nombre · S/ ${precio.toStringAsFixed(2)}'
        : nombre;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.navbar,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _chipGrupoAgregado(Map<String, dynamic> grupo) {
    final items = itemsDeGrupo(
      grupo,
    ).map((it) => '${it['nombre']}').join(', ');
    final maximo = cantidadMaximaGrupo(grupo) ?? 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.navbar,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${nombreGrupo(grupo)} (máx. $maximo)${items.isEmpty ? '' : ': $items'}',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

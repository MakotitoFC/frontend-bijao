import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../data/mock_cartas.dart';
import '../data/mock_categorias.dart';
import '../data/mock_presentaciones.dart';
import '../models/carta_item.dart';
import '../models/categoria_comida.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../utils/carta_visuals.dart';
import '../widgets/app_toast.dart';
import '../widgets/carta_item_detail_sheet.dart';
import 'carta_form_screen.dart';

// Desatura la tarjeta completa (foto incluida) a escala de grises para los
// platos inactivos.
const _filtroGris = ColorFilter.matrix(<double>[
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

// Catálogo de la carta. El Mesero solo consulta (sin editar); el
// Administrador además puede crear/editar/eliminar platos. Mismo diseño de
// tarjeta y tabs que el catálogo del pedido. Crear y buscar viven en la
// barra superior; el CRUD por ítem (editar/eliminar) se revela al pasar el
// cursor, empujando el ancho de la tarjeta en vez de superponerse (sin
// modales: crear/editar navegan a CartaFormScreen, una pantalla completa).
// TODO: al conectar el backend, reemplazar mockCartas/mockCategorias por la
// carta real de `carta`/`categoria_comida` filtrada por estado activo.
class CartaScreen extends StatefulWidget {
  final bool esAdmin;

  const CartaScreen({super.key, required this.esAdmin});

  @override
  State<CartaScreen> createState() => _CartaScreenState();
}

class _CartaScreenState extends State<CartaScreen> {
  CategoriaComida? _categoriaSeleccionada;
  List<CartaItem> _cartas = List.of(mockCartas);

  final _busquedaController = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  List<CartaItem> get _cartaFiltrada {
    var base = _categoriaSeleccionada == null
        ? _cartas
        : _cartas
              .where((c) => c.categoriaId == _categoriaSeleccionada!.id)
              .toList();
    final termino = _busqueda.trim().toLowerCase();
    if (termino.isNotEmpty) {
      base = base
          .where((c) => c.nombrePlato.toLowerCase().contains(termino))
          .toList();
    }
    return base;
  }

  Future<void> _crearPlato() async {
    final nuevo = await showBlurDialog<CartaItem>(
      context: context,
      builder: (_) => const CartaFormScreen(),
    );
    if (nuevo != null) {
      setState(() => _cartas = [..._cartas, nuevo]);
      if (!mounted) return;
      showAppToast(
        context,
        '${nuevo.nombrePlato} se agregó a la carta.',
        type: ToastType.success,
        titulo: 'Plato creado',
      );
    }
  }

  Future<void> _editarPlato(CartaItem item) async {
    final editado = await showBlurDialog<CartaItem>(
      context: context,
      builder: (_) => CartaFormScreen(item: item),
    );
    if (editado != null) {
      setState(() {
        _cartas = _cartas.map((c) => c.id == editado.id ? editado : c).toList();
      });
      if (!mounted) return;
      showAppToast(
        context,
        '${editado.nombrePlato} se actualizó correctamente.',
        type: ToastType.info,
        titulo: 'Plato actualizado',
      );
    }
  }

  // Modal de advertencia (no un simple confirm): ícono y texto de alerta,
  // dejando claro que la acción no se puede deshacer. Fondo blanco, ancho
  // reducido y difuminado detrás, igual que el resto de modales centrados.
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
      setState(() => _cartas = _cartas.where((c) => c.id != item.id).toList());
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

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final paddingExterno = esMobile ? 12.0 : 20.0;
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(paddingExterno),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  'Pedidos',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _barraSuperior(esMobile),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _tabsCategorias(),
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: _cartaFiltrada.isEmpty
                    ? Center(
                        child: Text(
                          'Sin resultados',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // En mobile, si es Administrador se reserva el
                            // ancho de la franja de editar/eliminar (que en
                            // mobile queda siempre visible, no por hover) para
                            // que la tarjeta + franja no desborden el ancho.
                            final anchoTarjeta = esMobile
                                ? constraints.maxWidth -
                                      (widget.esAdmin ? 38 : 0)
                                : 190.0;
                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                for (final item in _cartaFiltrada)
                                  KeyedSubtree(
                                    key: ValueKey(item.id),
                                    child: _tarjetaPlato(item, anchoTarjeta),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Buscador + botón de crear (solo Administrador), en la misma fila. El
  // Mesero solo ve el buscador. En mobile el buscador se estira y el botón
  // queda solo con "+ Nuevo".
  Widget _barraSuperior(bool esMobile) {
    final buscador = TextField(
      controller: _busquedaController,
      onChanged: (v) => setState(() => _busqueda = v),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Buscar productos...',
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 18,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.primaryGreen),
        ),
      ),
    );
    return Row(
      children: [
        esMobile
            ? Expanded(child: buscador)
            : SizedBox(width: 200, child: buscador),
        if (widget.esAdmin) ...[
          const SizedBox(width: 12),
          _botonNuevoPlato(esMobile),
        ],
      ],
    );
  }

  Widget _botonNuevoPlato(bool esMobile) {
    return FilledButton.icon(
      onPressed: _crearPlato,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      icon: const Icon(Icons.add, size: 18),
      label: Text(
        esMobile ? 'Nuevo' : 'Nuevo plato',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  // Los tabs no se estiran a lo ancho de la fila: cada uno ocupa solo el
  // espacio de su contenido y quedan alineados a la izquierda. Scrollable en
  // horizontal para que no se desborden en pantallas angostas (mobile).
  Widget _tabsCategorias() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tabCategoria(null, 'Todo', HugeIcons.strokeRoundedGridView),
          for (final cat in mockCategorias)
            _tabCategoria(cat, cat.categoria, iconoDeCategoria(cat.id)),
        ],
      ),
    );
  }

  // Los íconos de los tabs no cambian de color al seleccionar: solo el
  // texto y la franja inferior indican la categoría activa.
  Widget _tabCategoria(
    CategoriaComida? cat,
    String label,
    List<List<dynamic>> icono,
  ) {
    final seleccionado = _categoriaSeleccionada?.id == cat?.id;
    return InkWell(
      onTap: () => setState(() => _categoriaSeleccionada = cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: seleccionado ? AppColors.primaryGreen : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: icono, size: 20, color: Colors.grey.shade700),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w600,
                color: seleccionado
                    ? AppColors.primaryGreen
                    : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaPlato(CartaItem item, double ancho) {
    final inactivo = item.estado == 'inactivo';
    final contenido = inactivo
        ? ColorFiltered(
            colorFilter: _filtroGris,
            child: _contenidoTarjeta(item, ancho),
          )
        : _contenidoTarjeta(item, ancho);
    if (!widget.esAdmin) {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => CartaItemDetailSheet(item: item),
        ),
        child: _tarjetaBase(ancho: ancho, inactivo: inactivo, child: contenido),
      );
    }
    return _HoverCrudCard(
      ancho: ancho,
      inactivo: inactivo,
      siempreVisible: AppBreakpoints.esMobile(context),
      onEditar: () => _editarPlato(item),
      onEliminar: () => _eliminarPlato(item),
      child: contenido,
    );
  }

  Widget _tarjetaBase({
    required Widget child,
    required double ancho,
    bool inactivo = false,
  }) {
    return Container(
      width: ancho,
      decoration: BoxDecoration(
        color: inactivo ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade400, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }

  Widget _contenidoTarjeta(CartaItem item, double ancho) {
    final desdePrecio = item.precioCliente == null;
    final precio = desdePrecio ? _precioMinimo(item.id) : item.precioCliente!;
    final inactivo = item.estado == 'inactivo';
    final imagen = imagenDeCarta(item.id);
    return SizedBox(
      width: ancho - 24,
      height: 248,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: const Color(0xFFF1F3F0),
                    child: imagen != null
                        ? Image.asset(imagen, fit: BoxFit.cover)
                        : Center(
                            child: HugeIcon(
                              icon: iconoDeCategoria(item.categoriaId),
                              size: 36,
                              color: Colors.grey.shade400,
                            ),
                          ),
                  ),
                ),
              ),
              if (inactivo)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Inactivo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            item.nombrePlato,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          if (item.descripcion.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.descripcion,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            desdePrecio
                ? 'Desde S/ ${precio.toStringAsFixed(2)}'
                : 'S/ ${precio.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// Tarjeta con revelado de CRUD al pasar el cursor: una franja verde se
// expande desde el borde derecho empujando el ancho total de la tarjeta (no
// se superpone al contenido ni a las tarjetas vecinas), mostrando
// editar/eliminar en blanco; al salir el cursor, la franja se contrae. Sin
// modales: editar navega a CartaFormScreen (pantalla completa).
class _HoverCrudCard extends StatefulWidget {
  final Widget child;
  final double ancho;
  final bool inactivo;
  // En mobile no hay hover (pantalla táctil): la franja de editar/eliminar
  // queda siempre visible en vez de revelarse al pasar el cursor.
  final bool siempreVisible;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _HoverCrudCard({
    required this.child,
    required this.ancho,
    this.inactivo = false,
    this.siempreVisible = false,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  State<_HoverCrudCard> createState() => _HoverCrudCardState();
}

class _HoverCrudCardState extends State<_HoverCrudCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final mostrarFranja = widget.siempreVisible || _hover;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: widget.ancho,
                  color: widget.inactivo ? Colors.grey.shade100 : Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: widget.child,
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: mostrarFranja ? 38 : 0,
                  color: AppColors.primaryGreen,
                  child: ClipRect(
                    child: Column(
                      children: [
                        _botonAccion(
                          Icons.edit_outlined,
                          'Editar',
                          widget.onEditar,
                        ),
                        _botonAccion(
                          Icons.delete_outline,
                          'Eliminar',
                          widget.onEliminar,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _botonAccion(IconData icono, String tooltip, VoidCallback onTap) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          child: Center(child: Icon(icono, color: Colors.white, size: 18)),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../data/cartas_store.dart';
import '../data/categorias_store.dart';
import '../models/carta_item.dart';
import '../models/categoria_comida.dart';
import '../models/usuario.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'carta_acciones.dart';
import 'app_search_field.dart';
import 'app_tag.dart';
import 'categorias_crud_dialog.dart';
import 'tabs_desplazables.dart';

// Cabecera de Productos: título, buscador, "Nueva categoría" y tabs de categorías.
class CartaCabecera extends StatefulWidget {
  final ValueNotifier<CategoriaComida?> seleccion;
  final ValueNotifier<String> busqueda;
  final bool esAdmin;
  final Usuario? usuario;
  final bool vertical;
  // En escritorio el título vive en el header global, no aquí.
  final bool mostrarTitulo;
  final VoidCallback onCambio;

  const CartaCabecera({
    super.key,
    required this.seleccion,
    required this.busqueda,
    required this.esAdmin,
    this.usuario,
    this.vertical = false,
    this.mostrarTitulo = true,
    required this.onCambio,
  });

  @override
  State<CartaCabecera> createState() => _CartaCabeceraState();
}

class _CartaCabeceraState extends State<CartaCabecera> {
  bool get _puedeCrearProducto =>
      widget.esAdmin || (widget.usuario?.tienePermiso('CREAR.CARTA') ?? false);
  bool get _puedeCrearCategoria =>
      widget.esAdmin || (widget.usuario?.tienePermiso('CREAR.CATEGORIA_COMIDA') ?? false);

  late final _busquedaController = TextEditingController(
    text: widget.busqueda.value,
  );

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    await showBlurDialog<void>(
      context: context,
      builder: (_) => CategoriasCrudDialog(
        seleccion: widget.seleccion,
        onCambio: widget.onCambio,
      ),
    );
  }

  Future<void> _eliminarCategoria(CategoriaComida cat) async {
    final cantidad = cartasNotifier.value
        .where((c) => c.categoriaId == cat.id)
        .length;
    if (cantidad > 0) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No se puede eliminar'),
          content: Text(
            '"${cat.categoria}" tiene $cantidad producto(s). Muévelos a otra '
            'categoría o elimínalos antes de borrarla.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Seguro que deseas eliminar "${cat.categoria}"?'),
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
    if (confirmar != true) return;
    try {
      await CatalogService.instance.eliminarCategoria(cat.id);
      widget.seleccion.value = null;
      widget.onCambio();
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text('No se pudo eliminar la categoría: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buscador() {
    return AppSearchField(
      controller: _busquedaController,
      hint: 'Buscar en la carta...',
      onChanged: (v) => widget.busqueda.value = v,
    );
  }

  Widget _botonCategoria() {
    return OutlinedButton.icon(
      onPressed: _agregar,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
        side: const BorderSide(color: AppColors.primaryGreen),
      ),
      icon: const Icon(Icons.add, size: 18),
      label: const Text(
        'Categoría',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const titulo = Text(
      'Carta',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    );
    final tabs = ListenableBuilder(
      listenable: Listenable.merge([widget.seleccion, cartasNotifier]),
      builder: (context, _) {
        final cartas = cartasNotifier.value;
        final actual = widget.seleccion.value;
        return TabsDesplazables(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tab(
                'Todos',
                cartas.length,
                actual == null,
                () => widget.seleccion.value = null,
              ),
              for (final cat in categorias)
                _tab(
                  cat.categoria,
                  _contar(cartas, cat),
                  actual?.id == cat.id,
                  () => widget.seleccion.value = cat,
                  onEliminar: widget.esAdmin && actual?.id == cat.id
                      ? () => _eliminarCategoria(cat)
                      : null,
                ),
            ],
          ),
        );
      },
    );
    if (widget.vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          titulo,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buscador(),
                ),
              ),
              if (widget.esAdmin) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Nueva categoría',
                  onPressed: _agregar,
                  icon: const Icon(Icons.category_outlined),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  tooltip: 'Nuevo plato',
                  onPressed: () => crearPlato(
                    context,
                    categoriaId: widget.seleccion.value?.id,
                  ),
                  icon: const Icon(Icons.add),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          tabs,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (widget.mostrarTitulo) ...[titulo, const SizedBox(width: 32)],
            _buscador(),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: tabs),
            if (_puedeCrearCategoria) ...[
              const SizedBox(width: 24),
              _botonCategoria(),
            ],
            if (_puedeCrearProducto) ...[
              const SizedBox(width: 10),
              _botonNuevoProducto(),
            ],
          ],
        ),
      ],
    );
  }

  Widget _botonNuevoProducto() {
    return FilledButton.icon(
      onPressed: () =>
          crearPlato(context, categoriaId: widget.seleccion.value?.id),
      style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
      icon: const Icon(Icons.add, size: 18),
      label: const Text(
        'Plato',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  int _contar(List<CartaItem> cartas, CategoriaComida cat) =>
      cartas.where((c) => c.categoriaId == cat.id).length;

  // Tab de categoría: la activa tiene trazo verde, las demás se ven atenuadas.
  Widget _tab(
    String label,
    int cantidad,
    bool activo,
    VoidCallback onTap, {
    VoidCallback? onEliminar,
  }) {
    return AppTag(
      etiqueta: label,
      activo: activo,
      cantidad: cantidad,
      onTap: onTap,
      onQuitar: onEliminar,
      tooltipQuitar: 'Eliminar categoría',
    );
  }
}

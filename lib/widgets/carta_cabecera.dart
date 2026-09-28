import 'package:flutter/material.dart';

import '../data/cartas_store.dart';
import '../data/categorias_store.dart';
import '../models/carta_item.dart';
import '../models/categoria_comida.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'carta_acciones.dart';
import 'categorias_crud_dialog.dart';
import 'tabs_desplazables.dart';

// Cabecera de Productos: título, buscador, "Nueva categoría" (solo admin)
// y tabs de categorías.
class CartaCabecera extends StatefulWidget {
  final ValueNotifier<CategoriaComida?> seleccion;
  final ValueNotifier<String> busqueda;
  final bool esAdmin;
  final bool vertical;
  // En escritorio el título vive en el header global, no aquí.
  final bool mostrarTitulo;
  final VoidCallback onCambio;

  const CartaCabecera({
    super.key,
    required this.seleccion,
    required this.busqueda,
    required this.esAdmin,
    this.vertical = false,
    this.mostrarTitulo = true,
    required this.onCambio,
  });

  @override
  State<CartaCabecera> createState() => _CartaCabeceraState();
}

class _CartaCabeceraState extends State<CartaCabecera> {
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
    mockCategorias.removeWhere((c) => c.id == cat.id);
    widget.seleccion.value = null;
    widget.onCambio();
  }

  Widget _buscador() {
    return TextField(
      controller: _busquedaController,
      onChanged: (v) => widget.busqueda.value = v,
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
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.primaryGreen),
        ),
      ),
    );
  }

  Widget _botonCategoria() {
    return OutlinedButton.icon(
      onPressed: _agregar,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
        side: const BorderSide(color: AppColors.primaryGreen),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
      'Productos',
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
              for (final cat in mockCategorias)
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
              Expanded(child: _buscador()),
              if (widget.esAdmin) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Nueva categoría',
                  onPressed: _agregar,
                  icon: const Icon(Icons.category_outlined),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  tooltip: 'Nuevo producto',
                  onPressed: () => crearPlato(context),
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
            SizedBox(width: 320, child: _buscador()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: tabs),
            if (widget.esAdmin) ...[
              const SizedBox(width: 24),
              _botonCategoria(),
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
      onPressed: () => crearPlato(context),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      icon: const Icon(Icons.add, size: 18),
      label: const Text(
        'Producto',
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
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: activo ? AppColors.primaryGreen : Colors.grey.shade300,
              width: activo ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: activo
                      ? AppColors.primaryGreenDark
                      : Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: activo ? AppColors.primaryGreen : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$cantidad',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: activo ? Colors.white : Colors.grey.shade500,
                  ),
                ),
              ),
              if (onEliminar != null) ...[
                const SizedBox(width: 2),
                Tooltip(
                  message: 'Eliminar categoría',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onEliminar,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

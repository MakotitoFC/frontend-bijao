import 'package:flutter/material.dart';

import 'app_toast.dart';
import 'dialogo_app.dart';

import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/cartas_store.dart';
import '../data/categorias_store.dart';
import '../models/carta_item.dart';
import '../models/categoria_comida.dart';
import '../models/usuario.dart';
import '../services/catalog_service.dart';
import '../services/eventos_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'carta_acciones.dart';
import 'app_search_field.dart';
import 'app_tag.dart';
import 'apertura_diaria_dialog.dart';
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
  bool get _puedeAbrirDia =>
      widget.esAdmin ||
      (widget.usuario?.tienePermiso('CREAR.CARTA_DISPONIBILIDAD') ?? false);
  bool get _puedeCrearCategoria =>
      widget.esAdmin ||
      (widget.usuario?.tienePermiso('CREAR.CATEGORIA_COMIDA') ?? false);

  late final _busquedaController = TextEditingController(
    text: widget.busqueda.value,
  );

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  bool _actualizando = false;

  // Vuelve a leer del servidor las categorías y la carta (platos nuevos que
  // llegaron desde otro equipo o desde la nube mientras esta pantalla estaba
  // abierta).
  Future<void> _actualizar() async {
    if (_actualizando) return;
    setState(() => _actualizando = true);
    try {
      await CatalogService.instance.recargarCarta();
      if (!mounted) return;
      widget.onCambio();
      showAppToast(context, 'Carta actualizada.', type: ToastType.success);
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'No se pudo actualizar la carta: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _actualizando = false);
    }
  }

  Widget _botonActualizar() => IconButton.outlined(
    tooltip: 'Actualizar carta',
    onPressed: _actualizando ? null : _actualizar,
    icon: _actualizando
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(LucideIcons.refreshCw),
  );

  Future<void> _abrirDia() async {
    await showBlurDialog<bool>(
      context: context,
      builder: (_) => const AperturaDiariaDialog(),
    );
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
      await showBlurDialog<void>(
        context: context,
        builder: (dialogContext) => AlertaApp(
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
    final confirmar = await showBlurDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertaApp(
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
      showBlurDialog(
        context: context,
        builder: (dialogContext) => AlertaApp(
          title: const Text('Error'),
          content: Text('No se pudo eliminar la categoría: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
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
      listenable: Listenable.merge([
        widget.seleccion,
        cartasNotifier,
        EventosService.instance.revision,
      ]),
      builder: (context, _) {
        final cartas = cartasNotifier.value;
        final actual = widget.seleccion.value;
        if (actual != null && !categorias.any((c) => c.id == actual.id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.seleccion.value?.id == actual.id) {
              widget.seleccion.value = null;
            }
          });
        }
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
              const SizedBox(width: 8),
              _botonActualizar(),
              if (widget.esAdmin) ...[
                const SizedBox(width: 6),
                IconButton.outlined(
                  tooltip: 'Apertura del día',
                  onPressed: _abrirDia,
                  icon: const Icon(LucideIcons.calendarCheck),
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  tooltip: 'Nueva categoría',
                  onPressed: _agregar,
                  icon: const Icon(LucideIcons.folderPlus),
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
            const SizedBox(width: 16),
            _botonActualizar(),
            if (_puedeAbrirDia) ...[
              const SizedBox(width: 24),
              OutlinedButton.icon(
                onPressed: _abrirDia,
                icon: const Icon(Icons.event_available_outlined, size: 18),
                label: const Text(
                  'Abrir el día',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
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

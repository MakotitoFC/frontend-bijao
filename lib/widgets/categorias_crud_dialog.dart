import 'package:flutter/material.dart';

import '../data/cartas_store.dart';
import '../data/categorias_store.dart';
import '../models/categoria_comida.dart';
import '../theme/app_theme.dart';

// Modal "Categorías": lista, agrega, edita y elimina categorías.
class CategoriasCrudDialog extends StatefulWidget {
  final ValueNotifier<CategoriaComida?> seleccion;
  final VoidCallback onCambio;

  const CategoriasCrudDialog({
    super.key,
    required this.seleccion,
    required this.onCambio,
  });

  @override
  State<CategoriasCrudDialog> createState() => _CategoriasCrudDialogState();
}

class _CategoriasCrudDialogState extends State<CategoriasCrudDialog> {
  final _nombreController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  void _agregar() {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) return;
    final repetida = mockCategorias.any(
      (c) => c.categoria.toLowerCase() == nombre.toLowerCase(),
    );
    if (repetida) {
      setState(() => _error = 'Ya existe esa categoría');
      return;
    }
    setState(() {
      agregarCategoria(nombre);
      _nombreController.clear();
      _error = null;
    });
    widget.onCambio();
  }

  Future<void> _editar(CategoriaComida cat) async {
    final controller = TextEditingController(text: cat.categoria);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar categoría'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nuevo == null || nuevo.isEmpty || nuevo == cat.categoria) return;
    setState(() => renombrarCategoria(cat.id, nuevo));
    widget.onCambio();
  }

  Future<void> _eliminar(CategoriaComida cat) async {
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
    setState(() {
      mockCategorias.removeWhere((c) => c.id == cat.id);
      if (widget.seleccion.value?.id == cat.id) widget.seleccion.value = null;
    });
    widget.onCambio();
  }

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    final categorias = List.of(mockCategorias)
      ..sort((a, b) => a.orden.compareTo(b.orden));
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
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              )
            : const BoxConstraints(minWidth: 420, maxWidth: 420, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, esMobile ? 20 : 16, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Categorías',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nombreController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Nueva categoría...',
                          ),
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                          onSubmitted: (_) => _agregar(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Agregar',
                        onPressed: _agregar,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        _error!,
                        style: const TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Flexible(
              child: categorias.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Sin categorías todavía',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: categorias.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (context, i) {
                        final cat = categorias[i];
                        final cantidad = cartasNotifier.value
                            .where((c) => c.categoriaId == cat.id)
                            .length;
                        return ListTile(
                          title: Text(
                            cat.categoria,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '$cantidad producto(s)',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                onPressed: () => _editar(cat),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: AppColors.error,
                                ),
                                onPressed: () => _eliminar(cat),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../data/cartas_store.dart';
import '../data/categorias_store.dart';
import '../models/categoria_comida.dart';
import '../theme/app_theme.dart';

// Modal "Categorías": lista, agrega, edita (en la misma fila) y elimina.
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
  // Categoría que se está editando en su propia fila (null = ninguna).
  String? _editandoId;
  String? _errorEdicion;
  final _editController = TextEditingController();

  @override
  void dispose() {
    _nombreController.dispose();
    _editController.dispose();
    super.dispose();
  }

  void _agregar() {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) return;
    final repetida = categorias.any(
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

  // Edición en la propia fila: el nombre se vuelve un input.
  void _empezarEdicion(CategoriaComida cat) {
    setState(() {
      _editandoId = cat.id;
      _editController.text = cat.categoria;
    });
  }

  void _cancelarEdicion() => setState(() => _editandoId = null);

  void _guardarEdicion(CategoriaComida cat) {
    final nuevo = _editController.text.trim();
    if (nuevo.isEmpty || nuevo == cat.categoria) {
      _cancelarEdicion();
      return;
    }
    final repetida = categorias.any(
      (c) => c.id != cat.id && c.categoria.toLowerCase() == nuevo.toLowerCase(),
    );
    if (repetida) {
      setState(() => _errorEdicion = 'Ya existe esa categoría');
      return;
    }
    setState(() {
      renombrarCategoria(cat.id, nuevo);
      _editandoId = null;
      _errorEdicion = null;
    });
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
      categorias.removeWhere((c) => c.id == cat.id);
      if (widget.seleccion.value?.id == cat.id) widget.seleccion.value = null;
    });
    widget.onCambio();
  }

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    final ordenadas = List.of(categorias)
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
            : const BoxConstraints(
                minWidth: 420,
                maxWidth: 420,
                maxHeight: 560,
              ),
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Flexible(
              child: ordenadas.isEmpty
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
                      itemCount: ordenadas.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (context, i) {
                        final cat = ordenadas[i];
                        final cantidad = cartasNotifier.value
                            .where((c) => c.categoriaId == cat.id)
                            .length;
                        final editando = _editandoId == cat.id;
                        return ListTile(
                          title: editando
                              ? SizedBox(
                                  height: AppSizes.control,
                                  child: TextField(
                                    controller: _editController,
                                    expands: true,
                                    maxLines: null,
                                    minLines: null,
                                    textAlignVertical: TextAlignVertical.center,
                                    autofocus: true,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                    ),
                                    onChanged: (_) {
                                      if (_errorEdicion != null) {
                                        setState(() => _errorEdicion = null);
                                      }
                                    },
                                    onSubmitted: (_) => _guardarEdicion(cat),
                                  ),
                                )
                              : Text(
                                  cat.categoria,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                          subtitle: editando && _errorEdicion != null
                              ? Text(
                                  _errorEdicion!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.error,
                                  ),
                                )
                              : Text(
                                  '$cantidad producto(s)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                          trailing: editando
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Guardar',
                                      icon: const Icon(
                                        Icons.check,
                                        size: 20,
                                        color: AppColors.primaryGreen,
                                      ),
                                      onPressed: () => _guardarEdicion(cat),
                                    ),
                                    IconButton(
                                      tooltip: 'Cancelar',
                                      icon: const Icon(Icons.close, size: 20),
                                      onPressed: _cancelarEdicion,
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Editar',
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                      ),
                                      onPressed: () => _empezarEdicion(cat),
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

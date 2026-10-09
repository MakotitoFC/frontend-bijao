import 'package:flutter/material.dart';

import '../data/cartas_store.dart';
import '../data/categorias_store.dart';
import '../models/categoria_comida.dart';
import '../services/catalog_service.dart';
import '../data/subcategorias_store.dart';
import '../theme/app_theme.dart';
import '../models/subcategoria.dart';

// Modal "Categorías": lista, agrega, edita (en la misma fila) y elimina. Cada
// categoría muestra sus subcategorías como tags naranjas, con un botón para
// agregar más en la misma fila.
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

  // Subcategorías: categoría donde se está escribiendo una nueva, subcategoría
  // que se renombra y el error mostrado bajo los tags de una categoría.
  String? _agregandoSubEn;
  String? _editandoSubId;
  String? _errorSubEn;
  String? _errorSub;
  final _subController = TextEditingController();

  @override
  void dispose() {
    _nombreController.dispose();
    _editController.dispose();
    _subController.dispose();
    super.dispose();
  }

  void _cerrarCampoSub() => setState(() {
    _agregandoSubEn = null;
    _editandoSubId = null;
    _errorSub = null;
    _errorSubEn = null;
    _subController.clear();
  });

  Future<void> _guardarSub(CategoriaComida cat) async {
    final nombre = _subController.text.trim();
    if (nombre.isEmpty) {
      _cerrarCampoSub();
      return;
    }
    if (existeSubcategoria(cat.id, nombre, salvo: _editandoSubId)) {
      setState(() {
        _errorSubEn = cat.id;
        _errorSub = 'Ya existe esa subcategoría';
      });
      return;
    }
    try {
      final editando = subcategoriaPorId(_editandoSubId);
      if (editando != null) {
        await CatalogService.instance.actualizarSubcategoria(
          editando,
          nombre: nombre,
        );
      } else {
        await CatalogService.instance.crearSubcategoria(cat.id, nombre);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorSubEn = cat.id;
        _errorSub = 'Error al guardar: $e';
      });
      return;
    }
    if (mounted) _cerrarCampoSub();
  }

  Future<void> _eliminarSub(CategoriaComida cat, Subcategoria s) async {
    final enUso = cartasNotifier.value
        .where((c) => c.subcategoriaIds.contains(s.id))
        .length;
    if (enUso > 0) {
      setState(() {
        _errorSubEn = cat.id;
        _errorSub =
            '"${s.subcategoria}" tiene $enUso producto(s). Quítala de ellos '
            'antes de eliminarla.';
      });
      return;
    }
    try {
      await CatalogService.instance.eliminarSubcategoria(s.id);
      if (!mounted) return;
      setState(() {
        _errorSub = null;
        _errorSubEn = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorSubEn = cat.id;
        _errorSub = 'No se pudo eliminar: $e';
      });
    }
  }

  // Campo en línea (mismo estilo de los tags) para escribir una subcategoría.
  Widget _campoSub(CategoriaComida cat) {
    return Container(
      width: 200,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.platoDelDia),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _subController,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              textAlignVertical: TextAlignVertical.center,
              decoration: const InputDecoration(
                hintText: 'Subcategoría...',
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (_) {
                if (_errorSub != null) setState(() => _errorSub = null);
              },
              onSubmitted: (_) => _guardarSub(cat),
            ),
          ),
          InkWell(
            onTap: () => _guardarSub(cat),
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(5),
              child: Icon(Icons.check, size: 16, color: AppColors.platoDelDia),
            ),
          ),
          InkWell(
            onTap: _cerrarCampoSub,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(0, 5, 8, 5),
              child: Icon(Icons.close, size: 16, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  // Tag naranja de una subcategoría: al tocarlo se renombra; la x la elimina.
  Widget _tagSub(CategoriaComida cat, Subcategoria s) {
    return Material(
      color: AppColors.platoDelDia,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() {
          _agregandoSubEn = null;
          _editandoSubId = s.id;
          _subController.text = s.subcategoria;
          _errorSub = null;
        }),
        child: SizedBox(
          height: 32,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14, right: 6),
                child: Text(
                  s.subcategoria,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _eliminarSub(cat, s),
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(2, 6, 10, 6),
                  child: Icon(Icons.close, size: 15, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Fila de subcategorías: botón "+ Subcategoría" y los tags; si no caben en
  // la fila pasan a la siguiente.
  Widget _zonaSub(CategoriaComida cat) {
    final lista = subcategoriasDe(cat.id);
    final agregando = _agregandoSubEn == cat.id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (agregando)
                _campoSub(cat)
              else
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _editandoSubId = null;
                    _agregandoSubEn = cat.id;
                    _subController.clear();
                    _errorSub = null;
                  }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.platoDelDia,
                    side: const BorderSide(color: AppColors.platoDelDia),
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Subcategoría'),
                ),
              for (final s in lista)
                if (_editandoSubId == s.id) _campoSub(cat) else _tagSub(cat, s),
            ],
          ),
          if (_errorSub != null && _errorSubEn == cat.id)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                _errorSub!,
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _agregar() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) return;
    final repetida = categorias.any(
      (c) => c.categoria.toLowerCase() == nombre.toLowerCase(),
    );
    if (repetida) {
      setState(() => _error = 'Ya existe esa categoría');
      return;
    }
    try {
      await CatalogService.instance.crearCategoria(nombre);
      setState(() {
        _nombreController.clear();
        _error = null;
      });
      widget.onCambio();
    } catch (e) {
      setState(() => _error = 'Error al crear: $e');
    }
  }

  // Edición en la propia fila: el nombre se vuelve un input.
  void _empezarEdicion(CategoriaComida cat) {
    setState(() {
      _editandoId = cat.id;
      _editController.text = cat.categoria;
    });
  }

  void _cancelarEdicion() => setState(() => _editandoId = null);

  Future<void> _guardarEdicion(CategoriaComida cat) async {
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
    try {
      await CatalogService.instance.actualizarCategoria(cat.id, nuevo);
      setState(() {
        _editandoId = null;
        _errorEdicion = null;
      });
      widget.onCambio();
    } catch (e) {
      setState(() => _errorEdicion = 'Error: $e');
    }
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
    try {
      await CatalogService.instance.eliminarCategoria(cat.id);
      setState(() {
        if (widget.seleccion.value?.id == cat.id) widget.seleccion.value = null;
      });
      widget.onCambio();
    } catch (e) {
      // Ignorar o registrar error
    }
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
                maxHeight: 640,
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
                        final fila = ListTile(
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
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [fila, _zonaSub(cat)],
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

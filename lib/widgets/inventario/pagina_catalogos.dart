import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../data/catalogos_store.dart';
import '../../models/tipo_producto.dart';
import '../../models/unidad_producto.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/blur_dialog.dart';
import '../app_toast.dart';
import '../tipo_producto_form_dialog.dart';
import '../unidad_producto_form_dialog.dart';
import 'inventario_comun.dart';

// Inventario > Tipos y unidades: las clasificaciones que se eligen al registrar
// un producto. Aquí se crean, editan y eliminan.
class PaginaCatalogos extends StatefulWidget {
  const PaginaCatalogos({super.key});

  @override
  State<PaginaCatalogos> createState() => _PaginaCatalogosState();
}

class _PaginaCatalogosState extends State<PaginaCatalogos> {
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    await Future.wait([
      CatalogService.instance.cargarTiposProducto(),
      CatalogService.instance.cargarUnidadesProducto(),
    ]);
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _editarTipo([TipoProducto? tipo]) async {
    final r = await showBlurDialog<bool>(
      context: context,
      builder: (_) => TipoProductoFormDialog(item: tipo),
    );
    if (r == true && mounted) setState(() {});
  }

  Future<void> _editarUnidad([UnidadProducto? unidad]) async {
    final r = await showBlurDialog<bool>(
      context: context,
      builder: (_) => UnidadProductoFormDialog(item: unidad),
    );
    if (r == true && mounted) setState(() {});
  }

  Future<void> _eliminarTipo(TipoProducto t) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar tipo de producto',
      mensaje:
          '¿Eliminar "${t.tipoProducto}"? Si ya hay productos de este tipo, '
          'no se podrá borrar.',
    );
    if (!ok) return;
    try {
      await CatalogService.instance.eliminarTipoProducto(t.id);
      if (!mounted) return;
      setState(() {});
      showAppToast(context, 'Tipo eliminado', type: ToastType.success);
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'No se pudo eliminar: ${e.toString().replaceFirst('Exception: ', '')}',
        type: ToastType.error,
      );
    }
  }

  Future<void> _eliminarUnidad(UnidadProducto u) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar unidad',
      mensaje:
          '¿Eliminar "${u.unidad}"? Si ya hay productos con esta unidad, no '
          'se podrá borrar.',
    );
    if (!ok) return;
    try {
      await CatalogService.instance.eliminarUnidadProducto(u.id);
      if (!mounted) return;
      setState(() {});
      showAppToast(context, 'Unidad eliminada', type: ToastType.success);
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'No se pudo eliminar: ${e.toString().replaceFirst('Exception: ', '')}',
        type: ToastType.error,
      );
    }
  }

  List<Widget> _controles(VoidCallback editar, VoidCallback eliminar) => [
    IconButton(
      tooltip: 'Editar',
      onPressed: editar,
      icon: Icon(LucideIcons.pencil, size: 16, color: Colors.grey.shade700),
    ),
    IconButton(
      tooltip: 'Eliminar',
      onPressed: eliminar,
      icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
    ),
  ];

  String _alcance(String? sedeId) =>
      sedeId == null ? 'Todas las sedes' : 'Solo esta sede';

  @override
  Widget build(BuildContext context) {
    final vacio = _cargando ? 'Cargando…' : null;
    return PaginaInventario(
      secciones: [
        SeccionInventario(
          titulo: 'Tipos de producto de almacén',
          descripcion:
              'Clasifican lo que compras y guardas en el almacén (insumo, '
              'bebida, desechable…). Se eligen al crear un producto de '
              'inventario. No son las categorías de la carta.',
          accion: BotonNuevo(etiqueta: 'Tipo', onPressed: () => _editarTipo()),
          mensajeVacio:
              vacio ?? 'Aún no hay tipos. Crea el primero con "Tipo".',
          filas: [
            for (final t in tiposProducto)
              FilaInventario(
                titulo: tituloConEtiquetas(t.tipoProducto, [
                  if (t.esIngrediente) const EtiquetaFila('Ingrediente'),
                  if (!t.estado) const EtiquetaFila('Inactivo'),
                ], activo: t.estado),
                detalle: _alcance(t.sedeId),
                controles: _controles(
                  () => _editarTipo(t),
                  () => _eliminarTipo(t),
                ),
              ),
          ],
        ),
        SeccionInventario(
          titulo: 'Unidades de medida',
          descripcion:
              'Kg, litro, unidad, paquete… Se eligen al crear un '
              'producto y al registrar compras.',
          accion: BotonNuevo(
            etiqueta: 'Unidad',
            onPressed: () => _editarUnidad(),
          ),
          mensajeVacio:
              vacio ?? 'Aún no hay unidades. Crea la primera con "Unidad".',
          filas: [
            for (final u in unidadesProducto)
              FilaInventario(
                titulo: tituloConEtiquetas(u.unidad, [
                  if (!u.estado) const EtiquetaFila('Inactiva'),
                ], activo: u.estado),
                detalle: _alcance(u.sedeId),
                controles: _controles(
                  () => _editarUnidad(u),
                  () => _eliminarUnidad(u),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

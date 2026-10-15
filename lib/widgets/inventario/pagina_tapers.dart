import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../models/taper.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/blur_dialog.dart';
import '../app_search_field.dart';
import '../app_switch.dart';
import '../app_toast.dart';
import '../taper_form_dialog.dart';
import 'inventario_comun.dart';

// Inventario > Tápers: los recipientes que se cobran en pedidos para llevar o
// delivery. Su stock se lleva en inventario.
class PaginaTapers extends StatefulWidget {
  const PaginaTapers({super.key});

  @override
  State<PaginaTapers> createState() => _PaginaTapersState();
}

class _PaginaTapersState extends State<PaginaTapers> {
  String _busqueda = '';
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    await CatalogService.instance.cargarTapers();
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _abrir([Taper? taper]) async {
    final r = await showBlurDialog<Taper>(
      context: context,
      builder: (_) => TaperFormDialog(taper: taper),
    );
    if (r != null && mounted) setState(() {});
  }

  Future<void> _eliminar(Taper t) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar táper',
      mensaje: '¿Eliminar "${t.nombre}"?',
    );
    if (!ok) return;
    try {
      await CatalogService.instance.eliminarTaper(t.id);
      if (!mounted) return;
      setState(() {});
      showAppToast(context, 'Táper eliminado', type: ToastType.success);
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'Error al eliminar táper: $e',
        type: ToastType.error,
      );
    }
  }

  Future<void> _alternar(Taper t) async {
    try {
      await CatalogService.instance.alternarEstadoTaper(t);
      if (!mounted) return;
      setState(() {});
      showAppToast(
        context,
        t.estado ? 'Táper desactivado' : 'Táper activado',
        type: ToastType.info,
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'Error: $e', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tapers = CatalogService.instance.tapers;
    final q = _busqueda.trim().toLowerCase();
    final filtrados = [
      for (final t in tapers)
        if (q.isEmpty || t.nombre.toLowerCase().contains(q)) t,
    ];
    return PaginaInventario(
      secciones: [
        SeccionInventario(
          titulo: 'Tápers',
          descripcion:
              'Recipientes que se cobran en pedidos para llevar o delivery. '
              'Apaga uno para dejar de ofrecerlo.',
          accion: BotonNuevo(etiqueta: 'Táper', onPressed: () => _abrir()),
          barra: Align(
            alignment: Alignment.centerLeft,
            child: AppSearchField(
              hint: 'Buscar táper...',
              onChanged: (v) => setState(() => _busqueda = v),
            ),
          ),
          mensajeVacio: _cargando && tapers.isEmpty
              ? 'Cargando…'
              : (tapers.isEmpty
                    ? 'Aún no hay tápers. Crea el primero con "Táper".'
                    : 'Ningún táper coincide con la búsqueda.'),
          filas: [
            for (final t in filtrados)
              FilaInventario(
                titulo: tituloConEtiquetas(t.nombre, [
                  if (t.estado && t.stockMinimo > 0 && t.stock <= t.stockMinimo)
                    const EtiquetaFila('Stock bajo', color: AppColors.warning),
                ], activo: t.estado),
                detalle:
                    'S/ ${t.precio.toStringAsFixed(2)} · stock ${cantidadTexto(t.stock)}'
                    '${t.estado ? '' : ' · No se ofrece'}',
                controles: [
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: () => _abrir(t),
                    icon: Icon(
                      LucideIcons.pencil,
                      size: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    onPressed: () => _eliminar(t),
                    icon: const Icon(
                      LucideIcons.trash2,
                      size: 16,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AppSwitch(value: t.estado, onChanged: (_) => _alternar(t)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

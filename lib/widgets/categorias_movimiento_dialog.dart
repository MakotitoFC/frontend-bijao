import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/movimientos_caja_store.dart';
import '../models/movimiento_caja.dart';
import '../services/movimiento_caja_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'app_toast.dart';
import 'campo_texto.dart';
import 'dialogo_app.dart';

class CategoriasMovimientoDialog extends StatefulWidget {
  const CategoriasMovimientoDialog({super.key});

  @override
  State<CategoriasMovimientoDialog> createState() =>
      _CategoriasMovimientoDialogState();
}

class _CategoriasMovimientoDialogState extends State<CategoriasMovimientoDialog> {
  TipoMovimiento _filtroTipo = TipoMovimiento.ingreso;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  Future<void> _recargar() async {
    setState(() => _cargando = true);
    try {
      await MovimientoCajaService.instance.cargarCategorias();
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _crearOEditar({CategoriaMovimiento? existente}) async {
    final nombreCtrl = TextEditingController(text: existente?.nombre ?? '');
    var tipoSeleccionado = existente?.tipo ?? _filtroTipo;
    var activo = existente?.activo ?? true;

    final confirmar = await showBlurDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => DialogoApp(
          titulo: existente == null
              ? 'Nueva categoría de movimiento'
              : 'Editar categoría',
          ancho: 400,
          acciones: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (nombreCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Guardar'),
            ),
          ],
          children: [
            CampoTexto(
              controller: nombreCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre de la categoría',
                hintText: 'Ej. Ventas, Sencillo, Compra insumos...',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<TipoMovimiento>(
                    segments: const [
                      ButtonSegment(
                        value: TipoMovimiento.ingreso,
                        label: Text('Ingreso'),
                        icon: Icon(LucideIcons.arrowDownLeft, size: 16),
                      ),
                      ButtonSegment(
                        value: TipoMovimiento.egreso,
                        label: Text('Salida'),
                        icon: Icon(LucideIcons.arrowUpRight, size: 16),
                      ),
                    ],
                    selected: {tipoSeleccionado},
                    onSelectionChanged: (set) {
                      setDialogState(() => tipoSeleccionado = set.first);
                    },
                  ),
                ),
              ],
            ),
            if (existente != null) ...[
              const SizedBox(height: 12),
              SwitchListTile(
                value: activo,
                onChanged: (v) => setDialogState(() => activo = v),
                title: const Text('Categoría activa', style: TextStyle(fontSize: 13)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
    );

    if (confirmar != true || !mounted) return;
    final nombre = nombreCtrl.text.trim();
    if (nombre.isEmpty) return;

    try {
      if (existente == null) {
        await MovimientoCajaService.instance.crearCategoria(
          nombre: nombre,
          tipo: tipoSeleccionado,
        );
        if (mounted) {
          showAppToast(context, 'Categoría creada con éxito', type: ToastType.success);
        }
      } else {
        await MovimientoCajaService.instance.editarCategoria(
          id: existente.id,
          nombre: nombre,
          tipo: tipoSeleccionado,
          activo: activo,
        );
        if (mounted) {
          showAppToast(context, 'Categoría actualizada con éxito', type: ToastType.success);
        }
      }
      _recargar();
    } catch (e) {
      if (mounted) {
        showAppToast(context, e.toString(), type: ToastType.error);
      }
    }
  }

  Future<void> _eliminar(CategoriaMovimiento cat) async {
    final confirmar = await showBlurDialog<bool>(
      context: context,
      builder: (ctx) => AlertaApp(
        title: const Text('Eliminar categoría'),
        content: Text('¿Deseas eliminar la categoría "${cat.nombre}"? Si ya tiene movimientos registrados, te sugerimos inactivarla.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;
    try {
      await MovimientoCajaService.instance.eliminarCategoria(cat.id);
      if (mounted) {
        showAppToast(context, 'Categoría eliminada', type: ToastType.success);
      }
      _recargar();
    } catch (e) {
      if (mounted) {
        showAppToast(context, e.toString(), type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorias = categoriasMovimiento
        .where((c) => c.tipo == _filtroTipo)
        .toList();

    return DialogoApp(
      titulo: 'Categorías de movimiento (Caja / Ventas)',
      ancho: 520,
      acciones: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: () => _crearOEditar(),
          icon: const Icon(LucideIcons.plus, size: 16),
          label: const Text('Nueva categoría'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
        ),
      ],
      children: [
        Text(
          'Configura los conceptos de ingresos (ventas, sencillo) y egresos (gastos, insumos) '
          'que se utilizan al registrar movimientos y pagos.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<TipoMovimiento>(
                segments: const [
                  ButtonSegment(
                    value: TipoMovimiento.ingreso,
                    label: Text('Ingresos'),
                    icon: Icon(LucideIcons.arrowDownLeft, size: 16),
                  ),
                  ButtonSegment(
                    value: TipoMovimiento.egreso,
                    label: Text('Salidas / Egresos'),
                    icon: Icon(LucideIcons.arrowUpRight, size: 16),
                  ),
                ],
                selected: {_filtroTipo},
                onSelectionChanged: (set) =>
                    setState(() => _filtroTipo = set.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (categorias.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(LucideIcons.tag, size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No hay categorías de ${_filtroTipo.etiqueta.toLowerCase()} registradas',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _crearOEditar(),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: Text('Crear categoría de ${_filtroTipo.etiqueta.toLowerCase()}'),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categorias.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (ctx, idx) {
                final c = categorias[idx];
                final color = c.tipo == TipoMovimiento.ingreso
                    ? AppColors.primaryGreen
                    : AppColors.error;
                return ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      c.tipo == TipoMovimiento.ingreso
                          ? LucideIcons.arrowDownLeft
                          : LucideIcons.arrowUpRight,
                      size: 16,
                      color: color,
                    ),
                  ),
                  title: Text(
                    c.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: c.activo ? null : TextDecoration.lineThrough,
                      color: c.activo ? Colors.black87 : Colors.grey.shade500,
                    ),
                  ),
                  subtitle: Text(
                    c.activo ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.activo ? Colors.grey.shade600 : AppColors.error,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(LucideIcons.pencil, size: 16),
                        onPressed: () => _crearOEditar(existente: c),
                      ),
                      IconButton(
                        tooltip: 'Eliminar',
                        icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                        onPressed: () => _eliminar(c),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

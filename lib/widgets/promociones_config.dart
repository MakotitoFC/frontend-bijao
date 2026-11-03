import 'package:flutter/material.dart';

import 'dialogo_app.dart';

import '../data/promociones_destacadas_store.dart';
import '../data/promociones_store.dart';
import '../models/promocion.dart';
import '../services/api_client.dart';
import '../services/promocion_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'app_toast.dart';
import 'app_switch.dart';
import 'campo_texto.dart';
import 'tabla_app.dart';
import 'promocion_nueva_dialog.dart';

// Configuración de promociones (administrador): cada promoción es un acordeón
// con sus componentes (huecos por subcategoría) y, en cada uno, los productos
// permitidos. El primero activo es el incluido; los demás son los cambios que
// el mozo puede hacer si el cliente lo pide.
class PromocionesConfig extends StatefulWidget {
  const PromocionesConfig({super.key});

  @override
  State<PromocionesConfig> createState() => _PromocionesConfigState();
}

class _PromocionesConfigState extends State<PromocionesConfig> {
  // Promociones colapsadas por el usuario (por defecto todas expandidas).
  // Detalle abierto (modal): se vuelve a dibujar cuando cambia algo.
  VoidCallback? _refrescarDetalle;
  String? _detalleId;

  @override
  void initState() {
    super.initState();
    cargarPromocionesDestacadas();
    configCumpleanos.addListener(_alCambiarCumpleanos);
    promocionesDestacadas.addListener(_alCambiarCumpleanos);
    PromocionService.instance.cargar().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _alCambiarCumpleanos() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    configCumpleanos.removeListener(_alCambiarCumpleanos);
    promocionesDestacadas.removeListener(_alCambiarCumpleanos);
    super.dispose();
  }

  // Cumpleaños: se puede renombrar, describir, quitar el amarillo y eliminar
  // (deja de salir en el registro de pedidos; se puede restaurar).
  Future<void> _editarCumpleanos() async {
    final actual = configCumpleanos.value;
    final nombre = TextEditingController(text: actual.nombre);
    final descripcion = TextEditingController(text: actual.descripcion);
    var destacada = esPromocionDestacada(idCumpleanos);
    final ok = await showBlurDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogo) => DialogoApp(
          titulo: 'Editar Cumpleaños',
          ancho: 460,
          acciones: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Guardar'),
            ),
          ],
          children: [
            CampoTexto(
              controller: nombre,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            CampoTexto(
              controller: descripcion,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: 8),
            AppSwitchTile(
              contentPadding: EdgeInsets.zero,
              value: destacada,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFFEAB308),
              title: const Text('Destacada (color amarillo)'),
              onChanged: (v) => setDialogo(() => destacada = v),
            ),
          ],
        ),
      ),
    );
    final n = nombre.text.trim();
    final d = descripcion.text.trim();
    nombre.dispose();
    descripcion.dispose();
    if (ok != true || !mounted) return;
    await guardarConfigCumpleanos((
      nombre: n.isEmpty ? nombreCumpleanosPorDefecto : n,
      descripcion: d.isEmpty ? descripcionCumpleanosPorDefecto : d,
      eliminada: false,
    ));
    await marcarPromocionDestacada(idCumpleanos, destacada);
    if (mounted) {
      showAppToast(context, 'Cumpleaños actualizado.', type: ToastType.success);
    }
  }

  Future<void> _eliminarCumpleanos() async {
    if (!await _confirmar(
      'Eliminar Cumpleaños',
      'Deja de salir en el registro de pedidos. Puedes restaurarla desde '
          'esta pantalla cuando quieras.',
    )) {
      return;
    }
    final a = configCumpleanos.value;
    await guardarConfigCumpleanos((
      nombre: a.nombre,
      descripcion: a.descripcion,
      eliminada: true,
    ));
  }

  Future<void> _restaurarCumpleanos() async {
    final a = configCumpleanos.value;
    await guardarConfigCumpleanos((
      nombre: a.nombre,
      descripcion: a.descripcion,
      eliminada: false,
    ));
  }

  // Envía el cambio al servidor y, si sale bien, refresca la pantalla y avisa
  // con [exito]; si no, muestra el motivo.
  Future<void> _ejecutar(
    Future<void> Function() accion, {
    required String exito,
  }) async {
    try {
      await accion();
      if (!mounted) return;
      setState(() {});
      _refrescarDetalle?.call();
      // Si se eliminó la promoción abierta, se cierra su detalle.
      if (_detalleId != null && !promociones.any((p) => p.id == _detalleId)) {
        _detalleId = null;
        Navigator.of(context).pop();
      }
      showAppToast(context, exito, type: ToastType.success);
    } catch (e) {
      // Se vuelve a leer lo que quedó guardado, por si el cambio se aplicó a
      // medias.
      await PromocionService.instance.cargar();
      if (!mounted) return;
      setState(() {});
      _refrescarDetalle?.call();
      showAppToast(
        context,
        e is ApiException ? e.message : 'No se pudo guardar: $e',
        type: ToastType.error,
      );
    }
  }

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<bool> _confirmar(String titulo, String texto) async {
    final r = await showBlurDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertaApp(
        title: Text(titulo),
        content: Text(texto),
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
    return r == true;
  }

  // ---------- acciones ----------

  // Registro en un solo modal: se guarda la promoción y luego, uno tras otro,
  // sus componentes y productos (las mismas rutas del servidor de siempre).
  Future<void> _nuevaPromocion() async {
    final r = await showBlurDialog<PromocionCompleta>(
      context: context,
      builder: (_) => const PromocionNuevaDialog(),
    );
    if (r == null || !mounted) return;
    await _ejecutar(() async {
      await PromocionService.instance.crearPromocion(r.promocion);
      for (final comp in r.componentes) {
        await PromocionService.instance.crearComponente(comp.componente);
        for (final o in comp.opciones) {
          await PromocionService.instance.crearOpcion(o);
        }
      }
    }, exito: 'Promoción "${r.promocion.nombre}" creada.');
  }

  // Editar en el mismo modal de pasos. Al guardar se envían al servidor solo
  // las diferencias, con las mismas llamadas de siempre (promoción, componente
  // y opción).
  Future<void> _editarPromocion(Promocion p) async {
    final r = await showBlurDialog<PromocionCompleta>(
      context: context,
      builder: (_) => PromocionNuevaDialog(existente: p),
    );
    if (r == null || !mounted) return;
    await _ejecutar(
      () => _aplicarEdicion(p, r),
      exito: 'Promoción "${r.promocion.nombre}" actualizada.',
    );
  }

  Future<void> _aplicarEdicion(Promocion original, PromocionCompleta r) async {
    final s = PromocionService.instance;
    await s.actualizarPromocionEnServidor(r.promocion);
    final viejos = componentesDe(original.id);
    final nuevosIds = {for (final c in r.componentes) c.componente.id};
    // Componentes quitados.
    for (final v in viejos) {
      if (!nuevosIds.contains(v.id)) await s.eliminarComponenteEnServidor(v.id);
    }
    for (final c in r.componentes) {
      final viejo = viejos.where((v) => v.id == c.componente.id).firstOrNull;
      if (viejo == null) {
        // Componente nuevo, con todos sus productos.
        await s.crearComponente(c.componente);
        for (final o in c.opciones) {
          await s.crearOpcion(o);
        }
        continue;
      }
      if (viejo.subcategoriaId != c.componente.subcategoriaId ||
          viejo.cantidad != c.componente.cantidad) {
        await s.actualizarComponenteEnServidor(c.componente);
      }
      final opViejas = opcionesDe(viejo.id);
      final opNuevasIds = {for (final o in c.opciones) o.id};
      for (final ov in opViejas) {
        if (!opNuevasIds.contains(ov.id)) await s.eliminarOpcionEnServidor(ov);
      }
      for (final o in c.opciones) {
        final ov = opViejas.where((x) => x.id == o.id).firstOrNull;
        if (ov == null) {
          await s.crearOpcion(o);
        } else if (ov.cartaId != o.cartaId ||
            ov.cartaPresentacionId != o.cartaPresentacionId ||
            ov.precio != o.precio ||
            ov.estado != o.estado) {
          await s.actualizarOpcionEnServidor(o);
        }
      }
    }
  }

  Future<void> _eliminarPromocion(Promocion p) async {
    if (!await _confirmar(
      'Eliminar promoción',
      '¿Eliminar "${p.nombre}" con todos sus componentes y opciones?',
    )) {
      return;
    }
    await _ejecutar(
      () => PromocionService.instance.eliminarPromocionEnServidor(p.id),
      exito: 'Promoción "${p.nombre}" eliminada.',
    );
  }

  // ---------- UI ----------

  // Registros de promociones: título con el botón "+ Promoción" y una tabla.
  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(esMobile ? 16 : 28),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Promociones',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _nuevaPromocion,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Promoción'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'El mozo vende cada promoción tal como la configuras; solo '
                  'cambia un producto por otra opción registrada aquí.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
                if (configCumpleanos.value.eliminada)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _restaurarCumpleanos,
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Restaurar Cumpleaños'),
                    ),
                  ),
                const SizedBox(height: 14),
                TablaApp<Promocion>(
                  scrollInterno: true,
                  porPagina: 10,
                  filas: [
                    if (!configCumpleanos.value.eliminada) _cumpleanos,
                    ...promociones,
                  ],
                  onFila: (p) => p.id == idCumpleanos
                      ? _editarCumpleanos()
                      : _editarPromocion(p),
                  columnas: _columnas(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Cumpleaños: cada producto con el precio que se elija (por defecto S/ 0.00).
  Promocion get _cumpleanos => Promocion(
    id: idCumpleanos,
    nombre: configCumpleanos.value.nombre,
    descripcion: configCumpleanos.value.descripcion,
    estado: true,
  );

  List<ColumnaTabla<Promocion>> _columnas() => [
    ColumnaTabla(
      titulo: 'Promoción',
      flex: 1.6,
      anchoMin: 180,
      rol: RolTarjeta.titulo,
      ordenarPor: (p) => p.nombre.toLowerCase(),
      celda: (p) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          esPromocionDestacada(p.id)
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF08A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFA16207),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            p.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF713F12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : TablaApp.texto(p.nombre, fuerte: true),
          if ((p.descripcion ?? '').isNotEmpty)
            Text(
              p.descripcion!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
        ],
      ),
    ),
    ColumnaTabla(
      titulo: 'Incluye',
      flex: 1.4,
      anchoMin: 150,
      celda: (p) {
        if (p.id == idCumpleanos) return TablaApp.texto('A elección');
        final n = componentesDe(p.id).length;
        return TablaApp.texto(
          n == 0 ? 'Sin componentes' : '$n componente${n == 1 ? '' : 's'}',
        );
      },
    ),
    ColumnaTabla(
      titulo: 'Descuento',
      anchoMin: 100,
      rol: RolTarjeta.dato,
      ordenarPor: (p) => p.porcentajeDescuento ?? 0,
      celda: (p) => TablaApp.texto(
        p.porcentajeDescuento == null
            ? '—'
            : '${p.porcentajeDescuento!.toStringAsFixed(p.porcentajeDescuento! % 1 == 0 ? 0 : 1)} %',
      ),
    ),
    ColumnaTabla(
      titulo: 'Vigencia',
      flex: 1.3,
      anchoMin: 150,
      celda: (p) => TablaApp.texto(
        p.fechaInicio == null && p.fechaFin == null
            ? 'Siempre vigente'
            : '${p.fechaInicio != null ? _fecha(p.fechaInicio!) : '…'} – '
                  '${p.fechaFin != null ? _fecha(p.fechaFin!) : '…'}',
      ),
    ),
    ColumnaTabla(
      titulo: 'Estado',
      flex: 1.3,
      anchoMin: 150,
      rol: RolTarjeta.estado,
      celda: (p) => Align(
        alignment: Alignment.centerLeft,
        child: p.id == idCumpleanos
            ? _chip('Disponible en el registro', AppColors.primaryGreenDark)
            : _estadoChip(p),
      ),
    ),
    ColumnaTabla(
      titulo: 'Acciones',
      ancho: 110,
      rol: RolTarjeta.acciones,
      celda: (p) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Editar',
            visualDensity: VisualDensity.compact,
            onPressed: () => p.id == idCumpleanos
                ? _editarCumpleanos()
                : _editarPromocion(p),
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
          IconButton(
            tooltip: 'Eliminar',
            visualDensity: VisualDensity.compact,
            onPressed: () => p.id == idCumpleanos
                ? _eliminarCumpleanos()
                : _eliminarPromocion(p),
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    ),
  ];

  Widget _chip(String texto, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      texto,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );

  Widget _estadoChip(Promocion p) {
    if (!p.estado) return _chip('Inactiva', Colors.grey.shade600);
    if (!p.vigente) return _chip('Fuera de vigencia', AppColors.warning);
    if (!promocionLista(p)) {
      return _chip('Incompleta · no la ve el mozo', AppColors.error);
    }
    return _chip('Disponible', AppColors.primaryGreenDark);
  }
}

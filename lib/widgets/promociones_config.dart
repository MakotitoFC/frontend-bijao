import 'package:flutter/material.dart';

import 'dialogo_app.dart';

import '../data/promociones_store.dart';
import '../data/subcategorias_store.dart';
import '../models/promocion.dart';
import '../models/promocion_componente.dart';
import '../services/api_client.dart';
import '../services/promocion_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'app_toast.dart';
import 'menu_flotante.dart';
import 'promocion_dialogs.dart';
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
    PromocionService.instance.cargar().then((_) {
      if (mounted) setState(() {});
    });
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

  Future<void> _editarPromocion(Promocion p) async {
    final r = await showBlurDialog<Promocion>(
      context: context,
      builder: (_) => PromocionFormDialog(promocion: p),
    );
    if (r == null || !mounted) return;
    await _ejecutar(
      () => PromocionService.instance.actualizarPromocionEnServidor(r),
      exito: 'Promoción "${r.nombre}" actualizada.',
    );
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

  Future<void> _agregarComponente(Promocion p) async {
    final c = await showBlurDialog<PromocionComponente>(
      context: context,
      builder: (_) => ComponenteFormDialog(promocionId: p.id),
    );
    if (c == null || !mounted) return;
    await _ejecutar(
      () => PromocionService.instance.crearComponente(c),
      exito: 'Componente agregado a "${p.nombre}".',
    );
  }

  Future<void> _editarComponente(Promocion p, PromocionComponente c) async {
    final r = await showBlurDialog<PromocionComponente>(
      context: context,
      builder: (_) => ComponenteFormDialog(promocionId: p.id, componente: c),
    );
    if (r == null || !mounted) return;
    await _ejecutar(
      () => PromocionService.instance.actualizarComponenteEnServidor(r),
      exito: 'Componente actualizado.',
    );
  }

  Future<void> _eliminarComponente(PromocionComponente c) async {
    if (!await _confirmar(
      'Eliminar componente',
      '¿Eliminar "${nombreDeSubcategoria(c.subcategoriaId)}" y sus opciones?',
    )) {
      return;
    }
    await _ejecutar(
      () => PromocionService.instance.eliminarComponenteEnServidor(c.id),
      exito: 'Componente eliminado.',
    );
  }

  Future<void> _agregarOpcion(Promocion p, PromocionComponente c) async {
    final o = await showBlurDialog<PromocionOpcion>(
      context: context,
      builder: (_) => OpcionFormDialog(promocion: p, componente: c),
    );
    if (o == null || !mounted) return;
    await _ejecutar(
      () => PromocionService.instance.crearOpcion(o),
      exito: 'Opción agregada.',
    );
  }

  Future<void> _editarOpcion(
    Promocion p,
    PromocionComponente c,
    PromocionOpcion o,
  ) async {
    final r = await showBlurDialog<PromocionOpcion>(
      context: context,
      builder: (_) => OpcionFormDialog(promocion: p, componente: c, opcion: o),
    );
    if (r == null || !mounted) return;
    await _ejecutar(
      () => PromocionService.instance.actualizarOpcionEnServidor(r),
      exito: 'Opción actualizada.',
    );
  }

  // ---------- UI ----------

  static const _paleta = [
    Color(0xFF16A34A),
    Color(0xFFD99A06),
    Color(0xFF7C3AED),
    Color(0xFFE5484D),
    Color(0xFF2563EB),
    Color(0xFFF07F13),
  ];

  Color _colorDe(Promocion p) =>
      _paleta[p.nombre.codeUnits.fold<int>(0, (s, u) => s + u) %
          _paleta.length];

  bool _disponible(Promocion p) => p.vigente && promocionLista(p);

  @override
  Widget build(BuildContext context) {
    final disponibles = [
      for (final p in promociones)
        if (_disponible(p)) p,
    ];
    final otras = [
      for (final p in promociones)
        if (!_disponible(p)) p,
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppBreakpoints.esMobile(context) ? 16 : 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cabecera(),
              const SizedBox(height: 18),
              if (promociones.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Text(
                      'Aún no hay promociones registradas',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                ),
              if (disponibles.isNotEmpty) ...[
                _tituloSeccion('Disponibles', disponibles.length),
                _cuadricula(disponibles),
                const SizedBox(height: 22),
              ],
              if (otras.isNotEmpty) ...[
                _tituloSeccion(
                  'Inactivas, vencidas o incompletas',
                  otras.length,
                ),
                _cuadricula(otras),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cabecera() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.navbar,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.local_offer_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'PROMOCIONES',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'El mozo vende cada promoción tal como la configuras. Solo '
                  'puede cambiar un producto por otra opción que registres '
                  'aquí, y solo si el cliente lo pide.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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
    );
  }

  Widget _tituloSeccion(String titulo, int cantidad) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            titulo.toUpperCase(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$cantidad',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cuadricula(List<Promocion> lista) {
    return LayoutBuilder(
      builder: (context, c) {
        const espacio = 16.0;
        final columnas = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
        final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final p in lista)
              SizedBox(width: ancho, child: _tarjetaPromo(p)),
          ],
        );
      },
    );
  }

  // Tarjeta de una promoción: franja de color con el valor, lo que incluye y
  // los botones para ver el detalle o editar.
  Widget _tarjetaPromo(Promocion p) {
    final color = _colorDe(p);
    final componentes = componentesDe(p.id);
    String vigencia = '';
    if (p.fechaInicio != null || p.fechaFin != null) {
      vigencia =
          '${p.fechaInicio != null ? _fecha(p.fechaInicio!) : '…'} – '
          '${p.fechaFin != null ? _fecha(p.fechaFin!) : '…'}';
    }
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    p.etiqueta,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(Icons.local_offer, color: Colors.white54, size: 30),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  p.nombre.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if ((p.descripcion ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    p.descripcion!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
                const SizedBox(height: 8),
                if (componentes.isEmpty)
                  Text(
                    'Sin componentes todavía',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  )
                else
                  for (final comp in componentes)
                    Text(
                      '• ${comp.cantidad} × ${nombreDeSubcategoria(comp.subcategoriaId)}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _estadoChip(p),
                    if (vigencia.isNotEmpty)
                      Text(
                        vigencia,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _abrirDetalle(p),
                        child: const Text('Detalle'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _editarPromocion(p),
                        style: FilledButton.styleFrom(backgroundColor: color),
                        child: const Text('Editar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Detalle de la promoción en un modal: componentes y productos (agregar,
  // cambiar, activar, eliminar).
  Future<void> _abrirDetalle(Promocion inicial) async {
    _detalleId = inicial.id;
    await showBlurDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogo) {
          _refrescarDetalle = () => setDialogo(() {});
          final actual =
              promociones.where((x) => x.id == inicial.id).firstOrNull ??
              inicial;
          final alto = MediaQuery.sizeOf(context).height * 0.9;
          return Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppBreakpoints.esMobile(context)
                    ? MediaQuery.sizeOf(context).width
                    : 620,
                maxHeight: alto,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.sheet),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: _tarjeta(actual),
                ),
              ),
            ),
          );
        },
      ),
    );
    _refrescarDetalle = null;
    _detalleId = null;
  }

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

  Widget _tarjeta(Promocion p) {
    final componentes = componentesDe(p.id);
    String vigencia = '';
    if (p.fechaInicio != null || p.fechaFin != null) {
      vigencia =
          '${p.fechaInicio != null ? _fecha(p.fechaInicio!) : '…'} – '
          '${p.fechaFin != null ? _fecha(p.fechaFin!) : '…'}';
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _chip(p.etiqueta, AppColors.naranja),
                            _estadoChip(p),
                            if (vigencia.isNotEmpty)
                              Text(
                                vigencia,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar promoción',
                    onPressed: () => _editarPromocion(p),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Eliminar promoción',
                    onPressed: () => _eliminarPromocion(p),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(height: 1, color: Colors.grey.shade200),
                  if (p.descripcion != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        p.descripcion!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      p.seMantiene
                          ? 'Al hacer un cambio se mantiene el precio de promoción.'
                          : 'Al hacer un cambio, el producto nuevo se cobra a su precio normal.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (componentes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Agrega los componentes del combo (ej. 1 Segundo, 1 Bebida).',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  for (final c in componentes) ...[
                    _bloqueComponente(p, c),
                    const SizedBox(height: 10),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _agregarComponente(p),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Componente'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bloqueComponente(Promocion p, PromocionComponente c) {
    final opciones = opcionesDe(c.id);
    final incluida = opcionIncluida(c.id);
    final activas = opciones.where((o) => o.estado).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${c.cantidad} × ${nombreDeSubcategoria(c.subcategoriaId)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Editar componente',
                visualDensity: VisualDensity.compact,
                onPressed: () => _editarComponente(p, c),
                icon: const Icon(Icons.edit_outlined, size: 17),
              ),
              IconButton(
                tooltip: 'Eliminar componente',
                visualDensity: VisualDensity.compact,
                onPressed: () => _eliminarComponente(c),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 17,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          if (opciones.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Sin opciones: agrega al menos un producto.',
                style: TextStyle(fontSize: 12, color: AppColors.error),
              ),
            )
          else ...[
            for (final o in opciones)
              _filaOpcion(p, c, o, o.id == incluida?.id),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 6, 4),
              child: Text(
                activas > 1
                    ? 'El mozo puede cambiar entre ${activas > 2 ? 'estas $activas opciones' : 'estas 2 opciones'} si el cliente lo pide.'
                    : 'Con una sola opción activa no hay cambios posibles.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _agregarOpcion(p, c),
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Opción'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaOpcion(
    Promocion p,
    PromocionComponente c,
    PromocionOpcion o,
    bool incluida,
  ) {
    final normal = precioNormalDeOpcion(o);
    final promo = precioPromocionalDeOpcion(p, o);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Opacity(
              opacity: o.estado ? 1 : 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        nombreDeOpcion(o),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (incluida)
                        _chip('Incluido', AppColors.primaryGreenDark),
                      if (!o.estado) _chip('Inactiva', Colors.grey.shade600),
                    ],
                  ),
                  Text(
                    'Normal S/ ${normal.toStringAsFixed(2)} · Promoción S/ ${promo.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          MenuFlotante<String>(
            tooltip: 'Acciones',
            anchoMinimo: 170,
            opciones: [
              const OpcionMenu(valor: 'editar', etiqueta: 'Editar'),
              if (!incluida && o.estado)
                const OpcionMenu(valor: 'incluida', etiqueta: 'Hacer incluida'),
              OpcionMenu(
                valor: 'estado',
                etiqueta: o.estado ? 'Desactivar' : 'Activar',
              ),
              const OpcionMenu(valor: 'eliminar', etiqueta: 'Eliminar'),
            ],
            onSeleccionar: (v) {
              switch (v) {
                case 'editar':
                  _editarOpcion(p, c, o);
                case 'incluida':
                  _ejecutar(
                    () => PromocionService.instance.hacerIncluidaEnServidor(o),
                    exito: 'La opción ahora es la incluida.',
                  );
                case 'estado':
                  _ejecutar(
                    () => PromocionService.instance.actualizarOpcionEnServidor(
                      o.copyWith(estado: !o.estado),
                    ),
                    exito: o.estado
                        ? 'Opción desactivada.'
                        : 'Opción activada.',
                  );
                case 'eliminar':
                  _ejecutar(
                    () => PromocionService.instance.eliminarOpcionEnServidor(o),
                    exito: 'Opción eliminada.',
                  );
              }
            },
            disparador: (context, abierto) => const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.more_vert, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

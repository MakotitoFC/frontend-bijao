import 'package:flutter/material.dart';

import '../data/promociones_store.dart';
import '../data/subcategorias_store.dart';
import '../models/promocion.dart';
import '../models/promocion_componente.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'promocion_dialogs.dart';

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
  final Set<String> _colapsadas = {};

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<bool> _confirmar(String titulo, String texto) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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

  Future<void> _nuevaPromocion() async {
    final p = await showBlurDialog<Promocion>(
      context: context,
      builder: (_) => const PromocionFormDialog(),
    );
    if (p == null || !mounted) return;
    setState(() => agregarPromocion(p));
  }

  Future<void> _editarPromocion(Promocion p) async {
    final r = await showBlurDialog<Promocion>(
      context: context,
      builder: (_) => PromocionFormDialog(promocion: p),
    );
    if (r == null || !mounted) return;
    setState(() => actualizarPromocion(r));
  }

  Future<void> _eliminarPromocion(Promocion p) async {
    if (!await _confirmar(
      'Eliminar promoción',
      '¿Eliminar "${p.nombre}" con todos sus componentes y opciones?',
    )) {
      return;
    }
    setState(() => eliminarPromocion(p.id));
  }

  Future<void> _agregarComponente(Promocion p) async {
    final c = await showBlurDialog<PromocionComponente>(
      context: context,
      builder: (_) => ComponenteFormDialog(promocionId: p.id),
    );
    if (c == null || !mounted) return;
    setState(() => agregarComponente(c));
  }

  Future<void> _editarComponente(Promocion p, PromocionComponente c) async {
    final r = await showBlurDialog<PromocionComponente>(
      context: context,
      builder: (_) => ComponenteFormDialog(promocionId: p.id, componente: c),
    );
    if (r == null || !mounted) return;
    setState(() => actualizarComponente(r));
  }

  Future<void> _eliminarComponente(PromocionComponente c) async {
    if (!await _confirmar(
      'Eliminar componente',
      '¿Eliminar "${nombreDeSubcategoria(c.subcategoriaId)}" y sus opciones?',
    )) {
      return;
    }
    setState(() => eliminarComponente(c.id));
  }

  Future<void> _agregarOpcion(Promocion p, PromocionComponente c) async {
    final o = await showBlurDialog<PromocionOpcion>(
      context: context,
      builder: (_) => OpcionFormDialog(promocion: p, componente: c),
    );
    if (o == null || !mounted) return;
    setState(() => agregarOpcion(o));
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
    setState(() => actualizarOpcion(r));
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Promociones',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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
                'El mozo vende cada promoción tal como la configuras. Solo puede '
                'cambiar un producto por otra opción que registres aquí, y solo '
                'si el cliente lo pide.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),
              if (promociones.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Text(
                      'Aún no hay promociones registradas',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                )
              else
                for (final p in promociones) ...[
                  _tarjeta(p),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
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
    final expandida = !_colapsadas.contains(p.id);
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
            onTap: () => setState(() {
              if (!_colapsadas.remove(p.id)) _colapsadas.add(p.id);
            }),
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
                            _chip(p.etiqueta, AppColors.platoDelDia),
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
                  AnimatedRotation(
                    turns: expandida ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey.shade600,
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
            child: !expandida
                ? const SizedBox(width: double.infinity)
                : Padding(
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
            for (final o in opciones) _filaOpcion(p, c, o, o.id == incluida?.id),
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
          PopupMenuButton<String>(
            tooltip: 'Acciones',
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (v) {
              switch (v) {
                case 'editar':
                  _editarOpcion(p, c, o);
                case 'incluida':
                  setState(() => hacerIncluida(o.id));
                case 'estado':
                  setState(() => actualizarOpcion(o.copyWith(estado: !o.estado)));
                case 'eliminar':
                  setState(() => eliminarOpcion(o.id));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'editar', child: Text('Editar')),
              if (!incluida && o.estado)
                const PopupMenuItem(
                  value: 'incluida',
                  child: Text('Hacer incluida'),
                ),
              PopupMenuItem(
                value: 'estado',
                child: Text(o.estado ? 'Desactivar' : 'Activar'),
              ),
              const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
    );
  }
}

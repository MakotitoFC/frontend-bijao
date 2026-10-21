import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../services/pedido_mozo_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/blur_dialog.dart';
import '../app_search_field.dart';
import '../app_tag.dart';
import '../dialogo_app.dart';
import '../tabs_desplazables.dart';

class PaginaAnulaciones extends StatefulWidget {
  const PaginaAnulaciones({super.key});

  @override
  State<PaginaAnulaciones> createState() => _PaginaAnulacionesState();
}

class _PaginaAnulacionesState extends State<PaginaAnulaciones> {
  String _busqueda = '';
  String _filtro = 'todas'; // todas, servido, no_servido
  bool _cargando = false;
  List<Map<String, dynamic>> _anulaciones = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final list = await PedidoMozoService.instance.obtenerAnulaciones();
      if (mounted) {
        setState(() {
          _anulaciones = list;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _verEvidencia(String url) {
    showBlurDialog(
      context: context,
      builder: (ctx) => DialogoApp(
        titulo: 'Evidencia de anulación',
        ancho: 500,
        acciones: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No se pudo cargar la imagen de evidencia'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fecha(dynamic f) {
    if (f == null) return '—';
    DateTime? d;
    if (f is DateTime) {
      d = f;
    } else {
      d = DateTime.tryParse(f.toString());
    }
    if (d == null) return f.toString();
    final local = d.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _limpiarComentario(String raw) {
    var c = raw;
    if (c.contains('[SERVIDO: SI]')) c = c.replaceAll('[SERVIDO: SI]', '');
    if (c.contains('[SERVIDO: NO]')) c = c.replaceAll('[SERVIDO: NO]', '');
    if (c.contains('[POR: ')) {
      final idx = c.indexOf('[POR: ');
      final endIdx = c.indexOf(']', idx);
      if (endIdx != -1) {
        c = c.substring(0, idx) + c.substring(endIdx + 1);
      }
    }
    return c.trim();
  }

  @override
  Widget build(BuildContext context) {
    final query = _busqueda.toLowerCase().trim();
    final filtradas = _anulaciones.where((a) {
      final servido = a['fue_servido'] == true;
      if (_filtro == 'servido' && !servido) return false;
      if (_filtro == 'no_servido' && servido) return false;

      if (query.isNotEmpty) {
        final plato = (a['plato_nombre'] ?? '').toString().toLowerCase();
        final usuario = (a['usuario_nombre'] ?? '').toString().toLowerCase();
        final comentario = (a['comentario'] ?? '').toString().toLowerCase();
        final tipo = (a['tipo_pedido'] ?? '').toString().toLowerCase();
        final mesa = (a['mesa_numero'] ?? '').toString();
        return plato.contains(query) ||
            usuario.contains(query) ||
            comentario.contains(query) ||
            tipo.contains(query) ||
            mesa.contains(query);
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AppSearchField(
                hint: 'Buscar plato, mozo, mesa o motivo...',
                ajustarAlTexto: false,
                onChanged: (v) => setState(() => _busqueda = v),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: 'Actualizar lista',
              onPressed: _cargar,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TabsDesplazables(
          child: Row(
            children: [
              AppTag(
                etiqueta: 'Todas (${_anulaciones.length})',
                activo: _filtro == 'todas',
                onTap: () => setState(() => _filtro = 'todas'),
              ),
              AppTag(
                etiqueta:
                    'Servidas (${_anulaciones.where((a) => a['fue_servido'] == true).length})',
                activo: _filtro == 'servido',
                color: AppColors.naranja,
                onTap: () => setState(() => _filtro = 'servido'),
              ),
              AppTag(
                etiqueta:
                    'No servidas (${_anulaciones.where((a) => a['fue_servido'] != true).length})',
                activo: _filtro == 'no_servido',
                color: AppColors.primaryGreen,
                onTap: () => setState(() => _filtro = 'no_servido'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filtradas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                children: [
                  Icon(LucideIcons.ban, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text(
                    _busqueda.isNotEmpty || _filtro != 'todas'
                        ? 'No se encontraron anulaciones con los filtros aplicados'
                        : 'No se registran anulaciones de pedidos o platos',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 58,
                columnSpacing: 24,
                horizontalMargin: 16,
                columns: const [
                  DataColumn(label: Text('Fecha y hora', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Plato / Ítem', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Cant.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Pedido / Origen', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Anulado por', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('¿Fue servido?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Motivo / Comentario', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Evidencia', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                ],
                rows: [
                  for (final a in filtradas)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            _fecha(a['fecha']),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                a['pedido_detalle_id'] == null
                                    ? LucideIcons.receiptText
                                    : LucideIcons.utensils,
                                size: 16,
                                color: AppColors.naranja,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                (a['plato_nombre'] ?? 'Pedido Completo').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${a['cantidad'] ?? 1}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (a['mesa_numero'] != null && a['mesa_numero'] > 0)
                                    ? 'Mesa ${a['mesa_numero']}'
                                    : (a['tipo_pedido'] ?? 'Pedido').toString().toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                              Text(
                                '${a['tipo_pedido'] ?? 'normal'}',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.user, size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                (a['usuario_nombre'] ?? '—').toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          a['fue_servido'] == true
                              ? const AppTag(
                                  etiqueta: 'Servido (Consumido)',
                                  activo: false,
                                  color: AppColors.naranja,
                                )
                              : const AppTag(
                                  etiqueta: 'No servido (Retornado)',
                                  activo: false,
                                  color: AppColors.primaryGreen,
                                ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240),
                            child: Tooltip(
                              message: (a['comentario'] ?? '').toString(),
                              child: Text(
                                _limpiarComentario((a['comentario'] ?? '').toString()),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          (a['url_evidencia'] != null &&
                                  (a['url_evidencia'] as String).isNotEmpty)
                              ? IconButton(
                                  tooltip: 'Ver foto de evidencia',
                                  icon: const Icon(LucideIcons.image, size: 18, color: AppColors.primaryGreen),
                                  onPressed: () => _verEvidencia(a['url_evidencia'] as String),
                                )
                              : Text(
                                  'Sin foto',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                                ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

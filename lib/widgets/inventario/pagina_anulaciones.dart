import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../services/pedido_mozo_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/blur_dialog.dart';
import '../app_search_field.dart';
import '../app_tag.dart';
import '../dialogo_app.dart';
import '../tabla_app.dart';
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

    // Mismo margen lateral que las demás páginas de Inventario. Sin ancho
    // máximo: la tabla necesita todo el espacio disponible.
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppBreakpoints.esMobile(context) ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // El buscador termina en la columna "Cant." de la tabla (Fecha 150 +
          // Plato + Cant. 80); no se estira hasta el borde.
          LayoutBuilder(
            builder: (context, c) {
              const fijas = 150.0 + 80 + 190 + 100; // columnas de ancho fijo
              const minimo = 1150.0; // ancho mínimo de la tabla
              final ancho = c.maxWidth >= minimo
                  ? 150 + 80 + (c.maxWidth - fijas) * 14 / 50
                  : 150 + 80 + 170.0;
              return Row(
                children: [
                  SizedBox(
                    width: ancho.clamp(260.0, c.maxWidth - 56),
                    child: AppSearchField(
                      hint: 'Buscar plato, mozo, mesa o motivo...',
                      ajustarAlTexto: false,
                      onChanged: (v) => setState(() => _busqueda = v),
                    ),
                  ),
                ],
              );
            },
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
                    Icon(
                      LucideIcons.ban,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _busqueda.isNotEmpty || _filtro != 'todas'
                          ? 'No se encontraron anulaciones con los filtros aplicados'
                          : 'No se registran anulaciones de pedidos o platos',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            TablaApp<Map<String, dynamic>>(
              porPagina: 10,
              filas: filtradas,
              altoFila: 62,
              columnas: [
                ColumnaTabla(
                  titulo: 'Fecha y hora',
                  ancho: 150,
                  ordenarPor: (a) => _fecha(a['fecha']),
                  celda: (a) => TablaApp.texto(_fecha(a['fecha'])),
                ),
                ColumnaTabla(
                  titulo: 'Plato / Ítem',
                  rol: RolTarjeta.titulo,
                  flex: 1.4,
                  anchoMin: 170,
                  ordenarPor: (a) =>
                      (a['plato_nombre'] ?? 'Pedido Completo').toString(),
                  celda: (a) => Row(
                    children: [
                      Icon(
                        a['pedido_detalle_id'] == null
                            ? LucideIcons.receiptText
                            : LucideIcons.utensils,
                        size: 16,
                        color: AppColors.naranja,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: TablaApp.texto(
                          (a['plato_nombre'] ?? 'Pedido Completo').toString(),
                          fuerte: true,
                        ),
                      ),
                    ],
                  ),
                ),
                ColumnaTabla(
                  titulo: 'Cant.',
                  ancho: 80,
                  ordenarPor: (a) => (a['cantidad'] ?? 1) as num,
                  celda: (a) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${a['cantidad'] ?? 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                ColumnaTabla(
                  titulo: 'Pedido / Origen',
                  anchoMin: 130,
                  celda: (a) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TablaApp.texto(
                        (a['mesa_numero'] != null && a['mesa_numero'] > 0)
                            ? 'Mesa ${a['mesa_numero']}'
                            : (a['tipo_pedido'] ?? 'Pedido')
                                  .toString()
                                  .toUpperCase(),
                        fuerte: true,
                      ),
                      Text(
                        '${a['tipo_pedido'] ?? 'normal'}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                ColumnaTabla(
                  titulo: 'Anulado por',
                  anchoMin: 130,
                  ordenarPor: (a) => (a['usuario_nombre'] ?? '—').toString(),
                  celda: (a) => Row(
                    children: [
                      const Icon(
                        LucideIcons.user,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: TablaApp.texto(
                          (a['usuario_nombre'] ?? '—').toString(),
                        ),
                      ),
                    ],
                  ),
                ),
                ColumnaTabla(
                  titulo: '¿Fue servido?',
                  rol: RolTarjeta.estado,
                  ancho: 190,
                  ordenarPor: (a) => a['fue_servido'] == true ? 1 : 0,
                  celda: (a) => a['fue_servido'] == true
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
                ColumnaTabla(
                  titulo: 'Motivo / Comentario',
                  flex: 1.6,
                  anchoMin: 200,
                  celda: (a) => Tooltip(
                    message: (a['comentario'] ?? '').toString(),
                    child: Text(
                      _limpiarComentario((a['comentario'] ?? '').toString()),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TablaApp.estiloTexto.copyWith(fontSize: 12.5),
                    ),
                  ),
                ),
                ColumnaTabla(
                  titulo: 'Evidencia',
                  ancho: 100,
                  celda: (a) =>
                      (a['url_evidencia'] != null &&
                          (a['url_evidencia'] as String).isNotEmpty)
                      ? IconButton(
                          tooltip: 'Ver foto de evidencia',
                          icon: const Icon(
                            LucideIcons.image,
                            size: 18,
                            color: AppColors.primaryGreen,
                          ),
                          onPressed: () =>
                              _verEvidencia(a['url_evidencia'] as String),
                        )
                      : Text(
                          'Sin foto',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../services/pedido_mozo_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/blur_dialog.dart';
import '../app_search_field.dart';
import '../dialogo_app.dart';
import 'inventario_comun.dart';
import '../tabs_texto.dart';

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

    final hayFiltros = _busqueda.isNotEmpty || _filtro != 'todas';
    return PaginaListaFija(
      reiniciarCon: '$_busqueda|$_filtro',
      cabecera: const CabeceraSeccion(
        titulo: 'Anulaciones',
        descripcion:
            'Platos y pedidos anulados. Solo consulta: no cambia el stock.',
      ),
      barra: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AppSearchField(
              hint: 'Buscar...',
              onChanged: (v) => setState(() => _busqueda = v),
            ),
          ),
          const SizedBox(height: 12),
          TabsTexto(
            tabs: [
              TabTexto(
                etiqueta: 'Todas',
                cantidad: _anulaciones.length,
                activa: _filtro == 'todas',
                onTap: () => setState(() => _filtro = 'todas'),
              ),
              TabTexto(
                etiqueta: 'Servidas',
                cantidad: _anulaciones
                    .where((a) => a['fue_servido'] == true)
                    .length,
                activa: _filtro == 'servido',
                onTap: () => setState(() => _filtro = 'servido'),
              ),
              TabTexto(
                etiqueta: 'No servidas',
                cantidad: _anulaciones
                    .where((a) => a['fue_servido'] != true)
                    .length,
                activa: _filtro == 'no_servido',
                onTap: () => setState(() => _filtro = 'no_servido'),
              ),
            ],
          ),
        ],
      ),
      mensajeVacio: _cargando
          ? 'Cargando…'
          : (hayFiltros
                ? 'No se encontraron anulaciones con los filtros aplicados.'
                : 'No se registran anulaciones de pedidos o platos.'),
      filas: [for (final a in filtradas) _fila(a)],
    );
  }

  // Una anulación: plato y cantidad con su estado de servido, y debajo la
  // fecha, el origen, quién la anuló y el motivo.
  Widget _fila(Map<String, dynamic> a) {
    final servido = a['fue_servido'] == true;
    final mesa = a['mesa_numero'];
    final origen = (mesa is num && mesa > 0)
        ? 'Mesa ${mesa.toInt()}'
        : (a['tipo_pedido'] ?? 'Pedido').toString().toUpperCase();
    final motivo = _limpiarComentario((a['comentario'] ?? '').toString());
    final evidencia = (a['url_evidencia'] ?? '').toString();
    return FilaInventario(
      titulo: tituloConEtiquetas(
        '${a['cantidad'] ?? 1}x ${(a['plato_nombre'] ?? 'Pedido completo')}',
        [
          EtiquetaFila(
            servido ? 'Servido (consumido)' : 'No servido (retornado)',
            color: servido ? AppColors.naranja : AppColors.primaryGreen,
          ),
        ],
      ),
      detalle:
          '${_fecha(a['fecha'])} · $origen · '
          'Anulado por ${(a['usuario_nombre'] ?? '—')}'
          '${motivo.isEmpty ? '' : ' · $motivo'}',
      controles: [
        if (evidencia.isNotEmpty)
          IconButton(
            tooltip: 'Ver foto de evidencia',
            onPressed: () => _verEvidencia(evidencia),
            icon: const Icon(
              LucideIcons.image,
              size: 18,
              color: AppColors.primaryGreen,
            ),
          ),
      ],
    );
  }
}

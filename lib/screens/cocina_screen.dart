import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/incidencias_store.dart';
import '../data/inventario_store.dart';
import '../data/insumos_store.dart';
import '../data/pedidos_store.dart';
import '../data/usuarios_store.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/cronometro_pedido.dart';
import '../widgets/tabs_desplazables.dart';

// Vista de cocina: tabs por estado y una tarjeta por pedido
// (`pedidos` + `pedido_items`).
class CocinaScreen extends StatefulWidget {
  const CocinaScreen({super.key});

  @override
  State<CocinaScreen> createState() => _CocinaScreenState();
}

class _CocinaScreenState extends State<CocinaScreen> {
  // Estados de `pedidos.estado` que se pueden filtrar con los tabs.
  static const _estados = <(String, String)>[
    ('pendiente', 'Pendiente'),
    ('preparando', 'Preparando'),
    ('listo', 'Listo'),
    ('entregado', 'Entregado'),
    ('cancelado', 'Cancelado'),
    ('anulado', 'Anulado'),
  ];

  // null = Todos.
  String? _filtro;

  // Un pedido ya cobrado ('pagado') se considera entregado.
  String _estadoDe(Pedido p) => p.estado == 'pagado' ? 'entregado' : p.estado;

  bool _esActivo(String estado) =>
      estado == 'pendiente' || estado == 'preparando' || estado == 'listo';

  int _contar(String? estado) =>
      pedidos.where((p) => estado == null || _estadoDe(p) == estado).length;

  // Los activos primero (por orden de llegada) y después los ya cerrados.
  List<Pedido> get _visibles {
    final lista = pedidos
        .where((p) => _filtro == null || _estadoDe(p) == _filtro)
        .toList();
    lista.sort((a, b) {
      final aa = _esActivo(_estadoDe(a));
      final bb = _esActivo(_estadoDe(b));
      if (aa != bb) return aa ? -1 : 1;
      return a.fechaPedido.compareTo(b.fechaPedido);
    });
    return lista;
  }

  ({String texto, String siguiente})? _siguientePaso(String estado) {
    switch (estado) {
      case 'pendiente':
        return (texto: 'Iniciar', siguiente: 'preparando');
      case 'preparando':
        return (texto: 'Marcar listo', siguiente: 'listo');
      case 'listo':
        return (texto: 'Entregado', siguiente: 'entregado');
      default:
        return null;
    }
  }

  // Color del botón según el estado del pedido (`pedidos.estado`).
  Color _colorEstado(String estado) => switch (estado) {
    'preparando' => const Color(0xFFEF6C00),
    'listo' => const Color(0xFF1976D2),
    _ => AppColors.primaryGreen,
  };

  String _titulo(Pedido p) => p.tipoPedido == 'delivery'
      ? 'Delivery'
      : 'Mesa ${p.todasLasMesas.join(' + ')}';

  String _mesero(Pedido p) {
    for (final u in usuarios) {
      if (u.id == p.usuarioId) return u.nombre;
    }
    return '—';
  }

  String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // Insumos porcionados: la cantidad real se registra a mano al preparar.
  Future<void> _registrarInsumo(PedidoLine linea) async {
    final pendientes = insumosPendientesDe(linea);
    final controladores = {
      for (final r in pendientes) r.id: TextEditingController(),
    };
    final guardado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Insumo porcionado · ${linea.nombrePlato}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in pendientes)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: controladores[r.id],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _nombreProductoInventario(r.productoInventarioId),
                    hintText: 'Cantidad usada',
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (guardado != true || !mounted) return;
    setState(() {
      for (final r in pendientes) {
        final cantidad = double.tryParse(
          controladores[r.id]!.text.trim(),
        );
        if (cantidad != null && cantidad > 0) {
          registrarConsumoInsumo(linea, r, cantidad: cantidad);
        }
      }
    });
    showAppToast(
      context,
      'Consumo de insumo registrado para ${linea.nombrePlato}.',
      type: ToastType.success,
    );
  }

  String _nombreProductoInventario(String id) {
    for (final p in productosInventario) {
      if (p.id == id) return p.nombre;
    }
    return 'Insumo';
  }

  void _imprimir(Pedido p) {
    setState(() => marcarPedidoImpreso(p.id));
    showAppToast(
      context,
      'Comanda del pedido #${p.numeroPedido} enviada a imprimir.',
      type: ToastType.success,
      titulo: 'Comanda impresa',
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _visibles;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: TabsDesplazables(
              child: Row(
                children: [
                  _tab('Todos', _contar(null), _filtro == null, null),
                  for (final (valor, etiqueta) in _estados)
                    _tab(etiqueta, _contar(valor), _filtro == valor, valor),
                ],
              ),
            ),
          ),
          Expanded(
            child: visibles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.chefHat,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _filtro == null
                              ? 'Sin pedidos'
                              : 'Sin pedidos en este estado',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final p in visibles)
                          SizedBox(width: 264, child: _tarjeta(p)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String etiqueta, int cantidad, bool activo, String? valor) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => setState(() => _filtro = valor),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          decoration: Neon.etiqueta(activa: activo, radio: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.verdeTexto,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.verdeTexto,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$cantidad',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjeta(Pedido p) {
    final lineas = (detallesPorPedido[p.id] ?? [])
        .where((l) => l.cartaId != cartaIdCargoDelivery && l.cartaId != cartaIdAjuste)
        .toList();
    final paso = _siguientePaso(p.estado);
    final impreso = pedidosImpresos.contains(p.id);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _encabezado(p),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lineas.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: Colors.grey.shade300),
                  _producto(lineas[i]),
                ],
                if (lineas.isEmpty)
                  Text(
                    'Sin productos',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                if (p.clienteNombre != null ||
                    p.clienteCelular != null ||
                    p.direccionDelivery != null ||
                    p.notas != null) ...[
                  const SizedBox(height: 4),
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 10),
                  if (p.clienteNombre != null)
                    _dato(LucideIcons.user, p.clienteNombre!),
                  if (p.clienteCelular != null)
                    _dato(LucideIcons.phone, p.clienteCelular!),
                  if (p.direccionDelivery != null)
                    _dato(LucideIcons.mapPin, p.direccionDelivery!),
                  if (p.notas != null) _dato(LucideIcons.stickyNote, p.notas!),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Tooltip(
                  message: impreso ? 'Imprimir de nuevo' : 'Imprimir comanda',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _imprimir(p),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: impreso
                              ? AppColors.primaryGreen
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Icon(
                        LucideIcons.printer,
                        size: 18,
                        color: impreso
                            ? AppColors.primaryGreen
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (paso != null)
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed: () => setState(
                          () => actualizarEstadoPedido(p.id, paso.siguiente),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _colorEstado(p.estado),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          paso.texto,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Encabezado con mesa/delivery, número, mesero, estado y hora.
  Widget _encabezado(Pedido p) {
    final cerrado = p.estado == 'cancelado' || p.estado == 'anulado';
    return Container(
      color: cerrado ? const Color(0xFF6B7280) : AppColors.primaryGreen,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titulo(p),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '#${p.numeroPedido} · ${_mesero(p)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _badgeEstado(p.estado),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.clock,
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _hora(p.fechaPedido),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CronometroPedido(pedido: p, sobreVerde: true),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badgeEstado(String estado) {
    final (texto, tinta) = switch (estado) {
      'preparando' => ('Preparando', const Color(0xFFEF6C00)),
      'listo' => ('Listo', AppColors.primaryGreen),
      'entregado' || 'pagado' => ('Entregado', const Color(0xFF1976D2)),
      'cancelado' => ('Cancelado', const Color(0xFF6B7280)),
      'anulado' => ('Anulado', AppColors.error),
      _ => ('Pendiente', const Color(0xFFC2185B)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: tinta,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _producto(PedidoLine l) {
    final listo = lineasPreparadas.contains(l.id);
    final atenuado = listo ? Colors.grey.shade500 : Colors.black87;
    final incidencia = l.estado == 'incidencia' ? incidenciaDeLinea(l.id) : null;
    return InkWell(
      onTap: () => setState(() => alternarLineaPreparada(l.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l.nombrePlato,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: atenuado,
                        decoration: listo ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  if (incidencia != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE4EC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Incidencia: ${incidencia.etiquetaAccion}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFC2185B),
                        ),
                      ),
                    ),
                  ],
                  if (l.modificadores.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final m in l.modificadores)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: Neon.etiqueta(),
                            child: Text(
                              m.nombre,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: listo
                                    ? Colors.grey.shade500
                                    : AppColors.verdeTexto,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (l.comentario != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      l.comentario!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                  if (insumosPendientesDe(l).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _registrarInsumo(l),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Registrar insumo porcionado',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEF6C00),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'x${l.cantidad}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: listo ? Colors.grey.shade500 : AppColors.verdeTexto,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: listo,
                onChanged: (_) => setState(() => alternarLineaPreparada(l.id)),
                activeColor: AppColors.primaryGreen,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dato(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

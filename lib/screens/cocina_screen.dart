import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/cartas_store.dart';
import '../data/categorias_store.dart';
import '../data/incidencias_store.dart';
import '../data/inventario_store.dart';
import '../data/insumos_store.dart';
import '../data/pedidos_store.dart';
import '../data/usuarios_store.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import '../services/pedido_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_tag.dart';
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
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _cargar();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _cargar();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    await PedidoService.instance.cargarPedidos();
    if (mounted) setState(() {});
  }

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

  // Color del ticket según el estado: oscuro, naranja o verde.
  Color _colorEstado(String estado) => switch (estado) {
    'preparando' => AppColors.platoDelDia,
    'listo' || 'entregado' => AppColors.primaryGreen,
    _ => AppColors.navbar,
  };

  String _titulo(Pedido p) => switch (p.tipoPedido) {
    'delivery' => 'Delivery',
    _ => 'Mesa ${p.todasLasMesas.join(' + ')}',
  };

  String _mesero(Pedido p) {
    for (final u in usuarios) {
      if (u.id == p.usuarioId) return u.nombre;
    }
    return '—';
  }

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
                    labelText: _nombreProductoInventario(
                      r.productoInventarioId,
                    ),
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
        final cantidad = double.tryParse(controladores[r.id]!.text.trim());
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
                          SizedBox(width: 272, child: _tarjeta(p)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String etiqueta, int cantidad, bool activo, String? valor) {
    return AppTag(
      etiqueta: etiqueta,
      activo: activo,
      cantidad: cantidad,
      onTap: () => setState(() => _filtro = valor),
    );
  }

  // Ticket de cocina: cabecera de color según el estado, título del pedido,
  // productos por categoría y un botón que avanza el estado.
  Widget _tarjeta(Pedido p) {
    final estado = _estadoDe(p);
    final color = _colorEstado(estado);
    final lineas = (detallesPorPedido[p.id] ?? [])
        .where(
          (l) =>
              l.cartaId != cartaIdCargoDelivery && l.cartaId != cartaIdAjuste,
        )
        .toList();
    final grupos = <String, List<PedidoLine>>{};
    for (final l in lineas) {
      grupos.putIfAbsent(_categoriaDe(l), () => []).add(l);
    }
    final paso = _siguientePaso(estado);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radioTicket),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _encabezado(p, estado, color),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
            child: Text(
              _titulo(p).toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          if (lineas.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sin productos',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          for (final entrada in grupos.entries) ...[
            if (entrada.key.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Text(
                  entrada.key.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            for (final l in entrada.value) ...[
              Divider(height: 1, color: Colors.grey.shade300),
              _producto(l),
            ],
          ],
          if (p.clienteNombre != null ||
              p.clienteCelular != null ||
              p.direccionDelivery != null ||
              p.notas != null) ...[
            Divider(height: 1, color: Colors.grey.shade300),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.clienteNombre != null)
                    _dato(LucideIcons.user, p.clienteNombre!),
                  if (p.clienteCelular != null)
                    _dato(LucideIcons.phone, p.clienteCelular!),
                  if (p.direccionDelivery != null)
                    _dato(LucideIcons.mapPin, p.direccionDelivery!),
                  if (p.notas != null) _dato(LucideIcons.stickyNote, p.notas!),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(10),
            child: FilledButton(
              onPressed: paso == null
                  ? null
                  : () => setState(
                      () => actualizarEstadoPedido(p.id, paso.siguiente),
                    ),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.white,
              ),
              child: Text(
                (paso?.texto ?? _etiquetaEstado(estado)).toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const double _radioTicket = 8;

  // Categoría del producto de la línea ('' si no se conoce).
  String _categoriaDe(PedidoLine l) {
    final item = cartasNotifier.value
        .where((c) => c.id == l.cartaId)
        .firstOrNull;
    if (item == null) return '';
    final cat = categorias.where((c) => c.id == item.categoriaId).firstOrNull;
    return cat?.categoria ?? '';
  }

  String _etiquetaEstado(String estado) => switch (estado) {
    'pendiente' => 'Pendiente',
    'preparando' => 'Preparando',
    'listo' => 'Listo',
    'entregado' => 'Entregado',
    'cancelado' => 'Cancelado',
    'anulado' => 'Anulado',
    _ => estado,
  };

  String _horaCompleta(DateTime d) {
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(h12)}:${dos(d.minute)}:${dos(d.second)} '
        '${d.hour < 12 ? 'AM' : 'PM'}';
  }

  // Cabecera: número del pedido y estado a la izquierda; hora y mesero a la
  // derecha.
  Widget _encabezado(Pedido p, String estado, Color color) {
    const blanco = Colors.white;
    final suave = Colors.white.withValues(alpha: 0.85);
    return Container(
      color: color,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${p.numeroPedido}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: blanco,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _etiquetaEstado(estado),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: suave,
                        ),
                      ),
                      CronometroPedido(pedido: p, sobreVerde: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _horaCompleta(p.fechaPedido),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: blanco,
                ),
              ),
              Text(
                _mesero(p),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: suave),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Producto del ticket: cantidad y nombre; opciones y notas en rojo.
  Widget _producto(PedidoLine l) {
    final incidencia = l.estado == 'incidencia'
        ? incidenciaDeLinea(l.id)
        : null;
    const rojo = Color(0xFFE53935);
    const estiloRojo = TextStyle(fontSize: 12, color: rojo);
    final opciones = <String>[
      if (l.variante != null) l.variante!.nombre,
      for (final e in l.componentes)
        '${e.cantidad} × ${e.nombre}${e.esCambio ? ' (cambio)' : ''}',
      if (l.presentacion != null)
        '${l.presentacion!.unidad.unidadPresentacion} ${l.presentacion!.volumenMl}ml',
      ...l.modificadores.map((m) => m.nombre),
    ];
    return Container(
      color: incidencia != null ? const Color(0xFFFBE4E4) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '${l.cantidad}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.nombrePlato,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final o in opciones)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(o, style: estiloRojo),
                  ),
                if (l.comentario != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text.rich(
                      TextSpan(
                        style: estiloRojo,
                        children: [
                          const TextSpan(
                            text: 'NOTA : ',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(text: l.comentario),
                        ],
                      ),
                    ),
                  ),
                if (incidencia != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'INCIDENCIA : ${incidencia.etiquetaResolucion}',
                      style: estiloRojo.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                if (insumosPendientesDe(l).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
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
                  ),
              ],
            ),
          ),
        ],
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

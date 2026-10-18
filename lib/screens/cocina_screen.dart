import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/dialogo_app.dart';

import '../utils/blur_dialog.dart';

import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/cartas_store.dart';
import '../data/categorias_store.dart';
import '../data/incidencias_store.dart';
import '../data/inventario_store.dart';
import '../data/insumos_store.dart';
import '../data/pedidos_store.dart';
import '../data/usuarios_store.dart';
import '../models/pedido.dart';
import '../utils/nota_pedido.dart';
import '../models/pedido_line.dart';
import '../services/eventos_service.dart';
import '../services/pedido_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_tag.dart';
import '../widgets/app_toast.dart';
import '../widgets/cronometro_pedido.dart';
import '../widgets/tabs_desplazables.dart';
import '../widgets/campo_texto.dart';

// Vista de cocina: tabs por estado y una tarjeta por pedido
// (`pedidos` + `pedido_items`). Solo consulta: el backend no tiene estados de
// preparación; el pedido pasa a "servido" cuando lo marca el mozo.
class CocinaScreen extends StatefulWidget {
  const CocinaScreen({super.key});

  @override
  State<CocinaScreen> createState() => _CocinaScreenState();
}

class _CocinaScreenState extends State<CocinaScreen> {
  // Estados abiertos de `pedidos.estado` que se pueden filtrar con los tabs.
  static const _estados = <(String, String)>[
    ('pendiente', 'Pendiente'),
    ('servido', 'Servido'),
  ];

  // null = Todos.
  String? _filtro;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _cargar();
    EventosService.instance.revision.addListener(_alCambiarEnVivo);
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (EventosService.instance.conectado.value && ++_ciclos % 8 != 0) return;
      _cargar();
    });
  }

  int _ciclos = 0;

  void _alCambiarEnVivo() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    EventosService.instance.revision.removeListener(_alCambiarEnVivo);
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    await PedidoService.instance.cargarPedidos();
    if (mounted) setState(() {});
  }

  String _estadoDe(Pedido p) => p.estado == 'pedido' ? 'pendiente' : p.estado;

  bool _esActivo(String estado) => estado == 'pendiente';

  // Cocina solo ve los pedidos abiertos (pendientes y servidos sin cobrar).
  Iterable<Pedido> get _abiertos => pedidos.where((p) => p.abierto);

  int _contar(String? estado) =>
      _abiertos.where((p) => estado == null || _estadoDe(p) == estado).length;

  // Los pendientes primero (por orden de llegada) y después los servidos.
  List<Pedido> get _visibles {
    final lista = _abiertos
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

  // Color del ticket según el estado: oscuro (pendiente) o verde (servido).
  Color _colorEstado(String estado) => switch (estado) {
    'servido' => AppColors.primaryGreen,
    _ => AppColors.navbar,
  };

  String _titulo(Pedido p) => p.ubicacion;

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
    final guardado = await showBlurDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertaApp(
        title: Text('Insumo porcionado · ${linea.nombrePlato}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in pendientes)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CampoTexto(
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
          if (notaGeneralDe(p.notas) != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE53935)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFFE53935),
                  ),
                  children: [
                    const TextSpan(
                      text: 'NOTA DEL PEDIDO : ',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: notaGeneralDe(p.notas)),
                  ],
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
              (p.referenciaDelivery ?? '').isNotEmpty ||
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
                  if (p.referenciaDelivery != null &&
                      p.referenciaDelivery!.isNotEmpty)
                    _dato(LucideIcons.signpost, p.referenciaDelivery!),
                  if (p.notas != null) _dato(LucideIcons.stickyNote, p.notas!),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  static const double _radioTicket = 8;

  // Categoría del producto de la línea ('' si no se conoce).
  String _categoriaDe(PedidoLine l) {
    final item = cartaPorId(l.cartaId);
    if (item == null) return '';
    final cat = categorias.where((c) => c.id == item.categoriaId).firstOrNull;
    return cat?.categoria ?? '';
  }

  String _etiquetaEstado(String estado) => switch (estado) {
    'pendiente' => 'Pendiente',
    'servido' => 'Servido',
    'pagado' => 'Pagado',
    'anulado' => 'Anulado',
    'devuelto' => 'Devuelto',
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

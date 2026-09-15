import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../data/insumos_store.dart';
import '../data/mesas_store.dart';
import '../data/mock_cartas.dart';
import '../data/mock_categorias.dart';
import '../data/mock_medios_pago.dart';
import '../data/mock_presentaciones.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../models/carta_item.dart';
import '../models/categoria_comida.dart';
import '../models/medio_pago.dart';
import '../models/mesa.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import '../theme/app_theme.dart';
import '../utils/carta_visuals.dart';
import 'app_toast.dart';

// Panel de pedido de una mesa, embebido dentro de MesasScreen.
// Según el estado de la mesa muestra:
// - libre: armar un pedido nuevo (carta + carrito + confirmar).
// - ocupada: el pedido activo (items + resumen de pago + cobrar), con opción
//   de agregar más ítems al mismo pedido.
class PanelPedidoMesa extends StatefulWidget {
  final Mesa mesa;
  final VoidCallback onCerrar;
  final VoidCallback onCambio;

  const PanelPedidoMesa({
    super.key,
    required this.mesa,
    required this.onCerrar,
    required this.onCambio,
  });

  @override
  State<PanelPedidoMesa> createState() => _PanelPedidoMesaState();
}

class _PanelPedidoMesaState extends State<PanelPedidoMesa> {
  CategoriaComida? _categoriaSeleccionada;
  final List<PedidoLine> _carrito = [];
  bool _agregandoItems = false;
  String _tipoPedido = 'mesa'; // 'llevar' | 'mesa' | 'delivery'
  // Mobile: alterna entre ver la grilla de productos y ver el carrito/orden
  // (en vez de mostrarlos lado a lado como en escritorio).
  bool _mostrarCarritoMobile = false;

  final _busquedaProductoController = TextEditingController();
  String _busquedaProducto = '';
  final _nombreClienteController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _propinaController = TextEditingController(text: '0');
  final _descuentoController = TextEditingController(text: '0');

  // Cobro inline (sin modal aparte): medio de pago + monto + propina.
  MedioPago _medioPagoCobro = medioEfectivo;
  final _montoCobroController = TextEditingController();
  final _propinaCobroController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final pedido = _pedidoActivo;
    if (pedido != null) {
      _montoCobroController.text = saldoPendienteDePedido(pedido.id)
          .toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _busquedaProductoController.dispose();
    _nombreClienteController.dispose();
    _telefonoController.dispose();
    _propinaController.dispose();
    _descuentoController.dispose();
    _montoCobroController.dispose();
    _propinaCobroController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PanelPedidoMesa oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mesa.numero != widget.mesa.numero) {
      setState(() {
        _carrito.clear();
        _categoriaSeleccionada = null;
        _agregandoItems = false;
        _tipoPedido = 'mesa';
      });
    }
  }

  double get _totalCarrito =>
      _carrito.fold(0.0, (s, l) => s + l.precioTotalLinea);

  double get _propina => double.tryParse(_propinaController.text) ?? 0;

  double get _descuento => double.tryParse(_descuentoController.text) ?? 0;

  double get _totalConAjustes =>
      (_totalCarrito - _descuento + _propina).clamp(0, double.infinity);

  List<CartaItem> get _cartaFiltrada {
    final base = _categoriaSeleccionada == null
        ? mockCartas
        : mockCartas
              .where((c) => c.categoriaId == _categoriaSeleccionada!.id)
              .toList();
    final termino = _busquedaProducto.trim().toLowerCase();
    if (termino.isEmpty) return base;
    return base
        .where((c) => c.nombrePlato.toLowerCase().contains(termino))
        .toList();
  }

  List<List<dynamic>> _iconoCategoria(String categoriaId) =>
      iconoDeCategoria(categoriaId);

  int? get _parejaUnion => parejaDe(widget.mesa.numero);

  String get _tituloMesa {
    final pareja = _parejaUnion;
    return pareja == null
        ? 'Mesa ${widget.mesa.numero}'
        : 'Mesa ${widget.mesa.numero} + $pareja';
  }

  Pedido? get _pedidoActivo {
    for (final p in pedidos) {
      if (p.todasLasMesas.contains(widget.mesa.numero) &&
          p.estado != 'pagado') {
        return p;
      }
    }
    return null;
  }

  // Línea por defecto al agregar un producto con un solo toque: cantidad 1,
  // sin modificadores/taper/comentario, con la presentación más económica si
  // el ítem se vende por presentaciones (ej. bebidas).
  PedidoLine _lineaPorDefecto(CartaItem item) {
    final presentaciones = mockPresentaciones
        .where((p) => p.cartaId == item.id)
        .toList();
    final presentacion = presentaciones.isEmpty
        ? null
        : presentaciones.reduce(
            (a, b) => a.precioCliente < b.precioCliente ? a : b,
          );
    final precioUnitario =
        item.precioCliente ?? presentacion?.precioCliente ?? 0;
    return PedidoLine(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      cartaId: item.id,
      nombrePlato: item.nombrePlato,
      cantidad: 1,
      modificadores: const [],
      presentacion: presentacion,
      taper: null,
      promocion: null,
      comentario: null,
      precioUnitario: precioUnitario,
      descuentoAplicado: 0,
      precioTotalLinea: precioUnitario,
    );
  }

  PedidoLine _lineaConCantidad(PedidoLine linea, int cantidad) {
    return PedidoLine(
      id: linea.id,
      cartaId: linea.cartaId,
      nombrePlato: linea.nombrePlato,
      cantidad: cantidad,
      modificadores: linea.modificadores,
      presentacion: linea.presentacion,
      taper: linea.taper,
      promocion: linea.promocion,
      comentario: linea.comentario,
      precioUnitario: linea.precioUnitario,
      descuentoAplicado: linea.descuentoAplicado,
      precioTotalLinea:
          linea.precioUnitario * cantidad - linea.descuentoAplicado,
    );
  }

  bool _mismoProductoSinPersonalizar(PedidoLine linea, CartaItem item) =>
      linea.cartaId == item.id &&
      linea.modificadores.isEmpty &&
      linea.taper == null &&
      linea.comentario == null;

  // Un toque en "+" agrega 1 unidad directo al pedido (sin abrir un modal de
  // personalización): si ya hay una línea simple del mismo producto, suma la
  // cantidad; si no, crea una línea nueva.
  void _agregarItem(CartaItem item) {
    registrarConsumoAutomaticoDeLinea(_lineaPorDefecto(item));
    setState(() {
      final index = _carrito.indexWhere(
        (l) => _mismoProductoSinPersonalizar(l, item),
      );
      if (index != -1) {
        _carrito[index] = _lineaConCantidad(
          _carrito[index],
          _carrito[index].cantidad + 1,
        );
      } else {
        _carrito.add(_lineaPorDefecto(item));
      }
    });
  }

  void _agregarItemAPedidoExistente(CartaItem item, Pedido pedido) {
    registrarConsumoAutomaticoDeLinea(_lineaPorDefecto(item));
    final existentes = detallesPorPedido[pedido.id] ?? [];
    final index = existentes.indexWhere(
      (l) => _mismoProductoSinPersonalizar(l, item),
    );
    if (index != -1) {
      final actualizadas = List<PedidoLine>.from(existentes);
      actualizadas[index] = _lineaConCantidad(
        actualizadas[index],
        actualizadas[index].cantidad + 1,
      );
      detallesPorPedido[pedido.id] = actualizadas;
    } else {
      detallesPorPedido[pedido.id] = [...existentes, _lineaPorDefecto(item)];
    }
    widget.onCambio();
    setState(() {});
  }

  void _quitarLinea(int index) => setState(() => _carrito.removeAt(index));

  void _confirmarPedido() {
    final pareja = _parejaUnion;
    final pedido = Pedido(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      mesaNumero: widget.mesa.numero,
      mesasUnidas: pareja == null ? const [] : [pareja],
      tipoPedido: _tipoPedido,
      fechaPedido: DateTime.now(),
    );
    registrarPedido(pedido, List.of(_carrito));
    for (final linea in _carrito) {
      registrarConsumoAutomaticoDeLinea(linea);
    }
    for (final numero in pedido.todasLasMesas) {
      actualizarEstadoMesa(numero, 'ocupada');
    }
    final numItems = _carrito.length;
    setState(() {
      _carrito.clear();
      _propinaController.text = '0';
      _descuentoController.text = '0';
      _tipoPedido = 'mesa';
    });
    widget.onCambio();
    showAppToast(
      context,
      'Pedido confirmado para $_tituloMesa '
      '($numItems ítem(s)) · enviado a cocina',
      type: ToastType.success,
    );
    widget.onCerrar();
  }

  double get _montoCobro =>
      double.tryParse(_montoCobroController.text.trim()) ?? 0;

  double get _propinaCobro =>
      double.tryParse(_propinaCobroController.text.trim()) ?? 0;

  double get _comisionCobro => _medioPagoCobro.aplicaComision
      ? _montoCobro * (_medioPagoCobro.porcentajeComision / 100)
      : 0;

  void _confirmarCobro(Pedido pedido, double saldoPendiente) {
    if (_montoCobro <= 0 || _montoCobro > saldoPendiente + 0.01) {
      showAppToast(
        context,
        'El monto debe ser mayor a 0 y no superar el saldo pendiente',
        type: ToastType.error,
      );
      return;
    }
    final pago = registrarPago(
      pedido: pedido,
      medioPago: _medioPagoCobro,
      montoAbonado: _montoCobro,
      propina: _propinaCobro,
    );
    widget.onCambio();
    final restante = saldoPendienteDePedido(pedido.id);
    setState(() {
      _montoCobroController.text = restante.toStringAsFixed(2);
      _propinaCobroController.clear();
    });
    showAppToast(
      context,
      restante <= 0.01
          ? 'Cobro registrado · $_tituloMesa · S/ ${pago.montoAbonado.toStringAsFixed(2)}'
          : 'Pago parcial registrado · saldo restante S/ ${restante.toStringAsFixed(2)}',
      type: ToastType.success,
    );
    if (restante <= 0.01) widget.onCerrar();
  }

  String _descripcionLinea(PedidoLine linea) {
    final partes = <String>[
      if (linea.presentacion != null)
        '${linea.presentacion!.unidad.unidadPresentacion} ${linea.presentacion!.volumenMl}ml',
      ...linea.modificadores.map((m) => m.nombre),
      if (linea.taper != null) linea.taper!.nombre,
      if (linea.promocion != null) linea.promocion!.nombre,
    ];
    return partes.isEmpty ? (linea.comentario ?? '') : partes.join(' · ');
  }

  double _precioMinimoPresentacion(String cartaId) {
    final precios = mockPresentaciones
        .where((p) => p.cartaId == cartaId)
        .map((p) => p.precioCliente);
    if (precios.isEmpty) return 0;
    return precios.reduce((a, b) => a < b ? a : b);
  }

  String _hora(DateTime fecha) =>
      '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ocupada = widget.mesa.estado == 'ocupada';
    final catalogo = !ocupada || _agregandoItems;
    // El modal tiene el ancho de su contenido: partido en dos (detalle +
    // cobro) para ver un pedido existente, ancho para el catálogo (rail +
    // grilla + panel de orden). El cobro vive en el mismo modal, nunca en
    // uno aparte.
    final pedidoActivo = _pedidoActivo;
    final esMobile = AppBreakpoints.esMobile(context);

    late final Widget contenido;
    if (catalogo) {
      final onAgregar = ocupada
          ? (CartaItem item) =>
                _agregarItemAPedidoExistente(item, _pedidoActivo!)
          : _agregarItem;
      if (esMobile) {
        // Mobile: la grilla y el carrito/orden no van lado a lado (no caben);
        // se alternan, con una barra inferior para saltar al carrito.
        contenido = _mostrarCarritoMobile
            ? _panelOrden(
                ocupada: ocupada,
                esMobile: true,
                onVolverCatalogo: () =>
                    setState(() => _mostrarCarritoMobile = false),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _cabeceraOrden(ocupada),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  Expanded(
                    child: _panelCatalogo(
                      ocupada: ocupada,
                      esMobile: true,
                      onAgregar: onAgregar,
                    ),
                  ),
                  _barraVerCarrito(),
                ],
              );
      } else {
        contenido = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _panelCatalogo(ocupada: ocupada, onAgregar: onAgregar),
            ),
            _panelOrden(ocupada: ocupada),
          ],
        );
      }
    } else {
      contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _encabezado(ocupada),
          const Divider(height: 1),
          Expanded(
            child: pedidoActivo == null
                ? const Center(child: Text('Sin pedido activo para esta mesa'))
                : (esMobile
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _contenidoPedidoExistente(pedidoActivo),
                              const Divider(height: 32),
                              _contenidoCobro(
                                pedidoActivo,
                                dentroDeScrollExterno: true,
                              ),
                            ],
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _vistaPedidoExistente()),
                            _panelCobro(pedidoActivo),
                          ],
                        )),
          ),
        ],
      );
    }

    final anchoModal = esMobile
        ? MediaQuery.sizeOf(context).width
        : (catalogo ? 1000.0 : 780.0);
    final altoModal = esMobile
        ? MediaQuery.sizeOf(context).height * 0.92
        : 680.0;

    return ClipRRect(
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(24))
          : BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        width: anchoModal,
        height: altoModal,
        color: Colors.white,
        child: contenido,
      ),
    );
  }

  // Barra flotante inferior (mobile, vista de catálogo): resumen del
  // carrito/orden en curso; toca para pasar a verlo/confirmarlo. Oculta si
  // aún no hay ítems agregados.
  Widget _barraVerCarrito() {
    final ocupada = widget.mesa.estado == 'ocupada';
    final agregandoAExistente = ocupada && _agregandoItems;
    final int cantidad;
    final double total;
    if (agregandoAExistente) {
      final detalles = detallesPorPedido[_pedidoActivo?.id] ?? const [];
      cantidad = detalles.fold(0, (s, l) => s + l.cantidad);
      total = _pedidoActivo == null ? 0 : totalDePedido(_pedidoActivo!.id);
    } else {
      cantidad = _carrito.fold(0, (s, l) => s + l.cantidad);
      total = _totalConAjustes;
    }
    if (cantidad == 0) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Material(
          color: AppColors.primaryGreen,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => _mostrarCarritoMobile = true),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$cantidad',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Ver pedido',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    'S/ ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Header del panel ---

  Widget _encabezado(bool ocupada) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _tituloMesa,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  ocupada ? 'Pedido activo' : 'Nuevo pedido',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (ocupada && _pedidoActivo != null)
            IconButton(
              icon: Icon(
                _agregandoItems
                    ? Icons.receipt_long_outlined
                    : Icons.edit_outlined,
                size: 20,
              ),
              tooltip: _agregandoItems ? 'Ver pedido' : 'Agregar ítems',
              onPressed: () =>
                  setState(() => _agregandoItems = !_agregandoItems),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onCerrar,
          ),
        ],
      ),
    );
  }

  // --- Catálogo: armar pedido nuevo (mesa libre) o agregar más ítems ---
  // Buscador (fondo blanco, más ancho y bajo) + tabs de categoría (icono
  // arriba, etiqueta abajo) con una franja inferior verde de 1.5 en la
  // seleccionada, arriba de la grilla de productos.

  Widget _panelCatalogo({
    required bool ocupada,
    bool esMobile = false,
    required ValueChanged<CartaItem> onAgregar,
  }) {
    final buscador = TextField(
      controller: _busquedaProductoController,
      onChanged: (v) => setState(() => _busquedaProducto = v),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Buscar...',
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.primaryGreen),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SizedBox(width: esMobile ? 200 : 240, child: buscador),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _tabsCategorias(),
        ),
        const SizedBox(height: 4),
        Divider(height: 1, color: Colors.grey.shade200),
        Expanded(
          child: _gridProductos(
            ocupada: ocupada,
            esMobile: esMobile,
            onAgregar: onAgregar,
          ),
        ),
      ],
    );
  }

  // Los tabs no se estiran a lo ancho de la fila: cada uno ocupa solo el
  // espacio de su contenido y quedan alineados a la izquierda; scrollable en
  // horizontal para que no se desborden en pantallas angostas (mobile).
  Widget _tabsCategorias() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tabCategoria(null, 'Todo', HugeIcons.strokeRoundedGridView),
          for (final cat in mockCategorias)
            _tabCategoria(cat, cat.categoria, _iconoCategoria(cat.id)),
        ],
      ),
    );
  }

  // Los íconos de los tabs no cambian de color al seleccionar: solo el
  // texto y la franja inferior indican la categoría activa. El InkWell lleva
  // su propio borderRadius para que el sombreado gris de pulsar/pasar el
  // cursor sea un recuadro redondeado, no un rectángulo a filo.
  Widget _tabCategoria(
    CategoriaComida? cat,
    String label,
    List<List<dynamic>> icono,
  ) {
    final seleccionado = _categoriaSeleccionada?.id == cat?.id;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _categoriaSeleccionada = cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: seleccionado ? AppColors.primaryGreen : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: icono, size: 20, color: Colors.grey.shade700),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w600,
                color: seleccionado
                    ? AppColors.primaryGreen
                    : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridProductos({
    required bool ocupada,
    bool esMobile = false,
    required ValueChanged<CartaItem> onAgregar,
  }) {
    final items = _cartaFiltrada;
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Sin resultados',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: esMobile ? 2 : 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: esMobile ? 0.78 : 0.7,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => KeyedSubtree(
        key: ValueKey(items[index].id),
        child: _tarjetaProducto(items[index], onAgregar, ocupada),
      ),
    );
  }

  // Imagen real solo para algunos productos de muestra; el resto usa un
  // ícono de categoría como placeholder.
  String? _imagenDe(String cartaId) => imagenDeCarta(cartaId);

  int _cantidadEnCarritoDe(CartaItem item, bool ocupada) {
    final lineas = ocupada
        ? (detallesPorPedido[_pedidoActivo?.id] ?? const <PedidoLine>[])
        : _carrito;
    return lineas
        .where((l) => _mismoProductoSinPersonalizar(l, item))
        .fold(0, (s, l) => s + l.cantidad);
  }

  void _quitarUno(CartaItem item, bool ocupada) {
    if (ocupada) {
      final pedido = _pedidoActivo;
      if (pedido == null) return;
      final detalles = List<PedidoLine>.from(
        detallesPorPedido[pedido.id] ?? const [],
      );
      final index = detalles.indexWhere(
        (l) => _mismoProductoSinPersonalizar(l, item),
      );
      if (index == -1) return;
      final actual = detalles[index];
      if (actual.cantidad <= 1) {
        detalles.removeAt(index);
      } else {
        detalles[index] = _lineaConCantidad(actual, actual.cantidad - 1);
      }
      detallesPorPedido[pedido.id] = detalles;
      widget.onCambio();
      setState(() {});
    } else {
      final index = _carrito.indexWhere(
        (l) => _mismoProductoSinPersonalizar(l, item),
      );
      if (index == -1) return;
      setState(() {
        final actual = _carrito[index];
        if (actual.cantidad <= 1) {
          _carrito.removeAt(index);
        } else {
          _carrito[index] = _lineaConCantidad(actual, actual.cantidad - 1);
        }
      });
    }
  }

  Widget _tarjetaProducto(
    CartaItem item,
    ValueChanged<CartaItem> onAgregar,
    bool ocupada,
  ) {
    final desdePrecio = item.precioCliente == null;
    final cantidad = _cantidadEnCarritoDe(item, ocupada);
    final seleccionado = cantidad > 0;
    final imagen = _imagenDe(item.id);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: seleccionado ? AppColors.primaryGreen : Colors.grey.shade200,
          width: seleccionado ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // La foto ocupa todo el alto disponible que sobra tras el
          // nombre/precio/cantidad, en vez de un alto fijo que dejaba un
          // vacío en blanco debajo cuando la card es alta.
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: const Color(0xFFF1F3F0),
                  child: imagen != null
                      ? Image.asset(imagen, fit: BoxFit.cover)
                      : Center(
                          child: HugeIcon(
                            icon: _iconoCategoria(item.categoriaId),
                            size: 34,
                            color: Colors.grey.shade400,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.nombrePlato,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  desdePrecio
                      ? 'S/ ${_precioMinimoPresentacion(item.id).toStringAsFixed(2)}'
                      : 'S/ ${item.precioCliente!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              _stepperProducto(item, cantidad, ocupada, onAgregar),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepperProducto(
    CartaItem item,
    int cantidad,
    bool ocupada,
    ValueChanged<CartaItem> onAgregar,
  ) {
    final activo = cantidad > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: activo
            ? AppColors.primaryGreen.withValues(alpha: 0.12)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: activo ? () => _quitarUno(item, ocupada) : null,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.remove,
                size: 14,
                color: activo ? AppColors.primaryGreen : Colors.grey.shade400,
              ),
            ),
          ),
          SizedBox(
            width: 18,
            child: Text(
              '$cantidad',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          InkWell(
            onTap: () => onAgregar(item),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.add,
                size: 14,
                color: activo ? AppColors.primaryGreen : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Panel derecho: tipo de pedido + carrito + confirmar ---

  Widget _panelOrden({
    required bool ocupada,
    bool esMobile = false,
    VoidCallback? onVolverCatalogo,
  }) {
    final agregandoAExistente = ocupada && _agregandoItems;
    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabeceraOrden(ocupada, onVolverCatalogo: onVolverCatalogo),
        if (!agregandoAExistente) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: _tabsTipoPedido(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _campoTexto(
              controller: _nombreClienteController,
              hint: 'Nombre Cliente',
              icono: Icons.person_outline,
            ),
          ),
          if (_tipoPedido == 'delivery')
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _campoTexto(
                controller: _telefonoController,
                hint: 'WhatsApp / Teléfono',
                icono: Icons.phone_outlined,
              ),
            ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: agregandoAExistente
              ? _listaPedidoActivoResumen()
              : (_carrito.isEmpty
                    ? _carritoVacio()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _carrito.length,
                        itemBuilder: (context, index) => _filaCarrito(index),
                      )),
        ),
        agregandoAExistente ? _barraVolverPedido() : _resumenYConfirmar(),
      ],
    );
    if (esMobile) return contenido;
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade200)),
      ),
      child: contenido,
    );
  }

  Widget _cabeceraOrden(bool ocupada, {VoidCallback? onVolverCatalogo}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
      child: Row(
        children: [
          if (onVolverCatalogo != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: onVolverCatalogo,
            ),
            const SizedBox(width: 8),
          ] else if (ocupada) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => setState(() => _agregandoItems = false),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ocupada ? 'Agregar ítems' : 'Nuevo Pedido',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _tituloMesa,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onCerrar,
          ),
        ],
      ),
    );
  }

  Widget _tabsTipoPedido() {
    return Row(
      children: [
        _tabTipo('llevar', 'Llevar', Icons.shopping_bag_outlined),
        const SizedBox(width: 8),
        _tabTipo('mesa', 'Mesa', Icons.table_bar_outlined),
        const SizedBox(width: 8),
        _tabTipo('delivery', 'Delivery', Icons.delivery_dining_outlined),
      ],
    );
  }

  Widget _tabTipo(String valor, String label, IconData icono) {
    final activo = _tipoPedido == valor;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _tipoPedido = valor),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: activo
                ? AppColors.primaryGreen.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: activo ? AppColors.primaryGreen : Colors.grey.shade300,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icono,
                size: 16,
                color: activo ? AppColors.primaryGreen : Colors.grey.shade500,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: activo ? AppColors.primaryGreen : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campoTexto({
    required TextEditingController controller,
    required String hint,
    required IconData icono,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        prefixIcon: Icon(icono, size: 18),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryGreen),
        ),
      ),
    );
  }

  Widget _carritoVacio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'Carrito vacío',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _listaPedidoActivoResumen() {
    final pedido = _pedidoActivo;
    final detalles = pedido == null
        ? const []
        : detallesPorPedido[pedido.id] ?? const [];
    if (detalles.isEmpty) return _carritoVacio();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: detalles.length,
      itemBuilder: (context, index) => _filaItem(detalles[index]),
    );
  }

  Widget _badgeCantidad(int cantidad) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'x$cantidad',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _filaCarrito(int index) {
    final linea = _carrito[index];
    final desc = _descripcionLinea(linea);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badgeCantidad(linea.cantidad),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  linea.nombrePlato,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (desc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      desc,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            'S/ ${linea.precioTotalLinea.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _quitarLinea(index),
          ),
        ],
      ),
    );
  }

  Widget _resumenYConfirmar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _campoAjuste(
                  label: 'PROPINA',
                  controller: _propinaController,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _campoAjuste(
                  label: 'DESCUENTO',
                  controller: _descuentoController,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              Text(
                'S/ ${_totalConAjustes.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _carrito.isEmpty ? null : _confirmarPedido,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'CONFIRMAR Y CREAR PEDIDO',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoAjuste({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            prefixText: 'S/ ',
            prefixStyle: const TextStyle(fontSize: 13),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }

  Widget _barraVolverPedido() {
    final pedido = _pedidoActivo;
    final total = pedido == null ? 0.0 : totalDePedido(pedido.id);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total pedido',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                'S/ ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(() => _agregandoItems = false),
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(vertical: 14),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              side: const WidgetStatePropertyAll(
                BorderSide(color: AppColors.primaryGreen),
              ),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.pressed)) {
                  return AppColors.primaryGreen;
                }
                return Colors.transparent;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.pressed)) {
                  return Colors.white;
                }
                return AppColors.primaryGreen;
              }),
            ),
            child: const Text('Volver al pedido'),
          ),
        ],
      ),
    );
  }

  // --- Mesa ocupada: pedido activo (estilo captura) ---

  Widget _vistaPedidoExistente() {
    final pedido = _pedidoActivo;
    if (pedido == null) {
      return const Center(child: Text('Sin pedido activo para esta mesa'));
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: _contenidoPedidoExistente(pedido),
      ),
    );
  }

  // Contenido puro (sin scroll/borde propios) para poder reutilizarlo tanto
  // en el panel de escritorio como apilado dentro de un único scroll en
  // mobile (junto con el cobro, ver build()).
  Widget _contenidoPedidoExistente(Pedido pedido) {
    final detalles = detallesPorPedido[pedido.id] ?? [];
    final subtotal = detalles.fold(
      0.0,
      (s, l) => s + l.precioTotalLinea + l.descuentoAplicado,
    );
    final descuento = detalles.fold(0.0, (s, l) => s + l.descuentoAplicado);
    final total = totalDePedido(pedido.id);
    final saldo = saldoPendienteDePedido(pedido.id);
    final pagado = total - saldo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tarjetaInfoPedido(pedido),
        const SizedBox(height: 20),
        _tituloSeccion('ÍTEMS DEL PEDIDO'),
        const SizedBox(height: 8),
        if (detalles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Este pedido aún no tiene ítems.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          )
        else
          ...detalles.map(_filaItem),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() => _agregandoItems = true),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Agregar ítems'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _tituloSeccion('RESUMEN DE PAGO'),
        const SizedBox(height: 8),
        _filaResumen(
          'Subtotal (${detalles.length} ítem${detalles.length == 1 ? '' : 's'})',
          subtotal,
        ),
        if (descuento > 0)
          _filaResumen('Descuento', -descuento, color: Colors.green),
        const Divider(height: 20),
        _filaResumen('Total', total, negrita: true),
        if (pagado > 0.01 && saldo > 0.01)
          _filaResumen('Pagado', pagado, color: Colors.grey.shade700),
        if (saldo > 0.01 && saldo < total - 0.01)
          _filaResumen('Saldo pendiente', saldo, color: AppColors.mesaOcupada),
      ],
    );
  }

  // Tarjeta superior con avatar, mesa, código y estado.
  Widget _tarjetaInfoPedido(Pedido pedido) {
    final iniciales = 'M${pedido.mesaNumero}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.loginInputAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              iniciales,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pedido · ${pedido.codigoCorto}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_tituloMesa}  ·  ${_hora(pedido.fechaPedido)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _badgeEstado(pedido.estado, pedido.etiquetaEstado),
              const SizedBox(height: 6),
              _badgeTipoPedido(pedido.tipoPedido, pedido.etiquetaTipoPedido),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badgeTipoPedido(String tipo, String texto) {
    final icono = switch (tipo) {
      'llevar' => Icons.shopping_bag_outlined,
      'delivery' => Icons.delivery_dining_outlined,
      _ => Icons.table_bar_outlined,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeEstado(String estado, String texto) {
    Color fondo;
    Color borde;
    Color tinta;
    switch (estado) {
      case 'en_preparacion':
        fondo = const Color(0xFFE3F2FD);
        borde = const Color(0xFF1976D2);
        tinta = const Color(0xFF0D47A1);
        break;
      case 'listo':
        fondo = const Color(0xFFE8F5E9);
        borde = AppColors.primaryGreen;
        tinta = AppColors.primaryGreen;
        break;
      case 'entregado':
        fondo = const Color(0xFFE8F5E9);
        borde = const Color(0xFF2E7D32);
        tinta = const Color(0xFF1B5E20);
        break;
      default: // pendiente
        fondo = const Color(0xFFFFF3E0);
        borde = const Color(0xFFEF6C00);
        tinta = const Color(0xFFE65100);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borde.withValues(alpha: 0.35)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: tinta,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _filaItem(PedidoLine linea) {
    final pagadoLinea = montoPagadoDeLinea(linea.id);
    final desc = _descripcionLinea(linea);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badgeCantidad(linea.cantidad),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  linea.nombrePlato,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (desc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      desc,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                if (pagadoLinea > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Pagado S/ ${pagadoLinea.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'S/ ${linea.precioTotalLinea.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _tituloSeccion(String texto) {
    return Text(
      texto,
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
      ),
    );
  }

  Widget _filaResumen(
    String label,
    double monto, {
    Color? color,
    bool negrita = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: negrita ? FontWeight.w700 : FontWeight.normal,
              color: negrita ? Colors.black : Colors.grey.shade700,
            ),
          ),
          Text(
            'S/ ${monto.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: negrita ? FontWeight.w800 : FontWeight.w600,
              fontSize: negrita ? 17 : 14,
              color: color ?? (negrita ? Colors.black : Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  // --- Panel derecho de cobro: método de pago, monto, propina y el botón.
  // Vive en el mismo modal que el detalle del pedido (nunca aparte).

  Widget _panelCobro(Pedido pedido) {
    return Container(
      width: 300,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: _contenidoCobro(pedido, dentroDeScrollExterno: false),
    );
  }

  // dentroDeScrollExterno=true (mobile): el contenido va apilado dentro del
  // scroll compartido con _contenidoPedidoExistente (ver build()), así que
  // la lista de métodos de pago no debe pelear por un Expanded propio; en
  // escritorio (false) sí necesita su propio scroll interno para no empujar
  // el botón "Cobrar" fuera de la vista con una altura fija de 680.
  Widget _contenidoCobro(Pedido pedido, {required bool dentroDeScrollExterno}) {
    final saldo = saldoPendienteDePedido(pedido.id);
    final habilitado = saldo > 0.01;
    final listaMetodos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('MÉTODO DE PAGO'),
        const SizedBox(height: 8),
        for (final medio in mockMediosPago) _opcionMedioPago(medio),
        const SizedBox(height: 12),
        _tituloSeccion('MONTO A COBRAR (S/)'),
        const SizedBox(height: 6),
        _campoNumerico(_montoCobroController),
        const SizedBox(height: 12),
        _tituloSeccion('PROPINA (OPCIONAL, S/)'),
        const SizedBox(height: 6),
        _campoNumerico(_propinaCobroController),
        if (_medioPagoCobro.aplicaComision) ...[
          const SizedBox(height: 10),
          Text(
            'Comisión (${_medioPagoCobro.porcentajeComision.toStringAsFixed(1)}%): '
            '-S/ ${_comisionCobro.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 12, color: AppColors.error),
          ),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: dentroDeScrollExterno ? MainAxisSize.min : MainAxisSize.max,
      children: [
        const Text(
          'Cobro',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saldo pendiente',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                'S/ ${saldo.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        dentroDeScrollExterno
            ? listaMetodos
            : Expanded(child: SingleChildScrollView(child: listaMetodos)),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: habilitado ? () => _confirmarCobro(pedido, saldo) : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                habilitado ? Icons.payment : Icons.check_circle_outline,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                habilitado
                    ? 'Cobrar · S/ ${_montoCobro.toStringAsFixed(2)}'
                    : 'Pedido cobrado',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _opcionMedioPago(MedioPago medio) {
    final seleccionado = _medioPagoCobro.id == medio.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _medioPagoCobro = medio),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: seleccionado
                ? AppColors.primaryGreen.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: seleccionado
                  ? AppColors.primaryGreen
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                seleccionado
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: seleccionado
                    ? AppColors.primaryGreen
                    : Colors.grey.shade400,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  medio.medioPago,
                  style: TextStyle(
                    fontWeight: seleccionado
                        ? FontWeight.w700
                        : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              if (medio.aplicaComision)
                Text(
                  '+${medio.porcentajeComision.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campoNumerico(TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        prefixText: 'S/ ',
        prefixStyle: const TextStyle(fontSize: 13),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryGreen),
        ),
      ),
    );
  }
}

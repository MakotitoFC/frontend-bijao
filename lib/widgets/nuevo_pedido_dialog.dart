import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/cartas_store.dart';
import '../data/configuracion_store.dart';
import '../data/insumos_store.dart';
import '../data/mesas_store.dart';
import '../data/categorias_store.dart';
import '../data/pedidos_store.dart';
import '../models/app_role.dart';
import '../models/carta_item.dart';
import '../models/categoria_comida.dart';
import '../models/mesa.dart';
import '../models/mock_user.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import '../screens/mesas_screen.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../utils/carta_visuals.dart';
import 'app_toast.dart';
import 'descuento_dialog.dart';
import 'dotted_divider.dart';
import 'producto_opciones_dialog.dart';

// Arma un pedido nuevo (tipo ya elegido en ElegirTipoPedidoDialog): mesa
// (si aplica), galería de productos y resumen (`pedidos` + `pedidos_detalle`).
class NuevoPedidoDialog extends StatefulWidget {
  final MockUser usuario;
  final String tipo; // 'mesa' | 'delivery' | 'llevar', ya elegido antes.
  // true = se creó el pedido, false = se canceló/volvió a la cola.
  final ValueChanged<bool> onTerminar;

  const NuevoPedidoDialog({
    super.key,
    required this.usuario,
    required this.tipo,
    required this.onTerminar,
  });

  @override
  State<NuevoPedidoDialog> createState() => _NuevoPedidoDialogState();
}

class _NuevoPedidoDialogState extends State<NuevoPedidoDialog> {
  int? _mesaNumero;

  CategoriaComida? _categoria;
  final _busquedaController = TextEditingController();
  final List<PedidoLine> _carrito = [];
  bool _descEmpleado = false;
  final List<_Ajuste> _ajustes = []; // descuentos/servicios ("Descuento"/"+")

  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _notasController = TextEditingController();

  bool get _esAdmin => widget.usuario.rol == AppRole.administrador;

  @override
  void dispose() {
    _busquedaController.dispose();
    _nombreController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  // ---------- datos ----------

  List<CartaItem> get _productos {
    final termino = _busquedaController.text.trim().toLowerCase();
    return cartasNotifier.value.where((c) {
      if (!c.disponible) return false;
      if (_categoria != null && c.categoriaId != _categoria!.id) return false;
      if (termino.isEmpty) return true;
      return c.nombrePlato.toLowerCase().contains(termino);
    }).toList();
  }

  double get _subtotal => _carrito.fold(0.0, (s, l) => s + l.precioTotalLinea);

  double get _porcentajeDescuento =>
      _descEmpleado && config.descuentoEmpleadoHabilitado
      ? config.descuentoEmpleadoPorcentaje
      : 0;

  double get _descuento => _subtotal * _porcentajeDescuento / 100;

  double get _cargoDelivery =>
      (widget.tipo == 'delivery' && config.cargoDeliveryHabilitado)
      ? config.cargoDeliveryMonto
      : 0;

  double get _ajustesDescuento =>
      _ajustes.fold(0.0, (s, a) => s + a.calcular(_subtotal));

  double get _total => _subtotal - _descuento - _ajustesDescuento + _cargoDelivery;

  PedidoLine _conDescuento(PedidoLine l) {
    final pct = _porcentajeDescuento;
    if (pct <= 0) return l;
    final bruto = l.precioUnitario * l.cantidad;
    final d = bruto * pct / 100;
    return PedidoLine(
      id: l.id,
      cartaId: l.cartaId,
      nombrePlato: l.nombrePlato,
      cantidad: l.cantidad,
      modificadores: l.modificadores,
      presentacion: l.presentacion,
      taper: l.taper,
      promocion: l.promocion,
      comentario: l.comentario,
      precioUnitario: l.precioUnitario,
      descuentoAplicado: d,
      precioTotalLinea: bruto - d,
    );
  }

  // ---------- acciones ----------

  Future<void> _abrirOpciones(CartaItem item) async {
    final resultado = await showBlurDialog<ProductoConfigurado>(
      context: context,
      builder: (_) => ProductoOpcionesDialog(item: item, esAdmin: _esAdmin),
    );
    if (resultado == null || !mounted) return;
    setState(() {
      _carrito.add(
        PedidoLine(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          cartaId: item.id,
          nombrePlato: item.nombrePlato,
          cantidad: resultado.cantidad,
          modificadores: resultado.modificadores,
          presentacion: resultado.presentacion,
          taper: null,
          promocion: null,
          comentario: resultado.comentario,
          precioUnitario: resultado.precioUnitario,
          descuentoAplicado: 0,
          precioTotalLinea: resultado.precioUnitario * resultado.cantidad,
        ),
      );
    });
  }

  void _cambiarCantidadLinea(int index, int delta) {
    final linea = _carrito[index];
    final nueva = linea.cantidad + delta;
    setState(() {
      if (nueva <= 0) {
        _carrito.removeAt(index);
      } else {
        _carrito[index] = PedidoLine(
          id: linea.id,
          cartaId: linea.cartaId,
          nombrePlato: linea.nombrePlato,
          cantidad: nueva,
          modificadores: linea.modificadores,
          presentacion: linea.presentacion,
          taper: linea.taper,
          promocion: linea.promocion,
          comentario: linea.comentario,
          precioUnitario: linea.precioUnitario,
          descuentoAplicado: 0,
          precioTotalLinea: linea.precioUnitario * nueva,
        );
      }
    });
  }

  void _imprimir() {
    showAppToast(
      context,
      'Comanda enviada a imprimir.',
      type: ToastType.success,
    );
  }

  void _confirmar() {
    if (_carrito.isEmpty) {
      showAppToast(context, 'Agrega al menos un producto.', type: ToastType.error);
      return;
    }
    final esDelivery = widget.tipo == 'delivery';
    final esMesa = widget.tipo == 'mesa';
    if (esMesa && _mesaNumero == null) {
      showAppToast(context, 'Selecciona una mesa.', type: ToastType.error);
      return;
    }
    if (esDelivery &&
        (_telefonoController.text.trim().isEmpty ||
            _direccionController.text.trim().isEmpty)) {
      showAppToast(
        context,
        'Ingresa el celular y la dirección de entrega.',
        type: ToastType.error,
      );
      return;
    }

    final mesaNumero = esMesa ? _mesaNumero! : 0;
    final pedido = Pedido(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      numeroPedido: siguienteNumeroPedido(),
      mesaNumero: mesaNumero,
      tipoPedido: widget.tipo,
      fechaPedido: DateTime.now(),
      notas: _notasController.text.trim().isEmpty
          ? null
          : _notasController.text.trim(),
      clienteNombre: _nombreController.text.trim().isEmpty
          ? null
          : _nombreController.text.trim(),
      clienteCelular: esDelivery && _telefonoController.text.trim().isNotEmpty
          ? _telefonoController.text.trim()
          : null,
      direccionDelivery: esDelivery && _direccionController.text.trim().isNotEmpty
          ? _direccionController.text.trim()
          : null,
      usuarioId: widget.usuario.id,
    );
    final lineas = <PedidoLine>[
      for (final l in _carrito) _conDescuento(l),
      if (_cargoDelivery > 0)
        PedidoLine(
          id: '${DateTime.now().microsecondsSinceEpoch}-cargo',
          cartaId: cartaIdCargoDelivery,
          nombrePlato: 'Cargo por delivery',
          cantidad: 1,
          modificadores: const [],
          presentacion: null,
          taper: null,
          promocion: null,
          comentario: null,
          precioUnitario: _cargoDelivery,
          descuentoAplicado: 0,
          precioTotalLinea: _cargoDelivery,
        ),
      for (final a in _ajustes)
        PedidoLine(
          id: '${DateTime.now().microsecondsSinceEpoch}-${a.nombre.hashCode}',
          cartaId: cartaIdAjuste,
          nombrePlato: 'Descuento: ${a.nombre}',
          cantidad: 1,
          modificadores: const [],
          presentacion: null,
          taper: null,
          promocion: null,
          comentario: null,
          precioUnitario: -a.calcular(_subtotal),
          descuentoAplicado: 0,
          precioTotalLinea: -a.calcular(_subtotal),
        ),
    ];
    registrarPedido(pedido, lineas);
    if (esMesa) actualizarEstadoMesa(mesaNumero, 'ocupada');
    for (final l in lineas) {
      if (l.cartaId != cartaIdCargoDelivery && l.cartaId != cartaIdAjuste) {
        registrarConsumoAutomaticoDeLinea(l);
      }
    }

    final items = _carrito.fold(0, (s, l) => s + l.cantidad);
    final destino = esMesa
        ? 'Mesa $mesaNumero'
        : (esDelivery ? 'Delivery' : 'Para llevar');
    showAppToast(
      context,
      'Pedido #${pedido.numeroPedido} · $destino · $items ítem(s) · enviado a cocina',
      type: ToastType.success,
      titulo: 'Pedido confirmado',
    );
    widget.onTerminar(true);
  }

  void _elegirMesa(Mesa mesa) {
    if (mesa.estado != 'libre') {
      showAppToast(
        context,
        'La mesa ${mesa.numero} está ocupada.',
        type: ToastType.error,
      );
      return;
    }
    setState(() => _mesaNumero = mesa.numero);
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final enPasoMesa = widget.tipo == 'mesa' && _mesaNumero == null;
    final titulo = enPasoMesa
        ? 'Elige una mesa'
        : switch (widget.tipo) {
            'delivery' => 'Pedido de delivery',
            'llevar' => 'Pedido para llevar',
            _ => 'Mesa $_mesaNumero',
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              _botonCerrar(),
            ],
          ),
        ),
        Expanded(
          child: enPasoMesa
              ? MesasPlano(onSeleccionarMesa: _elegirMesa)
              : _armarPedido(esMobile),
        ),
      ],
    );
  }

  // "X" para salir y volver a la cola de pedidos.
  Widget _botonCerrar() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => widget.onTerminar(false),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(Icons.close, size: 18, color: Colors.grey.shade700),
      ),
    );
  }

  // --- Galería de productos + resumen ---

  Widget _armarPedido(bool esMobile) {
    final galeria = _galeria();
    final resumen = _resumen(fixedFooter: !esMobile);
    if (esMobile) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [galeria, const SizedBox(height: 16), resumen],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: galeria),
          const SizedBox(width: 16),
          SizedBox(width: 320, child: resumen),
        ],
      ),
    );
  }

  Widget _galeria() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Buscador del mismo ancho que los tags de categoría de abajo.
        IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _campoTexto(
                controller: _busquedaController,
                hint: 'Buscar producto...',
                icono: Icons.search,
                onChanged: (_) => setState(() {}),
                contentPaddingVertical: 14,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _pillCategoria('Todos', _categoria == null, () {
                    setState(() => _categoria = null);
                  }),
                  for (final cat in mockCategorias)
                    _pillCategoria(cat.categoria, _categoria?.id == cat.id, () {
                      setState(() => _categoria = cat);
                    }),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SizedBox(
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, c) {
                final productos = _productos;
                if (productos.isEmpty) {
                  return Center(
                    child: Text(
                      'Sin resultados',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  );
                }
                const espacio = 12.0;
                final columnas = c.maxWidth >= 620
                    ? 3
                    : (c.maxWidth >= 400 ? 2 : 1);
                final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
                return SingleChildScrollView(
                  child: Wrap(
                    spacing: espacio,
                    runSpacing: espacio,
                    children: [
                      for (final p in productos)
                        SizedBox(width: ancho, child: _tarjetaProducto(p)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _pillCategoria(String texto, bool activo, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: activo ? AppColors.navbar : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: activo ? null : Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: activo ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _imagen(CartaItem item) {
    final asset = imagenDeCarta(item.id);
    return ColoredBox(
      color: const Color(0xFFF1F3F0),
      child: asset != null
          ? Image.asset(asset, fit: BoxFit.cover, width: double.infinity)
          : Center(
              child: Icon(
                iconoDeCategoria(item.categoriaId),
                size: 30,
                color: Colors.grey.shade400,
              ),
            ),
    );
  }

  // Tarjeta con botón "+ Agregar al pedido" que abre el modal de opciones.
  Widget _tarjetaProducto(CartaItem item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 11,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _imagen(item),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.nombrePlato,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            'S/ ${(item.precioCliente ?? 0).toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: FilledButton.icon(
              onPressed: () => _abrirOpciones(item),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.add, size: 15),
              label: const Text(
                'Agregar al pedido',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumen({required bool fixedFooter}) {
    final esDelivery = widget.tipo == 'delivery';
    final tituloTipo = switch (widget.tipo) {
      'delivery' => 'Delivery',
      'llevar' => 'Para llevar',
      _ => 'Mesa $_mesaNumero',
    };
    final iconoTipo = switch (widget.tipo) {
      'delivery' => LucideIcons.bike,
      'llevar' => LucideIcons.shoppingBag,
      _ => LucideIcons.utensils,
    };
    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(iconoTipo, size: 16, color: AppColors.primaryGreenDark),
            const SizedBox(width: 6),
            Text(
              tituloTipo,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _campoTexto(
          controller: _nombreController,
          hint: 'Nombre del cliente (opcional)',
          icono: Icons.person_outline,
          contentPaddingVertical: 16,
        ),
        if (esDelivery) ...[
          const SizedBox(height: 10),
          _campoTexto(
            controller: _telefonoController,
            hint: 'Celular / WhatsApp',
            icono: Icons.phone_outlined,
            teclado: TextInputType.phone,
            contentPaddingVertical: 16,
          ),
          const SizedBox(height: 10),
          _campoTexto(
            controller: _direccionController,
            hint: 'Dirección de entrega',
            icono: Icons.location_on_outlined,
            contentPaddingVertical: 16,
          ),
        ],
        const SizedBox(height: 10),
        _campoTexto(
          controller: _notasController,
          hint: 'Nota del pedido (opcional)',
          icono: Icons.notes_outlined,
          maxLines: 3,
        ),
        const SizedBox(height: 14),
        Divider(height: 1, color: Colors.grey.shade200),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              'Productos del pedido',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const Spacer(),
            if (_carrito.isNotEmpty)
              InkWell(
                onTap: () => setState(_carrito.clear),
                child: Text(
                  'Limpiar',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_carrito.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                'Aún no agregas productos',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          )
        else
          for (var i = 0; i < _carrito.length; i++) _filaCarrito(i),
        if (config.descuentoEmpleadoHabilitado) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Descuento de empleado (${config.descuentoEmpleadoPorcentaje.toStringAsFixed(0)}%)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Switch(
                value: _descEmpleado,
                onChanged: (v) => setState(() => _descEmpleado = v),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primaryGreen,
              ),
            ],
          ),
        ],
      ],
    );
    final pie = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _filaTotal('Subtotal', _subtotal, fuerte: false)),
                  const SizedBox(width: 8),
                  _botonAgregarAjuste(),
                ],
              ),
              for (final a in _ajustes) ...[
                const SizedBox(height: 6),
                _filaAjuste(a),
              ],
              if (_descuento > 0) ...[
                const SizedBox(height: 6),
                _filaTotal('Descuento', -_descuento, fuerte: false),
              ],
              if (_cargoDelivery > 0) ...[
                const SizedBox(height: 6),
                _filaTotal('Cargo por delivery', _cargoDelivery, fuerte: false),
              ],
              const SizedBox(height: 10),
              _filaTotal('Total', _total, fuerte: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const DottedDivider(),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: OutlinedButton(
                onPressed: _carrito.isEmpty ? null : _imprimir,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Icon(
                  Icons.print_outlined,
                  size: 20,
                  color: _carrito.isEmpty ? Colors.grey.shade400 : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _carrito.isEmpty ? null : _confirmar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirmar pedido',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    final decoracion = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200),
    );
    if (!fixedFooter) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: decoracion,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [contenido, const SizedBox(height: 14), pie],
        ),
      );
    }
    return Container(
      decoration: decoracion,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: contenido,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: pie,
          ),
        ],
      ),
    );
  }

  // Fila de un descuento agregado, con botón para quitarlo.
  Widget _filaAjuste(_Ajuste a) {
    final monto = a.calcular(_subtotal);
    return Row(
      children: [
        Expanded(
          child: Text(
            a.esPorcentaje ? '${a.nombre} (${a.monto.toStringAsFixed(0)}%)' : a.nombre,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '-S/ ${monto.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _ajustes.remove(a)),
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(Icons.close, size: 14, color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }

  // Abre el modal de Descuentos para agregar uno como tag.
  Widget _botonAgregarAjuste() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _abrirAjuste,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(Icons.add, size: 16, color: AppColors.primaryGreenDark),
      ),
    );
  }

  Future<void> _abrirAjuste() async {
    final resultado = await showBlurDialog<DescuentoConfigurado>(
      context: context,
      builder: (_) => const DescuentoDialog(),
    );
    if (resultado == null || !mounted) return;
    setState(() {
      _ajustes.add(
        _Ajuste(
          nombre: resultado.nombre,
          esPorcentaje: resultado.esPorcentaje,
          monto: resultado.monto,
        ),
      );
    });
  }

  // Fila del carrito para una línea del pedido.
  Widget _filaCarrito(int index) {
    final linea = _carrito[index];
    final item = cartasNotifier.value.where((c) => c.id == linea.cartaId).firstOrNull;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item != null)
            SizedBox(
              width: 40,
              height: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _imagen(item),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  linea.nombrePlato,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                if (linea.presentacion != null)
                  Text(
                    '${linea.presentacion!.unidad.unidadPresentacion} ${linea.presentacion!.volumenMl}ml',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                if (linea.modificadores.isNotEmpty)
                  Text(
                    linea.modificadores.map((m) => m.nombre).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                if (linea.comentario != null)
                  Text(
                    linea.comentario!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade500,
                    ),
                  ),
                Text(
                  'S/ ${linea.precioUnitario.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          _iconoCantidad(Icons.remove, () => _cambiarCantidadLinea(index, -1)),
          SizedBox(
            width: 20,
            child: Text(
              '${linea.cantidad}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          _iconoCantidad(Icons.add, () => _cambiarCantidadLinea(index, 1)),
        ],
      ),
    );
  }

  Widget _iconoCantidad(IconData icono, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icono, size: 16, color: AppColors.primaryGreen),
      ),
    );
  }

  Widget _filaTotal(String etiqueta, double valor, {required bool fuerte}) {
    final estilo = TextStyle(
      fontSize: fuerte ? 15 : 12,
      fontWeight: fuerte ? FontWeight.w800 : FontWeight.w500,
      color: fuerte ? Colors.black87 : Colors.grey.shade600,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(etiqueta, style: estilo, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Text('${valor < 0 ? '-' : ''}S/ ${valor.abs().toStringAsFixed(2)}', style: estilo),
      ],
    );
  }

  Widget _campoTexto({
    required TextEditingController controller,
    required String hint,
    required IconData icono,
    TextInputType? teclado,
    ValueChanged<String>? onChanged,
    double contentPaddingVertical = 10,
    int maxLines = 1,
  }) {
    final multilinea = maxLines > 1;
    return TextField(
      controller: controller,
      keyboardType: teclado,
      onChanged: onChanged,
      maxLines: maxLines,
      minLines: multilinea ? maxLines : null,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        prefixIcon: multilinea
            ? null
            : Icon(icono, size: 18, color: Colors.grey.shade500),
        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 18),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(
          vertical: contentPaddingVertical,
          horizontal: multilinea ? 14 : 0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: AppColors.primaryGreen),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// Descuento del pedido: por porcentaje (sobre el subtotal) o monto fijo.
class _Ajuste {
  final String nombre;
  final bool esPorcentaje;
  final double monto;

  const _Ajuste({
    required this.nombre,
    required this.esPorcentaje,
    required this.monto,
  });

  double calcular(double subtotal) =>
      esPorcentaje ? subtotal * monto / 100 : monto;
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'dialogo_app.dart';

import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/cartas_store.dart';
import '../data/disponibilidad_store.dart';
import '../data/insumos_store.dart';
import '../data/mesas_store.dart';
import '../data/borrador_pedido_store.dart';
import '../data/categorias_store.dart';
import '../data/pedidos_store.dart';
import 'detalle_pedido_panel.dart' show nombreMeseroDe;
import '../data/promociones_store.dart';
import '../data/variantes_store.dart';
import '../models/app_role.dart';
import '../models/carta_item.dart';
import '../models/categoria_comida.dart';
import '../models/mesa.dart';
import '../models/usuario.dart';
import '../models/pedido.dart';
import '../models/taper.dart';
import '../models/pedido_line.dart';
import '../screens/mesas_screen.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../services/disponibilidad_service.dart';
import '../services/pedido_mozo_service.dart';
import '../services/pedido_service.dart';
import '../utils/blur_dialog.dart';
import '../utils/error_disponibilidad.dart';
import '../utils/motivo_precio.dart';
import '../utils/uuid_helper.dart';
import 'app_search_field.dart';
import 'app_tag.dart';
import 'app_toast.dart';
import 'dotted_divider.dart';
import 'imagen_plato.dart';
import 'plato_libre_dialog.dart';
import 'producto_opciones_dialog.dart';
import 'promocion_pedido_dialogs.dart';
import 'propina_dialog.dart';
import 'taper_catalogo_dialog.dart';
import 'tupper_dialog.dart';
import 'campo_texto.dart';
import 'indicador_abajo.dart';
import 'pago_dialogs.dart' show ModalPago;

// Arma un pedido nuevo (tipo ya elegido en ElegirNuevoPedidoDialog): mesa
// (si aplica), galería de productos y resumen (`pedidos` + `pedidos_detalle`).
class NuevoPedidoDialog extends StatefulWidget {
  final Usuario usuario;
  final String tipo; // 'mesa' | 'delivery', ya elegido antes.
  // true = se creó el pedido, false = se canceló/volvió a la cola.
  final ValueChanged<bool> onTerminar;
  // Volver desde el primer paso: reabre la elección del tipo de pedido.
  final VoidCallback onVolver;
  // Si viene activo (por ejemplo, al crear desde la pestaña "Empleados"):
  final bool inicioPersonal;
  // Familia de los dueños: cuenta cero (se aplica un descuento del 100 %).
  final bool esFamilia;

  const NuevoPedidoDialog({
    super.key,
    required this.usuario,
    required this.tipo,
    required this.onTerminar,
    required this.onVolver,
    this.inicioPersonal = false,
    this.esFamilia = false,
  });

  @override
  State<NuevoPedidoDialog> createState() => _NuevoPedidoDialogState();
}

class _NuevoPedidoDialogState extends State<NuevoPedidoDialog>
    with WidgetsBindingObserver {
  int? _mesaNumero;
  String? _mesaId;
  bool _confirmando = false;
  // true cuando el pedido terminó (confirmado, cerrado o se volvió atrás): no se
  // guarda como borrador.
  bool _descartado = false;
  // true mientras el pedido se está enviando: el borrador guardado lleva esa
  // marca y no se toca hasta saber el resultado.
  bool _enviandoBorrador = false;
  Timer? _autoguardado;
  String? _ultimoGuardado;
  // Pantallas angostas: el detalle del pedido va en una hoja inferior que se
  // puede expandir.
  bool _carritoExpandido = false;
  // La lista de productos de la hoja se puede ocultar para ver más la galería.
  // Empieza oculta: la galería es lo principal; el total ya se ve en la cabecera.
  bool _listaOculta = true;

  CategoriaComida? _categoria;
  final _busquedaController = TextEditingController();
  final List<PedidoLine> _carrito = [];
  double _propina = 0; // propina para el mesero (0 = sin propina)
  static const TupperConfigurado _sinTupper = (
    grande: 0,
    precioGrande: 0,
    mediano: 0,
    precioMediano: 0,
  );
  TupperConfigurado _tupper = _sinTupper;
  double get _tupperTotal =>
      _tupper.grande * _tupper.precioGrande +
      _tupper.mediano * _tupper.precioMediano;

  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _referenciaController = TextEditingController();
  // Monto del delivery: obligatorio. Varía según la dirección y lo registra caja
  // o administración, así que se escribe en cada pedido (nunca viene sugerido).
  final _envioController = TextEditingController();
  final _notasController = TextEditingController();

  bool get _esAdmin => widget.usuario.administraPedidos;

  @override
  void initState() {
    super.initState();
    if (widget.inicioPersonal) {
      _esPersonal = true;
      // Antes de agregar productos: aviso de que el precio de empleado se
      // escribe después, con el botón PRECIO EMPLEADO.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _carrito.isEmpty) _avisarPrecioEmpleado();
      });
    }
    // Disponibilidad del día al día: otros mozos o el administrador la cambian.
    DisponibilidadService.instance.cargarHoy();
    // La carta puede haber cambiado (productos inhabilitados, precios, platos
    // nuevos): se lee al abrir y la galería se redibuja cuando llega.
    CatalogService.instance.cargarCarta();
    cartasNotifier.addListener(_alCambiarCarta);
    _restaurarBorrador();
    // Se guarda en el dispositivo mientras se arma (no solo al salir de la
    // vista): si la app se cierra o el sistema la mata, el pedido sigue ahí.
    WidgetsBinding.instance.addObserver(this);
    _autoguardado = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _guardarSiCambio(),
    );
  }

  // Al minimizar la app (en Android el sistema puede cerrarla después) se guarda
  // en el acto.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado != AppLifecycleState.resumed) _guardarSiCambio(forzar: true);
  }

  // Solo se guarda si la sesión sigue siendo de este usuario (al cerrar sesión
  // no debe quedar ninguna copia).
  bool get _sesionVigente =>
      AuthService.instance.currentUser?.id == widget.usuario.id;

  void _guardarSiCambio({bool forzar = false}) {
    if (!mounted ||
        _descartado ||
        _enviandoBorrador ||
        _confirmando ||
        !_sesionVigente) {
      return;
    }
    final b = _armarBorrador();
    final huella = jsonEncode((b.toJson()..remove('guardado_en')));
    if (!forzar && huella == _ultimoGuardado) return;
    _ultimoGuardado = huella;
    borradorPedido = b.tieneContenido ? b : null;
  }

  // Si se salió de esta vista con el pedido a medias, se retoma tal cual.
  void _restaurarBorrador() {
    final b = borradorDe(widget.usuario.id);
    if (b == null || b.tipo != widget.tipo) return;
    _carrito.addAll(b.carrito);
    _propina = b.propina;
    _tupper = b.tupper;
    _nombreController.text = b.nombre;
    _telefonoController.text = b.telefono;
    _direccionController.text = b.direccion;
    _referenciaController.text = b.referencia;
    _envioController.text = b.envio;
    _notasController.text = b.notas;
    // La mesa elegida puede haberse ocupado mientras tanto.
    final mesa = b.mesaNumero == null
        ? null
        : mesas.where((m) => m.numero == b.mesaNumero).firstOrNull;
    if (mesa != null && mesa.estaLibre) {
      _mesaNumero = mesa.numero;
      _mesaId = mesa.id;
    }
  }

  BorradorPedido _armarBorrador() => BorradorPedido(
    usuarioId: widget.usuario.id,
    tipo: widget.tipo,
    mesaNumero: _mesaNumero,
    mesaId: _mesaId,
    carrito: List.of(_carrito),
    propina: _propina,
    tupper: _tupper,
    nombre: _nombreController.text,
    telefono: _telefonoController.text,
    direccion: _direccionController.text,
    referencia: _referenciaController.text,
    envio: _envioController.text,
    notas: _notasController.text,
  );

  // Guarda lo que hay para retomarlo al volver a esta vista.
  void _guardarBorrador() {
    if (!_sesionVigente) return;
    final b = _armarBorrador();
    borradorPedido = b.tieneContenido ? b : null;
  }

  // El pedido terminó: ya no hay borrador que conservar.
  void _descartarBorrador() {
    _descartado = true;
    limpiarBorradorPedido();
  }

  void _alCambiarCarta() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scrollGrilla.dispose();
    _scrollResumen.dispose();
    cartasNotifier.removeListener(_alCambiarCarta);
    _autoguardado?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (!_descartado && !_enviandoBorrador) _guardarBorrador();
    _busquedaController.dispose();
    _nombreController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _referenciaController.dispose();
    _envioController.dispose();
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

  // Pedido de personal (solo administrador y caja): el precio de cada plato se
  // escribe a mano en el cuadro del botón Empleado y es distinto cada vez.
  bool _esPersonal = false;
  final Map<String, double> _preciosPersonal = {};

  bool get _puedePersonal =>
      widget.usuario.rol == AppRole.administrador ||
      widget.usuario.rol == AppRole.cajero;

  // Las líneas con el precio que de verdad se cobra: en un pedido de empleado,
  // el que se escribió para cada producto (sin cambio, el de la carta).
  List<PedidoLine> get _lineas => _esPersonal
      ? [
          for (final l in _carrito)
            _preciosPersonal.containsKey(l.id)
                ? l.conPrecio(_preciosPersonal[l.id]!)
                : l,
        ]
      : _carrito;

  double get _subtotal => _lineas.fold(0.0, (s, l) => s + l.precioTotalLinea);

  double get _cargoDelivery {
    if (widget.tipo != 'delivery') return 0;
    final v = double.tryParse(
      _envioController.text.trim().replaceAll(',', '.'),
    );
    return (v == null || v < 0) ? 0 : v;
  }

  double get _total => _subtotal + _cargoDelivery + _propina + _tupperTotal;

  // ---------- acciones ----------

  // Abre el modal del producto. Con [indice] corrige esa línea del carrito.
  Future<void> _abrirOpciones(
    CartaItem item, {
    Color? acento,
    int? indice,
  }) async {
    final previa = indice == null ? null : _carrito[indice];
    final resultado = await showBlurDialog<ProductoConfigurado>(
      context: context,
      builder: (_) => ProductoOpcionesDialog(
        item: item,
        esAdmin: _esAdmin,
        acento: acento,
        enCarrito: _carrito,
        tipoEntregaInicial: widget.tipo,
        permitePrecioManual: true,
        lineaInicial: previa,
      ),
    );
    if (resultado == null || !mounted) return;
    setState(() {
      final idLinea = previa?.id ?? UuidHelper.v7();
      if (resultado.precioManual) {
        _precioCarta[idLinea] = resultado.precioOriginal;
      } else {
        _precioCarta.remove(idLinea);
      }
      final nueva = PedidoLine(
        id: idLinea,
        cartaId: item.id,
        nombrePlato: item.nombrePlato,
        cantidad: resultado.cantidad,
        modificadores: resultado.modificadores,
        presentacion: resultado.presentacion,
        variante: resultado.variante,
        promocion: null,
        comentario: resultado.comentario,
        precioUnitario: resultado.precioUnitario,
        descuentoAplicado: 0,
        precioTotalLinea: resultado.totalLinea,
        tipoEntrega: resultado.tipoEntrega,
        aplicaTaper: resultado.llevaTaper,
        taperId: resultado.taperId,
        precioTaper: resultado.precioTaper,
        cantidadTaper: resultado.cantidadTaper,
        esLibre: false,
        precioBase:
            resultado.variante?.precioCliente ?? item.precioCliente ?? 0.0,
        precioManual: resultado.precioManual,
      );
      if (indice != null) {
        _carrito[indice] = nueva;
        return;
      }
      _carrito.add(nueva);
      // Los demás tápers elegidos van como filas propias.
      for (final e in resultado.tapersAdicionales) {
        _carrito.add(lineaDeTaper(e.taper, e.cantidad));
      }
    });
  }

  // Agrega una promoción tal como la configuró el admin; el mozo solo cambia un
  // producto si el cliente lo pide.
  Future<void> _abrirPromocion() async {
    final e = await elegirPromocionOCumpleanos(context);
    if (e == null || !mounted) return;
    setState(() {
      final promo = e.promocion;
      if (promo != null) _carrito.add(lineaDePromocion(promo));
      _carrito.addAll(e.cumpleanos);
    });
  }

  // Cambia productos de una promoción del carrito (a pedido del cliente).
  Future<void> _cambiarProductosPromocion(int index) async {
    final linea = _carrito[index];
    final promo = linea.promocion;
    if (promo == null) return;
    final r = await showBlurDialog<PromocionConfigurada>(
      context: context,
      builder: (_) => PromocionOpcionesDialog(
        promocion: promo,
        inicial: linea.componentes,
        edicion: true,
      ),
    );
    if (r == null || !mounted) return;
    setState(
      () => _carrito[index] = linea.conComponentes(
        r.componentes,
        r.precioUnitario,
      ),
    );
  }

  // Modal para agregar un plato libre / pedido rápido que no está en la carta.
  Future<void> _abrirPlatoLibre() async {
    final linea = await showBlurDialog<PedidoLine>(
      context: context,
      builder: (_) => const PlatoLibreDialog(),
    );
    if (linea == null || !mounted) return;
    setState(() {
      _carrito.add(linea);
    });
  }

  // Porciones que aún se pueden pedir de esta línea, contando el resto del
  // carrito (null = sin tope).
  int? _topeDeLinea(int index) {
    final linea = _carrito[index];
    final quedan = topeDeUnidades(
      linea.cartaId,
      presentacionId: linea.presentacion?.id,
      varianteId: linea.variante?.id,
    );
    if (quedan == null) return null;
    var otras = 0;
    for (var i = 0; i < _carrito.length; i++) {
      final l = _carrito[i];
      if (i != index &&
          l.cartaId == linea.cartaId &&
          l.presentacion?.id == linea.presentacion?.id &&
          l.variante?.id == linea.variante?.id) {
        otras += l.cantidad;
      }
    }
    return quedan - otras < 0 ? 0 : quedan - otras;
  }

  void _quitarLineaCarrito(int index) =>
      setState(() => _carrito.removeAt(index));

  void _cambiarCantidadLinea(int index, int delta) {
    final linea = _carrito[index];
    final nueva = linea.cantidad + delta;
    final tope = _topeDeLinea(index);
    if (delta > 0 && tope != null && nueva > tope) {
      showAppToast(
        context,
        'Solo quedan $tope de "${linea.nombrePlato}".',
        type: ToastType.error,
      );
      return;
    }
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
          variante: linea.variante,
          componentes: linea.componentes,
          promocion: linea.promocion,
          comentario: linea.comentario,
          precioUnitario: linea.precioUnitario,
          descuentoAplicado: 0,
          precioTotalLinea: linea.precioUnitario * nueva,
          precioManual: linea.precioManual,
        );
      }
    });
  }

  Future<void> _confirmar() async {
    if (_confirmando) return;
    if (_carrito.isEmpty) {
      showAppToast(
        context,
        'Agrega al menos un producto.',
        type: ToastType.error,
      );
      return;
    }
    final esDelivery = widget.tipo == 'delivery';
    final esMesa = widget.tipo == 'mesa';
    if (esMesa && _mesaNumero == null) {
      showAppToast(context, 'Selecciona una mesa.', type: ToastType.error);
      return;
    }
    // Datos que pide cada tipo: para llevar, el nombre; delivery, nombre,
    // celular, dirección y monto del delivery.
    final faltan = <String>[
      if ((!esMesa || _esPersonal || widget.esFamilia) &&
          _nombreController.text.trim().isEmpty)
        _esPersonal
            ? 'Nombre del empleado'
            : (widget.esFamilia ? 'Nombre del familiar' : 'Nombre del cliente'),
      if (esDelivery && _telefonoController.text.trim().isEmpty)
        'Celular / WhatsApp',
      if (esDelivery && _direccionController.text.trim().isEmpty)
        'Dirección de entrega',
      if (esDelivery &&
          double.tryParse(_envioController.text.trim().replaceAll(',', '.')) ==
              null)
        'Monto del delivery',
    ];
    if (faltan.isNotEmpty) {
      await showBlurDialog<void>(
        context: context,
        builder: (dialogContext) => AlertaApp(
          title: const Text('FALTAN DATOS DEL PEDIDO'),
          content: Text(
            'Antes de confirmar el pedido ${esDelivery ? 'de delivery' : 'para llevar'} '
            'ingresa:\n\n${faltan.map((f) => '• $f').join('\n')}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _confirmando = true);

    final mesaNumero = esMesa ? _mesaNumero! : 0;
    final pedidoUuid = UuidHelper.v7();
    final pedido = Pedido(
      id: pedidoUuid,
      numeroPedido: siguienteNumeroPedido(),
      mesaNumero: mesaNumero,
      tipoPedido: widget.tipo,
      fechaPedido: DateTime.now(),
      notas: _notasController.text.trim().isEmpty
          ? null
          : _notasController.text.trim(),
      clienteNombre:
          (esMesa && !_esPersonal && !widget.esFamilia) ||
              _nombreController.text.trim().isEmpty
          ? null
          : _nombreController.text.trim(),
      clienteCelular: esDelivery && _telefonoController.text.trim().isNotEmpty
          ? _telefonoController.text.trim()
          : null,
      direccionDelivery:
          esDelivery && _direccionController.text.trim().isNotEmpty
          ? _direccionController.text.trim()
          : null,
      referenciaDelivery:
          esDelivery && _referenciaController.text.trim().isNotEmpty
          ? _referenciaController.text.trim()
          : null,
      usuarioId: widget.usuario.id,
    );
    final lineas = <PedidoLine>[
      ..._lineas,
      if (_cargoDelivery > 0)
        PedidoLine(
          id: UuidHelper.v7(),
          cartaId: cartaIdCargoDelivery,
          nombrePlato: 'Cargo por delivery',
          cantidad: 1,
          modificadores: const [],
          presentacion: null,
          promocion: null,
          comentario: null,
          precioUnitario: _cargoDelivery,
          descuentoAplicado: 0,
          precioTotalLinea: _cargoDelivery,
        ),
    ];

    // Se deja constancia de que se está enviando: si la app se cierra justo
    // ahora no se sabe si llegó al servidor y el borrador se descartará al
    // volver (mejor eso que un pedido duplicado).
    final instantanea = _armarBorrador();
    _enviandoBorrador = true;
    await guardarBorradorYEsperar(instantanea.conEnviando(true));

    var reintentar = false;
    try {
      final creado = await PedidoService.instance.crearPedido(
        pedido: pedido,
        lineas: lineas,
        mesaId: _mesaId,
        mesaNumero: esMesa ? mesaNumero : null,
        tipoEntrega: widget.tipo, // 'mesa', 'llevar' o 'delivery'
        comentarios: _notasController.text.trim().isNotEmpty
            ? _notasController.text.trim()
            : null,
        esPersonal: _esPersonal,
      );

      // El pedido ya está en el servidor: el borrador se borra de inmediato del
      // dispositivo (si no, volvería a aparecer y se podría enviar dos veces).
      _descartado = true;
      await descartarBorradorYEsperar();

      // Con el servidor nuevo el id lo asigna el backend.
      final pedidoId = creado.id;
      DisponibilidadService.instance.cargarHoy();
      // Familia: cuenta cero, con descuento del 100 % desde el inicio.
      if (widget.esFamilia) {
        try {
          await PedidoMozoService.instance.aplicarDescuento(
            pedidoId,
            motivo: 'Cuenta cero',
            porcentaje: true,
            valor: 100,
          );
        } catch (_) {
          if (mounted) {
            showAppToast(
              context,
              'El pedido se creó, pero no se pudo aplicar la cuenta cero. '
              'Aplícala desde Descuento.',
              type: ToastType.error,
            );
          }
        }
      }
      establecerPropinaPedido(pedidoId, _propina);
      if (_tupperTotal > 0) {
        establecerTupperPedido(
          pedidoId,
          grande: _tupper.grande,
          precioGrande: _tupper.precioGrande,
          mediano: _tupper.mediano,
          precioMediano: _tupper.precioMediano,
        );
      }
      if (esMesa) actualizarEstadoMesa(mesaNumero, 'ocupada');
      for (final l in lineas) {
        if (l.cartaId != cartaIdCargoDelivery && l.cartaId != cartaIdAjuste) {
          registrarConsumoAutomaticoDeLinea(l);
        }
      }

      await CatalogService.instance.cargarMesas();

      if (!mounted) return;
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
      _descartarBorrador();
      widget.onTerminar(true);
    } catch (e) {
      // No se envió: el borrador vuelve a quedar como un pedido a medias.
      _enviandoBorrador = false;
      if (!_descartado) {
        borradorPedido = instantanea.conEnviando(false);
      }
      if (!mounted) return;
      final falta = ErrorDisponibilidad.tryParse(e.toString());
      if (falta?.plato != null) {
        reintentar = await _resolverFaltaDeStock(falta!);
      } else {
        showAppToast(
          context,
          'Error al confirmar pedido: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _confirmando = false);
      }
    }
    if (reintentar && mounted) await _confirmar();
  }

  // El backend rechazó el pedido porque un plato se agotó o no alcanza. Deja
  // elegir qué hacer con esa fila y devuelve true si hay que reenviar.
  Future<bool> _resolverFaltaDeStock(ErrorDisponibilidad falta) async {
    DisponibilidadService.instance.cargarHoy();
    final nombre = falta.plato!.toLowerCase();
    final index = _carrito.indexWhere(
      (l) => l.nombrePlato.toLowerCase() == nombre,
    );
    if (index == -1) {
      showAppToast(
        context,
        falta.motivo == MotivoStock.agotado
            ? '"${falta.plato}" se agotó.'
            : 'No alcanza el stock de "${falta.plato}".',
        type: ToastType.error,
      );
      return false;
    }
    final linea = _carrito[index];
    final quedan = falta.disponibles ?? 0;
    final puedeReducir =
        falta.motivo == MotivoStock.insuficiente &&
        quedan > 0 &&
        quedan < linea.cantidad;
    final accion = await showBlurDialog<String>(
      context: context,
      builder: (dialogContext) => AlertaApp(
        title: const Text('Plato sin stock'),
        content: Text(
          puedeReducir
              ? 'Solo quedan $quedan de "${falta.plato}" y pediste '
                    '${linea.cantidad}.'
              : '"${falta.plato}" se agotó.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('quitar'),
            child: const Text('Quitar del pedido'),
          ),
          if (puedeReducir)
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop('reducir'),
              child: Text('Reducir a $quedan'),
            ),
        ],
      ),
    );
    if (accion == null || !mounted) return false;
    setState(() {
      if (accion == 'reducir') {
        _carrito[index] = linea.conCantidad(quedan);
      } else {
        _carrito.removeAt(index);
      }
    });
    return _carrito.isNotEmpty;
  }

  void _elegirMesa(Mesa mesa) {
    if (!mesa.estaLibre) {
      // Se dice de quién es, para no sumar productos a la mesa de otro mozo.
      final ocupante = pedidos
          .where((p) => p.todasLasMesas.contains(mesa.numero) && p.abierto)
          .firstOrNull;
      final mozo = ocupante == null ? '' : nombreMeseroDe(ocupante);
      showAppToast(
        context,
        mozo.isEmpty
            ? 'La mesa ${mesa.numero} está ocupada.'
            : 'La mesa ${mesa.numero} está ocupada por $mozo.',
        type: ToastType.error,
      );
      return;
    }
    setState(() {
      _mesaNumero = mesa.numero;
      _mesaId = mesa.id;
    });
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final enPasoMesa = widget.tipo == 'mesa' && _mesaNumero == null;
    final titulo = enPasoMesa
        ? 'Elige una mesa'
        : switch (widget.tipo) {
            'delivery' => 'Pedido de delivery',
            'llevar' => 'Pedido para llevar',
            _ => 'Mesa $_mesaNumero',
          };
    return LayoutBuilder(
      builder: (context, c) {
        final compacto = c.maxWidth < _anchoDosColumnas;
        // Elegir mesa: el título va a la izquierda. Armando el pedido no hay
        // título: una barra verde, pegada a los bordes de la vista, lleva el
        // buscador junto a "volver" y "x".
        // En dos columnas no hay cabecera: el buscador va arriba de la galería y
        // "volver" y "x" en el título del resumen, que sube hasta arriba.
        final cabecera = (!compacto && !enPasoMesa)
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    if (enPasoMesa)
                      Expanded(
                        child: Text(
                          titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      Flexible(child: _buscador()),
                    if (!enPasoMesa) const Spacer(),
                    const SizedBox(width: 12),
                    _botonVolver(),
                    const SizedBox(width: 8),
                    _botonCerrar(),
                  ],
                ),
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cabecera,
            Expanded(
              child: enPasoMesa
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: MesasPlano(
                        onSeleccionarMesa: _elegirMesa,
                        usuario: widget.usuario,
                      ),
                    )
                  : _armarPedido(compacto, c.maxHeight),
            ),
          ],
        );
      },
    );
  }

  // El buscador de productos, con "Plato rápido" al lado.
  Widget _buscador() => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 640),
    child: Row(
      children: [
        Expanded(
          child: AppSearchField(
            controller: _busquedaController,
            hint: 'Buscar producto...',
            onChanged: (_) => setState(() {}),
            ajustarAlTexto: false,
          ),
        ),
        const SizedBox(width: 10),
        // Mismo alto que los demás botones (Servido, Pagar...).
        OutlinedButton.icon(
          onPressed: _abrirPlatoLibre,
          icon: const Icon(LucideIcons.zap, size: 17),
          label: const Text(
            'Plato rápido',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryGreenDark,
            side: const BorderSide(color: AppColors.primaryGreen),
            minimumSize: const Size(0, AppSizes.boton),
            maximumSize: const Size(double.infinity, AppSizes.boton),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ],
    ),
  );

  // Vuelve a la vista anterior: del armado a la elección de mesa (si aplica) o
  // de ahí a la elección del tipo de pedido.
  void _volver() {
    if (widget.tipo == 'mesa' && _mesaNumero != null) {
      setState(() {
        _mesaNumero = null;
        _mesaId = null;
      });
    } else {
      _descartarBorrador();
      widget.onVolver();
    }
  }

  // Círculo de la barra de arriba: sobre la barra verde va blanco.
  BoxDecoration _circuloBoton(bool enBarra) => BoxDecoration(
    shape: BoxShape.circle,
    color: enBarra ? Colors.white : null,
    border: enBarra ? null : Border.all(color: Colors.grey.shade300),
  );

  Widget _botonVolver({bool enBarra = false}) {
    return Tooltip(
      message: 'Volver',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _volver,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: _circuloBoton(enBarra),
          child: Icon(
            LucideIcons.undo2,
            size: 16,
            color: enBarra ? AppColors.primaryGreenDark : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  // "X" para salir y volver a la cola de pedidos.
  Widget _botonCerrar({bool enBarra = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        _descartarBorrador();
        widget.onTerminar(false);
      },
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: _circuloBoton(enBarra),
        child: Icon(
          Icons.close,
          size: 18,
          color: enBarra ? AppColors.primaryGreenDark : Colors.grey.shade700,
        ),
      ),
    );
  }

  // --- Galería de productos + resumen ---

  // Por debajo de este ancho el detalle no cabe junto a la galería: pasa a una
  // hoja inferior.
  static const double _anchoDosColumnas = 820;

  Widget _armarPedido(bool compacto, double altoTotal) {
    if (compacto) {
      if (_carritoExpandido) return _detalleExpandido();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _galeria(todoEnScroll: true),
            ),
          ),
          _hojaPedido(altoTotal),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft, child: _buscador()),
                const SizedBox(height: 16),
                Expanded(child: _galeria()),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 380,
            child: _resumen(fixedFooter: true, botonesSalida: true),
          ),
        ],
      ),
    );
  }

  // Hoja inferior: resumen del pedido que crece con los productos agregados y
  // se puede abrir por completo con el ícono de expandir.
  Widget _hojaPedido(double altoTotal) {
    final cantidad = _carrito.fold<int>(0, (s, l) => s + l.cantidad);
    final tuTotal = _total;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              onTap: () => setState(() => _carritoExpandido = true),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.shoppingBag,
                      size: 18,
                      color: AppColors.primaryGreenDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _carrito.isEmpty
                            ? 'Aún no agregas productos'
                            : 'Pedido · $cantidad producto${cantidad == 1 ? '' : 's'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      'S/ ${tuTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_carrito.isNotEmpty)
                      Tooltip(
                        message: _listaOculta
                            ? 'Mostrar productos'
                            : 'Ocultar productos',
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              setState(() => _listaOculta = !_listaOculta),
                          icon: Icon(
                            _listaOculta
                                ? LucideIcons.chevronUp
                                : LucideIcons.chevronDown,
                            size: 18,
                          ),
                        ),
                      ),
                    Tooltip(
                      message: 'Ver detalle completo',
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            setState(() => _carritoExpandido = true),
                        icon: const Icon(LucideIcons.maximize2, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_carrito.isNotEmpty && !_listaOculta)
              ConstrainedBox(
                // Poca altura: la galería de productos es lo principal.
                constraints: BoxConstraints(
                  maxHeight: (altoTotal * 0.2).clamp(96.0, 150.0),
                ),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                  children: [
                    for (var i = 0; i < _carrito.length; i++)
                      _filaCarrito(i, compacta: true),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: _botonesDeAccion(),
            ),
          ],
        ),
      ),
    );
  }

  // Vista completa del detalle (campos, productos, totales y acciones) en
  // pantallas angostas: reemplaza a la galería hasta que se contrae.
  Widget _detalleExpandido() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Detalle del pedido',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _carritoExpandido = false),
                icon: const Icon(LucideIcons.minimize2, size: 16),
                label: const Text('Seguir agregando'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(child: _resumen(fixedFooter: true)),
        ],
      ),
    );
  }

  // [todoEnScroll] (celular): el buscador, las categorías y los productos se
  // desplazan juntos, para que los productos tengan toda la pantalla.
  Widget _galeria({bool todoEnScroll = false}) {
    final productos = _productos;
    final categoriasFila = _FilaDesplazable(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pillCategoria('Todos', _categoria == null, () {
            setState(() => _categoria = null);
          }),
          for (final cat in categorias)
            _pillCategoria(
              cat.categoria,
              _categoria?.id == cat.id,
              () => setState(() => _categoria = cat),
            ),
        ],
      ),
    );
    Widget grilla() => LayoutBuilder(
      builder: (context, c) {
        if (productos.isEmpty) {
          final vacio = Text(
            'Sin resultados',
            style: TextStyle(color: Colors.grey.shade500),
          );
          return todoEnScroll
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: vacio),
                )
              : Center(child: vacio);
        }
        const espacio = 12.0;
        final columnas = c.maxWidth >= 620
            ? 4
            : (c.maxWidth >= 520 ? 3 : (c.maxWidth >= 400 ? 2 : 1));
        final util = todoEnScroll ? c.maxWidth : c.maxWidth - 14;
        final ancho = (util - espacio * (columnas - 1)) / columnas;
        final tarjetas = Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final p in productos)
              SizedBox(
                width: ancho,
                child: _tarjetaProducto(p, horizontal: columnas == 1),
              ),
          ],
        );
        if (todoEnScroll) return tarjetas;
        return IndicadorAbajo(
          controller: _scrollGrilla,
          conFlecha: false,
          builder: (ctl) => SingleChildScrollView(
            controller: ctl,
            padding: const EdgeInsets.only(right: 14, bottom: 8),
            child: tarjetas,
          ),
        );
      },
    );

    if (todoEnScroll) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [categoriasFila, const SizedBox(height: 12), grilla()],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        categoriasFila,
        const SizedBox(height: 12),
        Expanded(
          child: SizedBox(width: double.infinity, child: grilla()),
        ),
      ],
    );
  }

  Widget _pillCategoria(String texto, bool activo, VoidCallback onTap) {
    return AppTag(etiqueta: texto, activo: activo, onTap: onTap);
  }

  Widget _imagen(CartaItem item) => ImagenPlato(item: item, tamanoIcono: 30);

  Widget _tarjetaProducto(CartaItem item, {bool horizontal = false}) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        disponibilidadHoyNotifier,
        configStockNotifier,
      ]),
      builder: (context, _) {
        final estado = estadoDisponibilidadDe(item.id);
        return Opacity(
          opacity: estado.vendible ? 1 : 0.55,
          child: horizontal
              ? _tarjetaProductoHorizontal(item, estado)
              : _tarjetaProductoContenido(item, estado),
        );
      },
    );
  }

  String _precioTarjeta(CartaItem item) =>
      item.precioCliente == null && precioMinimoDeVariantes(item.id) != null
      ? 'Desde S/ ${precioMinimoDeVariantes(item.id)!.toStringAsFixed(2)}'
      : 'S/ ${(item.precioCliente ?? 0).toStringAsFixed(2)}';

  // Tarjeta para celular: la imagen a la izquierda y, en la misma fila, el
  // nombre, el precio y el botón. Así se ven más productos sin desplazarse.
  Widget _tarjetaProductoHorizontal(
    CartaItem item,
    EstadoDisponibilidad estado,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(fit: StackFit.expand, children: [_imagen(item)]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.nombrePlato,
                  softWrap: true,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (estado.etiqueta != null) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: estado.vendible
                          ? AppColors.naranja
                          : AppColors.error,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      estado.etiqueta!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  _precioTarjeta(item),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 32,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: estado.vendible
                        ? () => _abrirOpciones(item)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.add, size: 15),
                    label: Text(
                      estado.vendible
                          ? 'Agregar'
                          : (estado.etiqueta ?? 'No disponible'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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

  Widget _tarjetaProductoContenido(
    CartaItem item,
    EstadoDisponibilidad estado,
  ) {
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _imagen(item),
                  if (estado.etiqueta != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: estado.vendible
                              ? AppColors.naranja
                              : AppColors.error,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          estado.etiqueta!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.nombrePlato,
            softWrap: true,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            item.precioCliente == null &&
                    precioMinimoDeVariantes(item.id) != null
                ? 'Desde S/ ${precioMinimoDeVariantes(item.id)!.toStringAsFixed(2)}'
                : 'S/ ${(item.precioCliente ?? 0).toStringAsFixed(2)}',
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
              onPressed: estado.vendible ? () => _abrirOpciones(item) : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              icon: const Icon(Icons.add, size: 15),
              label: Text(
                estado.vendible
                    ? 'Agregar al pedido'
                    : (estado.etiqueta ?? 'No disponible'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumen({required bool fixedFooter, bool botonesSalida = false}) {
    final esDelivery = widget.tipo == 'delivery';
    final tituloTipo = switch (widget.tipo) {
      'delivery' => 'Delivery',
      'llevar' => 'Para llevar',
      _ => 'Mesa $_mesaNumero',
    };
    final iconoTipo = switch (widget.tipo) {
      'delivery' => LucideIcons.bike,
      'llevar' => LucideIcons.packageCheck,
      _ => LucideIcons.utensils,
    };
    final cabeza = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(iconoTipo, size: 16, color: AppColors.primaryGreenDark),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tituloTipo.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            _botonNota(),
            if (_carrito.isNotEmpty) ...[
              const SizedBox(width: 6),
              _BotonLimpiar(onTap: () => setState(_carrito.clear)),
            ],
            if (botonesSalida) ...[
              const SizedBox(width: 8),
              _botonVolver(),
              const SizedBox(width: 6),
              _botonCerrar(),
            ],
          ],
        ),
        if (_notaVisible) ...[
          const SizedBox(height: 10),
          _campoTexto(
            controller: _notasController,
            hint: 'Ej. Sin ají, para compartir…',
            icono: Icons.edit_note,
            onChanged: (_) => setState(() {}),
            contentPaddingVertical: 14,
          ),
        ],
      ],
    );
    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // En una mesa el nombre del cliente no se pide; en un pedido de empleado
        // sí, siempre.
        if (widget.tipo != 'mesa' || _esPersonal || widget.esFamilia)
          _campoTexto(
            controller: _nombreController,
            hint: _esPersonal
                ? 'Nombre del empleado * Obligatorio'
                : (widget.esFamilia
                      ? 'Nombre del familiar * Obligatorio'
                      : 'Nombre del cliente * Obligatorio'),
            icono: Icons.person_outline,
            contentPaddingVertical: 16,
          ),
        // Pedido de empleado: el botón para escribir su precio va justo después
        // del nombre.
        if (_puedePersonal && _esPersonal) ...[
          const SizedBox(height: 10),
          _botonPrecioEmpleado(),
        ],
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
          const SizedBox(height: 10),
          _campoTexto(
            controller: _referenciaController,
            hint: 'Referencia (opcional)',
            icono: Icons.signpost_outlined,
            contentPaddingVertical: 16,
          ),
          const SizedBox(height: 10),
          _campoTexto(
            controller: _envioController,
            hint: 'Monto del delivery (S/) * Obligatorio',
            icono: Icons.delivery_dining_outlined,
            teclado: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            contentPaddingVertical: 16,
          ),
        ],
        if (widget.tipo != 'mesa' || _esPersonal || widget.esFamilia)
          const SizedBox(height: 14),
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
      ],
    );
    final pie = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DottedDivider(),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _filaTotal('Subtotal', _subtotal, fuerte: false),
              if (_cargoDelivery > 0) ...[
                const SizedBox(height: 6),
                _filaTotal('Cargo por delivery', _cargoDelivery, fuerte: false),
              ],
              if (_propina > 0) ...[const SizedBox(height: 6), _filaPropina()],
              if (_tupperTotal > 0) ...[
                const SizedBox(height: 6),
                _filaTupper(),
              ],
              const SizedBox(height: 10),
              _filaTotal('Total', _total, fuerte: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Agregar al pedido',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        // Alineados a la izquierda; si no caben, bajan a otra línea.
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            alignment: WrapAlignment.start,
            runSpacing: 8,
            children: [
              AppTag(
                etiqueta: 'Promoción',
                icono: LucideIcons.tag,
                activo: false,
                color: AppColors.naranja,
                onTap: _abrirPromocion,
              ),
              AppTag(
                etiqueta: 'Táper',
                icono: LucideIcons.package,
                activo: false,
                color: Colors.black87,
                colorBorde: Colors.grey.shade300,
                onTap: _abrirTupper,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _botonesDeAccion(),
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
          children: [
            cabeza,
            const SizedBox(height: 16),
            contenido,
            const SizedBox(height: 14),
            pie,
          ],
        ),
      );
    }
    return Container(
      decoration: decoracion,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: cabeza,
          ),
          Expanded(
            child: IndicadorAbajo(
              controller: _scrollResumen,
              builder: (ctl) => SingleChildScrollView(
                controller: ctl,
                padding: const EdgeInsets.fromLTRB(16, 0, 22, 8),
                child: contenido,
              ),
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

  // Confirmar el pedido. La comanda sale sola a la impresora de cocina al
  // confirmar (la manda el backend), por eso no hay botón de imprimir aquí.
  Widget _botonesDeAccion() {
    return FilledButton(
      onPressed: (_carrito.isEmpty || _confirmando) ? null : _confirmar,
      style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
      child: _confirmando
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'Confirmar pedido',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
    );
  }

  // Propina para el mesero: sale en el card del subtotal, con editar y quitar.
  Widget _filaPropina() {
    final estilo = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Colors.grey.shade600,
    );
    return Row(
      children: [
        Expanded(child: Text('Propina', style: estilo)),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _abrirPropina,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              LucideIcons.pencil,
              size: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('S/ ${_propina.toStringAsFixed(2)}', style: estilo),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _propina = 0),
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(Icons.close, size: 14, color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }

  // Tupper para llevar: sale en el card del subtotal, con editar y quitar.
  Widget _filaTupper() {
    final estilo = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Colors.grey.shade600,
    );
    return Row(
      children: [
        Expanded(child: Text('Táper', style: estilo)),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _abrirTupper,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              LucideIcons.pencil,
              size: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('S/ ${_tupperTotal.toStringAsFixed(2)}', style: estilo),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _tupper = _sinTupper),
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(Icons.close, size: 14, color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }

  // Con el servidor, el táper sale del catálogo y entra al pedido como una fila
  // más (el servidor la cobra y la cuenta en caja). Sin catálogo de tápers se
  // usa el táper local de la app (grande o mediano).
  Future<void> _abrirTupper() async {
    final catalogo = CatalogService.instance.tapers
        .where((t) => t.estado)
        .toList();
    if (catalogo.isNotEmpty) {
      await _abrirTapersDelCatalogo(catalogo);
      return;
    }
    await _abrirTupperLocal();
  }

  Future<void> _abrirTapersDelCatalogo(List<Taper> catalogo) async {
    final actuales = {
      for (final l in _carrito.where(esLineaTaper))
        if (l.taperId != null) l.taperId!: l.cantidad,
    };
    final elegidos = await showBlurDialog<List<TaperElegido>>(
      context: context,
      builder: (_) =>
          TaperCatalogoDialog(tapers: catalogo, iniciales: actuales),
    );
    if (elegidos == null || !mounted) return;
    setState(() {
      _carrito.removeWhere(esLineaTaper);
      for (final e in elegidos) {
        _carrito.add(lineaDeTaper(e.taper, e.cantidad));
      }
    });
  }

  Future<void> _abrirTupperLocal() async {
    final r = await showBlurDialog<TupperConfigurado>(
      context: context,
      builder: (_) =>
          TupperDialog(grande: _tupper.grande, mediano: _tupper.mediano),
    );
    if (r == null || !mounted) return;
    setState(() => _tupper = r);
  }

  Future<void> _abrirPropina() async {
    final monto = await showBlurDialog<double>(
      context: context,
      builder: (_) => PropinaDialog(base: _subtotal, actual: _propina),
    );
    if (monto == null || !mounted) return;
    setState(() => _propina = monto);
  }

  // Fila del carrito para una línea del pedido.
  // Una línea del carrito en una sola fila (para la hoja de abajo en celular):
  // nombre, precio con lo elegido y los controles.
  Widget _filaCarritoCompacta(int index) {
    final linea = _carrito[index];
    final detalle = [
      'S/ ${_lineas[index].precioUnitario.toStringAsFixed(2)}',
      if (linea.variante != null) linea.variante!.nombre,
      if (linea.presentacion != null)
        '${linea.presentacion!.unidad.unidadPresentacion} ${linea.presentacion!.volumenMl}ml',
      ...linea.componentes.map((e) => e.nombre),
      ...linea.modificadores.map((m) => m.nombre),
      if (linea.comentario != null) 'nota',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 4, 2, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  linea.nombrePlato,
                  softWrap: true,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          _iconoCantidad(
            Icons.add,
            () => _cambiarCantidadLinea(index, 1),
            habilitado:
                _topeDeLinea(index) == null ||
                linea.cantidad < _topeDeLinea(index)!,
          ),
          _iconoCantidad(
            Icons.close,
            () => _quitarLineaCarrito(index),
            color: AppColors.error,
            tooltip: 'Quitar del pedido',
          ),
        ],
      ),
    );
  }

  Widget _filaCarrito(int index, {bool compacta = false}) {
    if (compacta) return _filaCarritoCompacta(index);
    final linea = _carrito[index];
    final item = cartasNotifier.value
        .where((c) => c.id == linea.cartaId)
        .firstOrNull;
    // Tocar la tarjeta vuelve a abrir el modal del producto para corregirlo
    // (no aplica a promociones, platos rápidos ni tápers).
    final editable = item != null && linea.promocion == null && !linea.esLibre;
    final tarjeta = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                  softWrap: true,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                for (final e in linea.componentes)
                  Text(
                    textoDeComponente(e),
                    style: TextStyle(
                      fontSize: 10,
                      color: e.esCambio
                          ? AppColors.naranja
                          : Colors.grey.shade500,
                    ),
                  ),
                if (linea.promocion != null &&
                    linea.componentes.any(
                      (e) =>
                          opcionesDe(e.componenteId, soloActivas: true).length >
                          1,
                    ))
                  InkWell(
                    onTap: () => _cambiarProductosPromocion(index),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        'Cambiar productos',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.naranja,
                        ),
                      ),
                    ),
                  ),
                if (linea.variante != null)
                  Text(
                    linea.variante!.nombre,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
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
                    comentarioVisible(linea.comentario!),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade500,
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'S/ ${_lineas[index].precioUnitario.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
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
          _iconoCantidad(
            Icons.add,
            () => _cambiarCantidadLinea(index, 1),
            habilitado:
                _topeDeLinea(index) == null ||
                linea.cantidad < _topeDeLinea(index)!,
          ),
          _iconoCantidad(
            Icons.close,
            () => _quitarLineaCarrito(index),
            color: AppColors.error,
            tooltip: 'Quitar del pedido',
          ),
        ],
      ),
    );
    if (!editable) return tarjeta;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _abrirOpciones(item, indice: index),
      child: tarjeta,
    );
  }

  // Botones de la fila del producto: − y + en un cuadro de esquinas suaves; la
  // "x" en un círculo rojo que se rellena al pasar o tocar.
  Widget _iconoCantidad(
    IconData icono,
    VoidCallback onTap, {
    bool habilitado = true,
    Color color = AppColors.primaryGreen,
    String? tooltip,
  }) {
    if (icono == Icons.close) {
      return _BotonQuitar(onTap: onTap, tooltip: tooltip);
    }
    const lado = 26.0;
    final esMas = icono == Icons.add;
    final colorTrazo = esMas ? AppColors.primaryGreen : Colors.grey.shade500;
    final boton = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(lado * 0.1),
        onTap: habilitado ? onTap : null,
        child: Container(
          width: lado,
          height: lado,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(lado * 0.1),
            // "+" relleno de verde con el signo blanco; "−" solo con trazo gris.
            color: esMas
                ? (habilitado ? AppColors.primaryGreen : Colors.grey.shade300)
                : null,
            border: Border.all(
              color: habilitado ? colorTrazo : Colors.grey.shade300,
            ),
          ),
          child: Icon(
            icono,
            size: 16,
            color: esMas
                ? Colors.white
                : (habilitado ? colorTrazo : Colors.grey.shade400),
          ),
        ),
      ),
    );
    return tooltip == null ? boton : Tooltip(message: tooltip, child: boton);
  }

  // ---- Precio escrito a mano para este pedido (no cambia la carta) ----
  // Se escribe en el modal de cada producto; aquí solo se guarda el precio de la
  // carta de cada línea.

  // Precio de carta de cada línea antes de cambiarlo (por id de línea).
  final Map<String, double> _precioCarta = {};

  // Empleado: cuadro con los productos, su precio y su cantidad, y un campo para
  // escribir el precio que se cobra por cada uno.
  // El botón PRECIO EMPLEADO (el mismo que se muestra en el aviso).
  Widget _botonPrecioEmpleado() => FilledButton.icon(
    onPressed: _abrirEmpleado,
    icon: const Icon(LucideIcons.users, size: 16),
    label: const Text(
      'PRECIO EMPLEADO',
      style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.4),
    ),
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF2563EB),
      minimumSize: const Size.fromHeight(AppSizes.boton),
    ),
  );

  // Aviso previo: después de agregar los productos hay que pulsar PRECIO
  // EMPLEADO; se muestra el botón tal como se verá.
  Future<void> _avisarPrecioEmpleado() async {
    const clave = 'aviso_precio_empleado_oculto';
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(clave) == true) return;
    } catch (_) {}
    if (!mounted) return;
    var noMostrar = false;
    await showBlurDialog<void>(
      context: context,
      builder: (dialogContext) => AlertaApp(
        title: const Text('Pedido de empleado'),
        content: StatefulBuilder(
          builder: (context, setAviso) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Primero agrega los productos. Después, pulsa este botón (debajo '
                'del nombre del empleado) para escribir el precio de empleado de '
                'cada plato:',
              ),
              const SizedBox(height: 14),
              IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(LucideIcons.users, size: 16),
                    label: const Text(
                      'PRECIO EMPLEADO',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      minimumSize: const Size.fromHeight(AppSizes.boton),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Para no volver a ver este aviso.
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setAviso(() => noMostrar = !noMostrar),
                child: Row(
                  children: [
                    Checkbox(
                      value: noMostrar,
                      activeColor: AppColors.primaryGreen,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => setAviso(() => noMostrar = v ?? false),
                    ),
                    const Text(
                      'No volver a mostrar',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    if (noMostrar) {
      try {
        await prefs?.setBool(clave, true);
      } catch (_) {}
    }
  }

  Future<void> _abrirEmpleado() async {
    if (_carrito.isEmpty) {
      showAppToast(
        context,
        'Agrega primero los productos del pedido.',
        type: ToastType.info,
      );
      return;
    }
    final r = await showBlurDialog<_PreciosEmpleado>(
      context: context,
      builder: (_) => _EmpleadoPreciosDialog(
        lineas: List.of(_carrito),
        precios: Map.of(_preciosPersonal),
        activo: _esPersonal,
      ),
    );
    if (r == null || !mounted) return;
    setState(() {
      _esPersonal = r.activar;
      _preciosPersonal
        ..clear()
        ..addAll(r.activar ? r.precios : const {});
    });
  }

  // Nota del pedido: el botón "+ Nota" habilita el campo ahí mismo.
  bool _notaAbierta = false;

  // Barra de desplazamiento visible de la galería de productos.
  final ScrollController _scrollGrilla = ScrollController();
  final ScrollController _scrollResumen = ScrollController();

  bool get _notaVisible =>
      _notaAbierta || _notasController.text.trim().isNotEmpty;

  Widget _botonNota() {
    final visible = _notaVisible;
    return OutlinedButton.icon(
      onPressed: () => setState(() {
        if (visible) _notasController.clear();
        _notaAbierta = !visible;
      }),
      icon: Icon(visible ? Icons.close : Icons.add, size: 15),
      label: const Text('Nota'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black87,
        side: BorderSide(color: Colors.grey.shade600, width: 1.3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
          child: Text(
            etiqueta,
            style: estilo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${valor < 0 ? '-' : ''}S/ ${valor.abs().toStringAsFixed(2)}',
          style: estilo,
        ),
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
    return CampoTexto(
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
        prefixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 18,
        ),
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

// "Borrar": trazo gris de bordes redondeados; al pasar el cursor o tocarlo se
// vuelve rojo con el texto blanco.
class _BotonLimpiar extends StatefulWidget {
  final VoidCallback onTap;

  const _BotonLimpiar({required this.onTap});

  @override
  State<_BotonLimpiar> createState() => _BotonLimpiarState();
}

class _BotonLimpiarState extends State<_BotonLimpiar> {
  bool _hover = false;
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    final activo = _hover || _presionado;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _presionado = true),
        onTapUp: (_) => setState(() => _presionado = false),
        onTapCancel: () => setState(() => _presionado = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: activo ? AppColors.error : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activo ? AppColors.error : Colors.grey.shade400,
            ),
          ),
          child: Text(
            'Borrar',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: activo ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}

// "x" de quitar un producto: círculo con trazo rojo; al pasar el cursor o
// tocarlo se rellena de rojo y la "x" se vuelve blanca.
class _BotonQuitar extends StatefulWidget {
  final VoidCallback onTap;
  final String? tooltip;

  const _BotonQuitar({required this.onTap, this.tooltip});

  @override
  State<_BotonQuitar> createState() => _BotonQuitarState();
}

class _BotonQuitarState extends State<_BotonQuitar> {
  bool _hover = false;
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    final activo = _hover || _presionado;
    final boton = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _presionado = true),
        onTapUp: (_) => setState(() => _presionado = false),
        onTapCancel: () => setState(() => _presionado = false),
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activo ? AppColors.error : Colors.transparent,
              border: Border.all(color: AppColors.error),
            ),
            child: Icon(
              Icons.close,
              size: 14,
              color: activo ? Colors.white : AppColors.error,
            ),
          ),
        ),
      ),
    );
    return widget.tooltip == null
        ? boton
        : Tooltip(message: widget.tooltip!, child: boton);
  }
}

// Resultado del cuadro de Empleado: si el pedido queda como de empleado y los
// precios escritos (id de la línea -> precio por unidad).
typedef _PreciosEmpleado = ({bool activar, Map<String, double> precios});

// Cuadro del botón Empleado: lista los productos del pedido con su precio y su
// cantidad, y un campo para escribir el precio que se cobra por cada uno. Los
// que se dejan en blanco quedan al precio de la carta.
class _EmpleadoPreciosDialog extends StatefulWidget {
  final List<PedidoLine> lineas;
  final Map<String, double> precios;
  final bool activo;

  const _EmpleadoPreciosDialog({
    required this.lineas,
    required this.precios,
    required this.activo,
  });

  @override
  State<_EmpleadoPreciosDialog> createState() => _EmpleadoPreciosDialogState();
}

class _EmpleadoPreciosDialogState extends State<_EmpleadoPreciosDialog> {
  late final Map<String, TextEditingController> _campos = {
    for (final l in widget.lineas)
      l.id: TextEditingController(
        text: widget.precios[l.id]?.toStringAsFixed(2) ?? '',
      ),
  };

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    final precios = <String, double>{};
    _campos.forEach((id, campo) {
      final v = double.tryParse(campo.text.trim().replaceAll(',', '.'));
      if (v != null && v >= 0) precios[id] = v;
    });
    Navigator.of(context)
        .pop<_PreciosEmpleado>((activar: true, precios: precios));
  }

  @override
  Widget build(BuildContext context) {
    return ModalPago(
      titulo: 'Pedido de empleado',
      subtitulo: 'Escribe el precio que se cobra por cada producto',
      anchoEscritorio: 520,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final l in widget.lineas)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.nombrePlato,
                            softWrap: true,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Precio S/ ${l.precioUnitario.toStringAsFixed(2)} · '
                            'Cantidad ${l.cantidad}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 110,
                      child: CampoTexto(
                        controller: _campos[l.id],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'S/.',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.activo)
                  TextButton(
                    onPressed: () => Navigator.of(context)
                        .pop<_PreciosEmpleado>((activar: false, precios: {})),
                    child: const Text('Quitar precio de empleado'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _guardar,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Fila que se desplaza en horizontal con botones circulares < y > a los lados;
// cada botón solo aparece si hay más contenido hacia ese lado.
class _FilaDesplazable extends StatefulWidget {
  final Widget child;

  const _FilaDesplazable({required this.child});

  @override
  State<_FilaDesplazable> createState() => _FilaDesplazableState();
}

class _FilaDesplazableState extends State<_FilaDesplazable> {
  final _scroll = ScrollController();
  bool _izq = false;
  bool _der = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_medir);
    WidgetsBinding.instance.addPostFrameCallback((_) => _medir());
  }

  @override
  void didUpdateWidget(covariant _FilaDesplazable old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _medir());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _medir() {
    if (!mounted || !_scroll.hasClients) return;
    final m = _scroll.position;
    final izq = m.pixels > 1;
    final der = m.pixels < m.maxScrollExtent - 1;
    if (izq != _izq || der != _der) {
      setState(() {
        _izq = izq;
        _der = der;
      });
    }
  }

  void _mover(double signo) {
    final destino = (_scroll.offset + signo * 240).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      destino,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  // Franja que difumina lo que hay debajo de la flecha.
  Widget _conDifuminado(Widget flecha, {required bool izquierda}) {
    const fondo = AppColors.background;
    return Positioned(
      left: izquierda ? 0 : null,
      right: izquierda ? null : 0,
      top: 0,
      bottom: 0,
      child: Container(
        width: 56,
        alignment: izquierda ? Alignment.centerLeft : Alignment.centerRight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: izquierda ? Alignment.centerLeft : Alignment.centerRight,
            end: izquierda ? Alignment.centerRight : Alignment.centerLeft,
            colors: [
              fondo,
              fondo.withValues(alpha: 0.9),
              fondo.withValues(alpha: 0),
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: flecha,
      ),
    );
  }

  Widget _flecha(IconData icono, String tip, VoidCallback onTap) => Tooltip(
    message: tip,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(icono, size: 18, color: Colors.grey.shade800),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _medir());
        return false;
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: widget.child,
          ),
          if (_izq)
            _conDifuminado(
              _flecha(Icons.chevron_left, 'Anterior', () => _mover(-1)),
              izquierda: true,
            ),
          if (_der)
            _conDifuminado(
              _flecha(Icons.chevron_right, 'Siguiente', () => _mover(1)),
              izquierda: false,
            ),
        ],
      ),
    );
  }
}

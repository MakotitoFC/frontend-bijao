import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/cartas_store.dart';
import '../data/disponibilidad_store.dart';
import '../data/presentaciones_store.dart';
import '../data/variantes_store.dart';
import '../models/carta_item.dart';
import '../models/carta_presentacion.dart';
import '../models/carta_variante.dart';
import '../models/modificador.dart';
import '../models/pedido_line.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';
import 'app_tag.dart';
import 'app_toast.dart';
import 'imagen_plato.dart';
import 'taper_catalogo_dialog.dart' show TaperElegido;
import '../utils/agregados_utils.dart';
import 'dialogo_app.dart';
import 'campo_texto.dart';

// Resultado al agregar un producto configurado al pedido.
typedef ProductoConfigurado = ({
  int cantidad,
  CartaPresentacion? presentacion,
  CartaVariante? variante,
  List<Modificador> modificadores,
  String? comentario,
  double precioUnitario,
  String tipoEntrega,
  bool llevaTaper,
  String? taperId,
  double precioTaper,
  // Cuántos tápers se llevan (null = uno por unidad) y el total de la línea.
  int? cantidadTaper,
  double totalLinea,
  // Los demás tápers elegidos (el primero va en la línea del plato): cada uno
  // se agrega como una fila propia con su cantidad.
  List<TaperElegido> tapersAdicionales,
  // El precio se escribió a mano para este pedido; [precioOriginal] es el de la
  // carta antes del cambio.
  bool precioManual,
  double precioOriginal,
});

// Modal "Agregar al pedido": presentación, extras opcionales y nota.
class ProductoOpcionesDialog extends StatefulWidget {
  final CartaItem item;
  final bool esAdmin;
  // Color del botón principal (ej. naranja para promociones).
  final Color? acento;
  // Productos que ya están en el carrito (aún sin guardar): cuentan contra las
  // porciones que quedan hoy.
  final List<PedidoLine> enCarrito;
  // Tipo del pedido en curso ('mesa', 'llevar' o 'delivery'): el producto
  // arranca con esa entrega, que se puede cambiar producto por producto.
  final String tipoEntregaInicial;
  // Deja cambiar el precio (con su motivo) solo para este pedido.
  final bool permitePrecioManual;
  // Línea del carrito que se está corrigiendo: el modal abre con sus datos.
  final PedidoLine? lineaInicial;

  const ProductoOpcionesDialog({
    super.key,
    required this.item,
    required this.esAdmin,
    this.acento,
    this.enCarrito = const [],
    this.tipoEntregaInicial = 'mesa',
    this.permitePrecioManual = false,
    this.lineaInicial,
  });

  @override
  State<ProductoOpcionesDialog> createState() => _ProductoOpcionesDialogState();
}

class _ProductoOpcionesDialogState extends State<ProductoOpcionesDialog> {
  late final List<CartaPresentacion> _presentaciones = presentaciones
      .where((p) => p.cartaId == widget.item.id)
      .toList();
  CartaPresentacion? _presentacion;
  // Tamaños con precio propio (`carta_variante`): si el plato los tiene, se
  // elige uno y reemplaza a las presentaciones.
  late final List<CartaVariante> _variantes = variantesDeCarta(
    widget.item.id,
    soloActivas: true,
  );
  CartaVariante? _variante;
  final Set<String> _agregadosElegidos = {};
  // Selección por grupo de extras: nombre del grupo -> ítems elegidos.
  final Map<String, Set<String>> _seleccionPorGrupo = {};
  final _comentarioController = TextEditingController();
  int _cantidad = 1;

  String _tipoEntrega = 'mesa'; // 'mesa', 'llevar', 'delivery'
  late final List<Map<String, dynamic>> _extrasSimples = agregadosSimples(
    widget.item.agregados,
  );
  late final List<Map<String, dynamic>> _grupos = gruposDeAgregados(
    widget.item.agregados,
  );

  @override
  void initState() {
    super.initState();
    if (_variantes.isNotEmpty) {
      _variante = _variantes.first;
    } else if (_presentaciones.isNotEmpty) {
      _presentacion = _presentaciones.first;
    }
    // Entrega según el pedido en curso (lo mismo que hace tocar el chip).
    final inicial = widget.tipoEntregaInicial;
    if (inicial == 'llevar' || inicial == 'delivery') {
      _tipoEntrega = inicial;
    }
    final l = widget.lineaInicial;
    if (l != null) _restaurar(l);
  }

  // Abre el modal con lo que ya tenía la línea del carrito.
  void _restaurar(PedidoLine l) {
    _cantidad = l.cantidad;
    _tipoEntrega = l.tipoEntrega;
    if (l.variante != null) {
      _variante =
          _variantes.where((v) => v.id == l.variante!.id).firstOrNull ??
          _variante;
    }
    if (l.presentacion != null) {
      _presentacion =
          _presentaciones
              .where((p) => p.id == l.presentacion!.id)
              .firstOrNull ??
          _presentacion;
    }
    // Extras elegidos.
    for (final m in l.modificadores) {
      if (_extrasSimples.any((a) => '${a['nombre']}' == m.nombre)) {
        _agregadosElegidos.add(m.nombre);
      }
      for (final g in _grupos) {
        if (m.id == '${widget.item.id}-${nombreGrupo(g)}-${m.nombre}') {
          _seleccionPorGrupo
              .putIfAbsent(nombreGrupo(g), () => {})
              .add(m.nombre);
        }
      }
    }
    // La nota y, aparte, el motivo del precio.
    const marca = 'Precio manual: ';
    final lineas = (l.comentario ?? '').split('\n');
    _comentarioController.text = lineas
        .where((x) => !x.startsWith(marca))
        .join('\n')
        .trim();
    final motivo = lineas
        .where((x) => x.startsWith(marca))
        .map((x) => x.substring(marca.length))
        .join(' ')
        .trim();
    if (l.precioManual && motivo.isNotEmpty) {
      _precioManual = l.precioUnitario;
      _motivoPrecio = motivo;
      final cambio = RegExp(r'^Cambio por (.+) \(\+S/ ([0-9.]+)\)$')
          .firstMatch(motivo);
      if (cambio != null) {
        _platoCambio = cambio.group(1);
        _adicionalCtrl.text = cambio.group(2)!;
      } else {
        _editandoPrecio = true;
        _precioCtrl.text = l.precioUnitario.toStringAsFixed(2);
        _motivoCtrl.text = motivo;
      }
    }
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    _precioCtrl.dispose();
    _motivoCtrl.dispose();
    _adicionalCtrl.dispose();
    super.dispose();
  }

  // Precio escrito a mano para este pedido y su motivo (null = el de la carta).
  double? _precioManual;
  String? _motivoPrecio;

  double get _precioUnitario => _precioManual ?? _precioCalculado;

  bool get _esFamiliar =>
      (widget.item.categoriaNombre ?? '').toLowerCase().contains('familiar');

  double get _precioCalculado {
    final base =
        _variante?.precioCliente ??
        _presentacion?.precioCliente ??
        widget.item.precioCliente ??
        0;
    final extrasSimples = _extrasSimples
        .where((a) => _agregadosElegidos.contains('${a['nombre']}'))
        .fold(0.0, (s, a) => s + (precioDeAgregado(a) ?? 0));
    final extrasGrupos = _grupos.fold(0.0, (s, g) {
      final elegidos = _seleccionPorGrupo[nombreGrupo(g)] ?? const {};
      return s +
          itemsDeGrupo(g)
              .where((it) => elegidos.contains('${it['nombre']}'))
              .fold(0.0, (s2, it) => s2 + (precioDeAgregado(it) ?? 0));
    });
    return base + extrasSimples + extrasGrupos;
  }

  double get _total => _precioUnitario * _cantidad;

  // Porciones que aún se pueden agregar de lo elegido (null = sin tope).
  int? get _tope {
    final quedan = topeDeUnidades(
      widget.item.id,
      presentacionId: _presentacion?.id,
      varianteId: _variante?.id,
    );
    if (quedan == null) return null;
    final ya = widget.enCarrito
        .where(
          (l) =>
              l.cartaId == widget.item.id &&
              l.presentacion?.id == _presentacion?.id &&
              l.variante?.id == _variante?.id,
        )
        .fold(0, (s, l) => s + l.cantidad);
    return quedan - ya < 0 ? 0 : quedan - ya;
  }

  void _alternarAgregado(String nombre) {
    setState(() {
      if (_agregadosElegidos.contains(nombre)) {
        _agregadosElegidos.remove(nombre);
        return;
      }
      final limite = widget.item.limiteAgregados;
      if (limite != null && _agregadosElegidos.length >= limite) {
        return;
      }
      _agregadosElegidos.add(nombre);
    });
  }

  void _alternarAgregadoGrupo(String grupo, String nombre, int cantidadMaxima) {
    setState(() {
      final elegidos = _seleccionPorGrupo.putIfAbsent(grupo, () => {});
      if (elegidos.contains(nombre)) {
        elegidos.remove(nombre);
        return;
      }
      if (elegidos.length >= cantidadMaxima) return;
      elegidos.add(nombre);
    });
  }

  void _confirmar() {
    final tope = _tope;
    if (tope != null && _cantidad > tope) {
      showAppToast(
        context,
        tope == 0
            ? '"${widget.item.nombrePlato}" ya no tiene porciones disponibles.'
            : 'Solo quedan $tope de "${widget.item.nombrePlato}".',
        type: ToastType.error,
      );
      return;
    }
    final modificadores = [
      for (final a in _extrasSimples)
        if (_agregadosElegidos.contains('${a['nombre']}'))
          Modificador(
            id: '${widget.item.id}-${a['nombre']}',
            cartaId: widget.item.id,
            nombre: '${a['nombre']}',
            tipo: 'agregar',
            precioAjuste: precioDeAgregado(a) ?? 0,
          ),
      for (final g in _grupos)
        for (final it in itemsDeGrupo(g))
          if ((_seleccionPorGrupo[nombreGrupo(g)] ?? const {}).contains(
            '${it['nombre']}',
          ))
            Modificador(
              id: '${widget.item.id}-${nombreGrupo(g)}-${it['nombre']}',
              cartaId: widget.item.id,
              nombre: '${it['nombre']}',
              tipo: 'agregar',
              precioAjuste: precioDeAgregado(it) ?? 0,
            ),
    ];
    final totalLinea = _precioUnitario * _cantidad;
    Navigator.of(context).pop<ProductoConfigurado>((
      cantidad: _cantidad,
      presentacion: _presentacion,
      variante: _variante,
      modificadores: modificadores,
      comentario: _comentarioFinal,
      precioUnitario: totalLinea / _cantidad,
      tipoEntrega: _tipoEntrega,
      // El táper se agrega después, desde el detalle del pedido.
      llevaTaper: false,
      taperId: null,
      precioTaper: 0.0,
      cantidadTaper: null,
      totalLinea: totalLinea,
      tapersAdicionales: const [],
      precioManual: _precioManual != null,
      precioOriginal: _precioCalculado,
    ));
  }

  // La nota del producto, más el motivo del precio si se cambió.
  String? get _comentarioFinal {
    final nota = _comentarioController.text.trim();
    final motivo = _motivoPrecio == null ? '' : 'Precio manual: $_motivoPrecio';
    final partes = [nota, motivo].where((x) => x.isNotEmpty).join('\n');
    return partes.isEmpty ? null : partes;
  }

  // ---- Precio a mano y cambio de plato, en el mismo modal (sin otros modales) ----

  bool _editandoPrecio = false;
  final _precioCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  String? _platoCambio;
  final _adicionalCtrl = TextEditingController();

  double _leer(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.')) ?? -1;

  // Platos entre los que se puede cambiar un plato familiar: sus variantes y,
  // si no tiene, los demás platos de la carta.
  List<String> get _opcionesDeCambio => _variantes.isNotEmpty
      ? [for (final v in _variantes) v.nombre]
      : [
          for (final c in cartasNotifier.value)
            if (c.id != widget.item.id) c.nombrePlato,
        ];

  // Vuelve a calcular el precio manual con lo escrito: el precio con su motivo
  // o, si no, el cambio de plato con su adicional.
  void _recalcularManual() {
    final p = _leer(_precioCtrl.text);
    final motivo = _motivoCtrl.text.trim();
    final extra = _leer(_adicionalCtrl.text);
    setState(() {
      if (_editandoPrecio && p >= 0 && motivo.isNotEmpty) {
        _precioManual = p;
        _motivoPrecio = motivo;
      } else if (_platoCambio != null && extra >= 0) {
        _precioManual = _precioCalculado + extra;
        _motivoPrecio =
            'Cambio por $_platoCambio (+S/ ${extra.toStringAsFixed(2)})';
      } else {
        _precioManual = null;
        _motivoPrecio = null;
      }
    });
  }

  // El precio se cambió pero falta el motivo (o el cambio de plato está a
  // medias): no se puede agregar todavía.
  bool get _falta {
    if (_editandoPrecio) {
      final p = _leer(_precioCtrl.text);
      final cambio = p >= 0 && (p - _precioCalculado).abs() > 0.004;
      if ((cambio || _motivoCtrl.text.trim().isNotEmpty) &&
          (_motivoCtrl.text.trim().isEmpty || p < 0)) {
        return true;
      }
    }
    if (_esFamiliar) {
      final extra = _leer(_adicionalCtrl.text);
      final escribioExtra = _adicionalCtrl.text.trim().isNotEmpty;
      if (_platoCambio != null && extra < 0) return true;
      if (_platoCambio == null && escribioExtra) return true;
    }
    return false;
  }

  void _alternarEdicionPrecio() {
    setState(() {
      _editandoPrecio = !_editandoPrecio;
      if (_editandoPrecio) {
        _precioCtrl.text = _precioUnitario.toStringAsFixed(2);
      } else {
        _precioCtrl.clear();
        _motivoCtrl.clear();
      }
    });
    _recalcularManual();
  }

  // Campo de texto de una sola línea del modal.
  Widget _campoLinea(
    TextEditingController ctrl,
    String hint, {
    bool numero = false,
    String? prefijo,
  }) => SizedBox(
    height: AppSizes.boton,
    child: CampoTexto(
      controller: ctrl,
      expands: true,
      maxLines: null,
      keyboardType: numero
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      onChanged: (_) => _recalcularManual(),
      decoration: InputDecoration(hintText: hint, prefixText: prefijo),
    ),
  );

  Widget _precioEnLinea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_editandoPrecio) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _campoLinea(
                  _precioCtrl,
                  'Precio',
                  numero: true,
                  prefijo: 'S/ ',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: _campoLinea(_motivoCtrl, 'Motivo del cambio'),
              ),
            ],
          ),
        ],
        if (_falta)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Escribe el motivo del cambio (y completa el cambio de plato) '
              'para poder agregarlo.',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
        if (_esFamiliar) ...[
          const SizedBox(height: 14),
          const Text(
            'Cambio de plato',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: AppSelect<String>(
                  compacto: true,
                  buscable: true,
                  value: _platoCambio,
                  hint: 'Plato que se cambia',
                  items: [
                    for (final n in _opcionesDeCambio)
                      AppSelectItem(value: n, label: n),
                  ],
                  onChanged: (v) {
                    _platoCambio = v;
                    _recalcularManual();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _campoLinea(
                  _adicionalCtrl,
                  'Adicional',
                  numero: true,
                  prefijo: 'S/ ',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final tam = MediaQuery.sizeOf(context);
    final limite = widget.item.limiteAgregados;
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: esMobile ? tam.width : 400,
          maxHeight: esMobile
              ? tam.height * 0.9
              : (tam.height * 0.85).clamp(420.0, 680.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, esMobile ? 20 : 16, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.nombrePlato,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  BotonCerrarCircular(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SeparadorDialogo(aire: 12),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.item.descripcion,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 84,
                            height: 84,
                            child: _imagen(widget.item),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          'S/ ${_precioUnitario.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (widget.permitePrecioManual) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Cambiar el precio',
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _alternarEdicionPrecio,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  LucideIcons.pencil,
                                  size: 16,
                                  color: _precioManual != null
                                      ? AppColors.naranja
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          if (_precioManual != null)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _editandoPrecio = false;
                                  _platoCambio = null;
                                  _precioCtrl.clear();
                                  _motivoCtrl.clear();
                                  _adicionalCtrl.clear();
                                });
                                _recalcularManual();
                              },
                              child: const Text('Quitar cambio'),
                            ),
                        ],
                      ],
                    ),
                    if (_motivoPrecio != null)
                      Text(
                        _motivoPrecio!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.naranja,
                        ),
                      ),
                    if (widget.permitePrecioManual) _precioEnLinea(),
                    // Las variantes ya no se muestran: si el plato aún tiene,
                    // se usa la primera (su precio) sin preguntar.
                    if (_variantes.isEmpty && _presentaciones.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _tituloSeccion(
                        'Elige la presentación',
                        obligatorio: true,
                      ),
                      const SizedBox(height: 6),
                      for (final p in _presentaciones) _filaRadio(p),
                    ],
                    if (_extrasSimples.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _tituloSeccion(
                        'Extras opcionales',
                        subtitulo: limite != null
                            ? 'Selecciona hasta $limite opción(es)'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final a in _extrasSimples) _tagAgregado(a),
                        ],
                      ),
                    ],
                    for (final g in _grupos) ...[
                      const SizedBox(height: 18),
                      _tituloSeccion(
                        nombreGrupo(g),
                        subtitulo:
                            'Selecciona hasta ${cantidadMaximaGrupo(g) ?? 1} opción(es)',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final it in itemsDeGrupo(g))
                            _tagAgregadoGrupo(g, it),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    _selectorTipoEntrega(),
                    const SizedBox(height: 18),
                    _tituloSeccion('Notas (opcional)'),
                    const SizedBox(height: 6),
                    CampoTexto(
                      controller: _comentarioController,
                      maxLength: 60,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Notas para este producto (opcional)',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  _botonCantidad(
                    Icons.remove,
                    _cantidad > 1 ? () => setState(() => _cantidad--) : null,
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$_cantidad',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _botonCantidad(
                    Icons.add,
                    (_tope == null || _cantidad < _tope!)
                        ? () => setState(() => _cantidad++)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _falta ? null : _confirmar,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            widget.acento ?? AppColors.primaryGreen,
                      ),
                      child: Text(
                        '${widget.lineaInicial == null ? 'Agregar' : 'Guardar'} S/ ${_total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectorTipoEntrega() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('Tipo de entrega'),
        const SizedBox(height: 8),
        Row(
          children: [
            _chipTipoEntrega('mesa', 'En mesa', LucideIcons.utensils),
            const SizedBox(width: 8),
            _chipTipoEntrega('llevar', 'Para llevar', LucideIcons.packageCheck),
            const SizedBox(width: 8),
            _chipTipoEntrega('delivery', 'Delivery', LucideIcons.bike),
          ],
        ),
      ],
    );
  }

  Widget _chipTipoEntrega(String tipo, String etiqueta, IconData icono) {
    final activo = _tipoEntrega == tipo;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _tipoEntrega = tipo);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activo
                ? AppColors.primaryGreen.withValues(alpha: 0.12)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: activo ? AppColors.primaryGreen : Colors.grey.shade300,
              width: activo ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icono,
                size: 14,
                color: activo
                    ? AppColors.primaryGreenDark
                    : Colors.grey.shade700,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  etiqueta,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                    color: activo
                        ? AppColors.primaryGreenDark
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tituloSeccion(
    String texto, {
    String? subtitulo,
    bool obligatorio = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                texto,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              if (subtitulo != null)
                Text(
                  subtitulo,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
        if (obligatorio)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Obligatorio',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ),
      ],
    );
  }

  Widget _filaRadio(CartaPresentacion p) {
    final activo = _presentacion?.id == p.id;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _presentacion = p),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                activo ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
                color: activo ? AppColors.primaryGreen : Colors.grey.shade400,
              ),
            ),
            Expanded(
              child: Text('${p.unidad.unidadPresentacion} · ${p.volumenMl} ml'),
            ),
            Text(
              'S/ ${p.precioCliente.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                color: activo ? AppColors.primaryGreenDark : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Cada extra opcional es una tag que se activa al tocarla.
  Widget _tagAgregado(Map<String, dynamic> a) {
    final nombre = '${a['nombre']}';
    final precio = a['precio'];
    final texto = precio is num && precio > 0
        ? '$nombre +S/ ${precio.toStringAsFixed(2)}'
        : nombre;
    return AppTag(
      etiqueta: texto,
      activo: _agregadosElegidos.contains(nombre),
      onTap: () => _alternarAgregado(nombre),
    );
  }

  // Igual que `_tagAgregado`, pero para un ítem dentro de un grupo.
  Widget _tagAgregadoGrupo(
    Map<String, dynamic> grupo,
    Map<String, dynamic> it,
  ) {
    final nombreItem = '${it['nombre']}';
    final precio = it['precio'];
    final grupoNombre = nombreGrupo(grupo);
    final texto = precio is num && precio > 0
        ? '$nombreItem +S/ ${precio.toStringAsFixed(2)}'
        : nombreItem;
    return AppTag(
      etiqueta: texto,
      activo: (_seleccionPorGrupo[grupoNombre] ?? const {}).contains(
        nombreItem,
      ),
      onTap: () => _alternarAgregadoGrupo(
        grupoNombre,
        nombreItem,
        cantidadMaximaGrupo(grupo) ?? 1,
      ),
    );
  }

  Widget _botonCantidad(IconData icono, VoidCallback? onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icono,
          size: 20,
          color: onTap == null
              ? Colors.grey.shade300
              : (widget.acento ?? AppColors.primaryGreen),
        ),
      ),
    );
  }

  Widget _imagen(CartaItem item) => ImagenPlato(item: item, tamanoIcono: 26);
}

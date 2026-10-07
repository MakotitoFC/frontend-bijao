import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/presentaciones_store.dart';
import '../models/carta_item.dart';
import '../models/carta_presentacion.dart';
import '../models/modificador.dart';
import '../models/taper.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import 'app_tag.dart';
import '../utils/agregados_utils.dart';

// Resultado al agregar un producto configurado al pedido.
typedef ProductoConfigurado = ({
  int cantidad,
  CartaPresentacion? presentacion,
  List<Modificador> modificadores,
  String? comentario,
  double precioUnitario,
  String tipoEntrega,
  bool llevaTaper,
  String? taperId,
  double precioTaper,
});

// Modal "Agregar al pedido": presentación, extras opcionales y nota.
class ProductoOpcionesDialog extends StatefulWidget {
  final CartaItem item;
  final bool esAdmin;
  // Color del botón principal (ej. naranja para el plato del día).
  final Color? acento;

  const ProductoOpcionesDialog({
    super.key,
    required this.item,
    required this.esAdmin,
    this.acento,
  });

  @override
  State<ProductoOpcionesDialog> createState() => _ProductoOpcionesDialogState();
}

class _ProductoOpcionesDialogState extends State<ProductoOpcionesDialog> {
  late final List<CartaPresentacion> _presentaciones = presentaciones
      .where((p) => p.cartaId == widget.item.id)
      .toList();
  CartaPresentacion? _presentacion;
  final Set<String> _agregadosElegidos = {};
  // Selección por grupo de extras: nombre del grupo -> ítems elegidos.
  final Map<String, Set<String>> _seleccionPorGrupo = {};
  final _comentarioController = TextEditingController();
  int _cantidad = 1;

  String _tipoEntrega = 'mesa'; // 'mesa', 'llevar', 'delivery'
  bool _llevaTaper = false;
  Taper? _taperSeleccionado;

  late final List<Map<String, dynamic>> _extrasSimples = agregadosSimples(
    widget.item.agregados,
  );
  late final List<Map<String, dynamic>> _grupos = gruposDeAgregados(
    widget.item.agregados,
  );

  @override
  void initState() {
    super.initState();
    if (_presentaciones.isNotEmpty) _presentacion = _presentaciones.first;
    final tapers = CatalogService.instance.tapers.where((t) => t.estado).toList();
    if (widget.item.taperId != null && widget.item.taperId!.isNotEmpty) {
      _taperSeleccionado = tapers.where((t) => t.id == widget.item.taperId).firstOrNull;
    }
    if (_taperSeleccionado == null && tapers.isNotEmpty) {
      _taperSeleccionado = tapers.first;
    }
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  double get _precioUnitario {
    final base = _presentacion?.precioCliente ?? widget.item.precioCliente ?? 0;
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
    final taperMonto = (_llevaTaper && _taperSeleccionado != null) ? _taperSeleccionado!.precio : 0.0;
    return base + extrasSimples + extrasGrupos + taperMonto;
  }

  double get _total => _precioUnitario * _cantidad;

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
    Navigator.of(context).pop<ProductoConfigurado>((
      cantidad: _cantidad,
      presentacion: _presentacion,
      modificadores: modificadores,
      comentario: _comentarioController.text.trim().isEmpty
          ? null
          : _comentarioController.text.trim(),
      precioUnitario: _precioUnitario,
      tipoEntrega: _tipoEntrega,
      llevaTaper: _llevaTaper,
      taperId: _llevaTaper ? _taperSeleccionado?.id : null,
      precioTaper: (_llevaTaper && _taperSeleccionado != null) ? _taperSeleccionado!.precio : 0.0,
    ));
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
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
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
                    Text(
                      'S/ ${_precioUnitario.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_presentaciones.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _tituloSeccion('Elige el tamaño', obligatorio: true),
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
                    const SizedBox(height: 16),
                    _selectorTaper(),
                    const SizedBox(height: 18),
                    _tituloSeccion('Notas (opcional)'),
                    const SizedBox(height: 6),
                    TextField(
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
                  _botonCantidad(Icons.add, () => setState(() => _cantidad++)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _confirmar,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            widget.acento ?? AppColors.primaryGreen,
                      ),
                      child: Text(
                        'Agregar S/ ${_total.toStringAsFixed(2)}',
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
          setState(() {
            _tipoEntrega = tipo;
            if (tipo == 'llevar' || tipo == 'delivery') {
              _llevaTaper = true;
            }
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activo ? AppColors.primaryGreen.withValues(alpha: 0.12) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: activo ? AppColors.primaryGreen : Colors.grey.shade300,
              width: activo ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 14, color: activo ? AppColors.primaryGreenDark : Colors.grey.shade700),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  etiqueta,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                    color: activo ? AppColors.primaryGreenDark : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectorTaper() {
    final tapers = CatalogService.instance.tapers.where((t) => t.estado).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _llevaTaper ? const Color(0xFFF0FDF4) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _llevaTaper ? AppColors.primaryGreen.withValues(alpha: 0.4) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.package, size: 18, color: _llevaTaper ? AppColors.primaryGreenDark : Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '¿Llevar en táper descartable?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _llevaTaper ? AppColors.primaryGreenDark : Colors.black87,
                  ),
                ),
              ),
              Switch(
                value: _llevaTaper,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primaryGreen,
                onChanged: (val) {
                  setState(() => _llevaTaper = val);
                },
              ),
            ],
          ),
          if (_llevaTaper) ...[
            const SizedBox(height: 8),
            if (tapers.isEmpty)
              Text(
                'No hay táperes registrados en inventario.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _taperSeleccionado?.id,
                decoration: InputDecoration(
                  labelText: 'Seleccionar tipo de táper',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: [
                  for (final t in tapers)
                    DropdownMenuItem(
                      value: t.id,
                      child: Text('${t.nombre} (+S/ ${t.precio.toStringAsFixed(2)})'),
                    ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _taperSeleccionado = tapers.firstWhere((t) => t.id == val);
                    });
                  }
                },
              ),
          ],
        ],
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

  Widget _imagen(CartaItem item) {
    return ColoredBox(
      color: const Color(0xFFF1F3F0),
      child: item.imagenBytes != null
          ? Image.memory(item.imagenBytes!, fit: BoxFit.cover)
          : Center(
              child: Icon(
                Icons.restaurant_outlined,
                size: 26,
                color: Colors.grey.shade400,
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';

import '../data/presentaciones_store.dart';
import '../models/carta_item.dart';
import '../models/carta_presentacion.dart';
import '../models/modificador.dart';
import '../theme/app_theme.dart';
import '../utils/agregados_utils.dart';
import '../utils/carta_visuals.dart';

// Resultado al agregar un producto configurado al pedido.
typedef ProductoConfigurado =
    ({
      int cantidad,
      CartaPresentacion? presentacion,
      List<Modificador> modificadores,
      String? comentario,
      double precioUnitario,
    });

// Modal "Agregar al pedido": presentación, extras opcionales y nota.
class ProductoOpcionesDialog extends StatefulWidget {
  final CartaItem item;
  final bool esAdmin;

  const ProductoOpcionesDialog({
    super.key,
    required this.item,
    required this.esAdmin,
  });

  @override
  State<ProductoOpcionesDialog> createState() => _ProductoOpcionesDialogState();
}

class _ProductoOpcionesDialogState extends State<ProductoOpcionesDialog> {
  late final List<CartaPresentacion> _presentaciones = mockPresentaciones
      .where((p) => p.cartaId == widget.item.id)
      .toList();
  CartaPresentacion? _presentacion;
  final Set<String> _agregadosElegidos = {};
  // Selección por grupo de extras: nombre del grupo -> ítems elegidos.
  final Map<String, Set<String>> _seleccionPorGrupo = {};
  final _comentarioController = TextEditingController();
  int _cantidad = 1;

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
    return base + extrasSimples + extrasGrupos;
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
          maxHeight: esMobile ? tam.height * 0.9 : (tam.height * 0.85).clamp(420.0, 680.0),
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
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    if (_presentaciones.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _tituloSeccion('Elige el tamaño', obligatorio: true),
                      const SizedBox(height: 6),
                      for (final p in _presentaciones)
                        _filaRadio(p),
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
                    _tituloSeccion('Notas (opcional)'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _comentarioController,
                      maxLength: 60,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Notas para este producto (opcional)',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
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
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  _botonCantidad(Icons.add, () => setState(() => _cantidad++)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _confirmar,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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

  Widget _tituloSeccion(String texto, {String? subtitulo, bool obligatorio = false}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(texto, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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

  // Cada extra opcional es una tag/chip que se activa al tocarla.
  Widget _tagAgregado(Map<String, dynamic> a) {
    final nombre = '${a['nombre']}';
    final precio = a['precio'];
    final activo = _agregadosElegidos.contains(nombre);
    final texto = precio is num && precio > 0
        ? '$nombre +S/ ${precio.toStringAsFixed(2)}'
        : nombre;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _alternarAgregado(nombre),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? AppColors.primaryGreen.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activo ? AppColors.primaryGreen : Colors.grey.shade300,
            width: activo ? 1.5 : 1,
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: activo ? AppColors.primaryGreenDark : Colors.black87,
          ),
        ),
      ),
    );
  }

  // Igual que `_tagAgregado`, pero para un ítem dentro de un grupo.
  Widget _tagAgregadoGrupo(Map<String, dynamic> grupo, Map<String, dynamic> it) {
    final nombreItem = '${it['nombre']}';
    final precio = it['precio'];
    final grupoNombre = nombreGrupo(grupo);
    final activo = (_seleccionPorGrupo[grupoNombre] ?? const {}).contains(
      nombreItem,
    );
    final texto = precio is num && precio > 0
        ? '$nombreItem +S/ ${precio.toStringAsFixed(2)}'
        : nombreItem;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _alternarAgregadoGrupo(
        grupoNombre,
        nombreItem,
        cantidadMaximaGrupo(grupo) ?? 1,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? AppColors.primaryGreen.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activo ? AppColors.primaryGreen : Colors.grey.shade300,
            width: activo ? 1.5 : 1,
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: activo ? AppColors.primaryGreenDark : Colors.black87,
          ),
        ),
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
          color: onTap == null ? Colors.grey.shade300 : AppColors.primaryGreen,
        ),
      ),
    );
  }

  Widget _imagen(CartaItem item) {
    final asset = imagenDeCarta(item.id);
    return ColoredBox(
      color: const Color(0xFFF1F3F0),
      child: asset != null
          ? Image.asset(asset, fit: BoxFit.cover)
          : Center(
              child: Icon(
                iconoDeCategoria(item.categoriaId),
                size: 26,
                color: Colors.grey.shade400,
              ),
            ),
    );
  }
}

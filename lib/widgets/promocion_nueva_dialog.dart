import 'package:flutter/material.dart';

import '../data/cartas_store.dart';
import '../data/presentaciones_store.dart';
import '../data/promociones_destacadas_store.dart';
import '../data/promociones_store.dart';
import '../data/subcategorias_store.dart';
import '../models/carta_item.dart';
import '../models/carta_presentacion.dart';
import '../models/promocion.dart';
import '../models/promocion_componente.dart';
import '../models/subcategoria.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/uuid_helper.dart';
import 'app_select.dart';
import 'app_switch.dart';
import 'campo_texto.dart';
import 'pago_dialogs.dart';
import 'promocion_dialogs.dart' show etiquetaSubcategoria;
import 'selector_rango_fechas.dart';

// Una promoción completa lista para guardar: la promoción, sus componentes y,
// en cada uno, los productos permitidos (el primero es el incluido).
typedef PromocionCompleta = ({
  Promocion promocion,
  List<({PromocionComponente componente, List<PromocionOpcion> opciones})>
  componentes,
});

class _OpcionBorrador {
  // Si se está editando, la opción que ya existe (conserva su id y si es la
  // incluida).
  final PromocionOpcion? existente;
  CartaItem? item;
  CartaPresentacion? presentacion;
  final precio = TextEditingController();
  bool activa = true;

  _OpcionBorrador({this.existente});
}

class _ComponenteBorrador {
  // Si se está editando, el componente que ya existe.
  final PromocionComponente? existente;
  Subcategoria? subcategoria;
  int cantidad = 1;
  final List<_OpcionBorrador> opciones;

  _ComponenteBorrador({this.existente, List<_OpcionBorrador>? opciones})
    : opciones = opciones ?? [_OpcionBorrador()];
}

// Registro de una promoción en un solo modal: datos, componentes (huecos del
// combo por subcategoría) y productos de cada uno. Usa las mismas rutas del
// servidor que ya existen (promoción, componente y opción), una tras otra.
class PromocionNuevaDialog extends StatefulWidget {
  // Si viene, el modal edita esa promoción (mismos pasos, ya llenos).
  final Promocion? existente;

  const PromocionNuevaDialog({super.key, this.existente});

  @override
  State<PromocionNuevaDialog> createState() => _PromocionNuevaDialogState();
}

class _PromocionNuevaDialogState extends State<PromocionNuevaDialog> {
  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();
  final _porcentaje = TextEditingController();
  bool _seMantiene = true;
  bool _estado = true;
  bool _destacada = false;
  DateTime? _inicio;
  DateTime? _fin;
  List<_ComponenteBorrador> _componentes = [_ComponenteBorrador()];
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.existente;
    if (p == null) return;
    _nombre.text = p.nombre;
    _descripcion.text = p.descripcion ?? '';
    if (p.porcentajeDescuento != null) {
      final d = p.porcentajeDescuento!;
      _porcentaje.text = d.toStringAsFixed(d % 1 == 0 ? 0 : 2);
    }
    _seMantiene = p.seMantiene;
    _estado = p.estado;
    _destacada = esPromocionDestacada(p.id);
    _inicio = p.fechaInicio;
    _fin = p.fechaFin;
    final comps = [
      for (final comp in componentesDe(p.id))
        _ComponenteBorrador(
            existente: comp,
            opciones: [
              for (final o in opcionesDe(comp.id))
                _OpcionBorrador(existente: o)
                  ..item = cartasNotifier.value
                      .where((x) => x.id == o.cartaId)
                      .firstOrNull
                  ..presentacion = presentaciones
                      .where((x) => x.id == o.cartaPresentacionId)
                      .firstOrNull
                  ..activa = o.estado
                  ..precio.text = o.precio > 0
                      ? o.precio.toStringAsFixed(o.precio % 1 == 0 ? 0 : 2)
                      : '',
            ],
          )
          ..subcategoria = subcategorias
              .where((s) => s.id == comp.subcategoriaId)
              .firstOrNull,
    ];
    if (comps.isNotEmpty) _componentes = comps;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _porcentaje.dispose();
    for (final c in _componentes) {
      for (final o in c.opciones) {
        o.precio.dispose();
      }
    }
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  // Productos de la subcategoría del componente que aún no se eligieron en él.
  List<CartaItem> _candidatos(_ComponenteBorrador c, _OpcionBorrador actual) {
    final sub = c.subcategoria;
    if (sub == null) return const [];
    final usados = {
      for (final o in c.opciones)
        if (!identical(o, actual) && o.item != null)
          '${o.item!.id}|${o.presentacion?.id}',
    };
    return cartasNotifier.value.where((x) {
      if (!x.subcategoriaIds.contains(sub.id)) return false;
      final pres = presentaciones.where((p) => p.cartaId == x.id).toList();
      if (pres.isEmpty) return !usados.contains('${x.id}|null');
      return pres.any((p) => !usados.contains('${x.id}|${p.id}'));
    }).toList();
  }

  List<CartaPresentacion> _presentacionesDe(
    _ComponenteBorrador c,
    _OpcionBorrador o,
  ) {
    final item = o.item;
    if (item == null) return const [];
    final usados = {
      for (final x in c.opciones)
        if (!identical(x, o) && x.item?.id == item.id)
          '${x.item!.id}|${x.presentacion?.id}',
    };
    return presentaciones
        .where((p) => p.cartaId == item.id)
        .where((p) => !usados.contains('${item.id}|${p.id}'))
        .toList();
  }

  void _guardar() {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Ingresa el nombre de la promoción');
      return;
    }
    final textoPct = _porcentaje.text.trim();
    double? pct;
    if (textoPct.isNotEmpty) {
      pct = _num(_porcentaje);
      if (pct <= 0 || pct > 100) {
        setState(() => _error = 'El descuento debe estar entre 0 y 100');
        return;
      }
    }
    if (_inicio != null && _fin != null && _fin!.isBefore(_inicio!)) {
      setState(() => _error = 'La fecha fin no puede ser anterior al inicio');
      return;
    }
    if (_componentes.isEmpty) {
      setState(() => _error = 'Agrega al menos un componente al combo');
      return;
    }
    final promoId = widget.existente?.id ?? UuidHelper.v7();
    final comps =
        <({PromocionComponente componente, List<PromocionOpcion> opciones})>[];
    for (var i = 0; i < _componentes.length; i++) {
      final c = _componentes[i];
      final sub = c.subcategoria;
      if (sub == null) {
        setState(() => _error = 'Componente ${i + 1}: elige la subcategoría');
        return;
      }
      final compId = c.existente?.id ?? UuidHelper.v7();
      final opciones = <PromocionOpcion>[];
      for (final o in c.opciones) {
        final item = o.item;
        if (item == null) {
          setState(
            () =>
                _error = 'Componente ${i + 1}: elige el producto de cada fila',
          );
          return;
        }
        if (_presentacionesDe(c, o).isNotEmpty && o.presentacion == null) {
          setState(
            () => _error =
                '"${item.nombrePlato}": elige la presentación (vaso, jarra…)',
          );
          return;
        }
        if (o.precio.text.trim().isNotEmpty && _num(o.precio) < 0) {
          setState(() => _error = 'El precio no puede ser negativo');
          return;
        }
        opciones.add(
          PromocionOpcion(
            id: o.existente?.id ?? UuidHelper.v7(),
            componenteId: compId,
            cartaId: item.id,
            cartaPresentacionId: o.presentacion?.id,
            cartaVarianteId: o.existente?.cartaVarianteId,
            precio: _num(o.precio),
            estado: o.activa,
            esFijo: o.existente?.esFijo ?? false,
          ),
        );
      }
      if (opciones.isEmpty) {
        setState(() => _error = 'Componente ${i + 1}: agrega un producto');
        return;
      }
      comps.add((
        componente: PromocionComponente(
          id: compId,
          promocionId: promoId,
          subcategoriaId: sub.id,
          cantidad: c.cantidad,
          orden: i,
        ),
        opciones: opciones,
      ));
    }
    final descripcion = _descripcion.text.trim();
    marcarPromocionDestacada(promoId, _destacada);
    Navigator.of(context).pop<PromocionCompleta>((
      promocion: Promocion(
        id: promoId,
        nombre: nombre,
        descripcion: descripcion.isEmpty ? null : descripcion,
        porcentajeDescuento: pct,
        seMantiene: _seMantiene,
        fechaInicio: _inicio,
        fechaFin: _fin,
        estado: _estado,
        sedeId:
            widget.existente?.sedeId ??
            AuthService.instance.currentUser?.sedeId,
      ),
      componentes: comps,
    ));
  }

  Widget _paso(IconData icono, VoidCallback? onTap) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onTap == null
            ? Colors.grey.shade100
            : AppColors.primaryGreen.withValues(alpha: 0.12),
      ),
      child: Icon(
        icono,
        size: 17,
        color: onTap == null
            ? Colors.grey.shade400
            : AppColors.primaryGreenDark,
      ),
    ),
  );

  Widget _opcion(_ComponenteBorrador c, _OpcionBorrador o, int indice) {
    final candidatos = _candidatos(c, o);
    final items = {if (o.item != null) o.item!, ...candidatos}.toList();
    final pres = _presentacionesDe(c, o);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  indice == 0 ? 'Producto incluido' : 'Cambio posible',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: indice == 0
                        ? AppColors.primaryGreenDark
                        : Colors.grey.shade600,
                  ),
                ),
              ),
              if (c.opciones.length > 1)
                IconButton(
                  tooltip: 'Quitar producto',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    c.opciones.remove(o);
                    o.precio.dispose();
                  }),
                  icon: const Icon(
                    Icons.close,
                    size: 17,
                    color: AppColors.error,
                  ),
                ),
            ],
          ),
          AppSelect<CartaItem>(
            label: 'Producto',
            hint: c.subcategoria == null
                ? 'Primero elige la subcategoría'
                : 'Selecciona un producto',
            value: o.item,
            items: [
              for (final x in items)
                AppSelectItem(value: x, label: x.nombrePlato),
            ],
            onChanged: (x) => setState(() {
              o.item = x;
              o.presentacion = null;
              _error = null;
            }),
          ),
          if (o.item != null && pres.isNotEmpty) ...[
            const SizedBox(height: 10),
            AppSelect<CartaPresentacion>(
              label: 'Presentación',
              hint: 'Vaso, jarra, botella…',
              value: o.presentacion,
              items: [
                for (final p in pres)
                  AppSelectItem(
                    value: p,
                    label:
                        '${p.unidad.unidadPresentacion} · ${p.volumenMl} ml · '
                        'S/ ${p.precioCliente.toStringAsFixed(2)}',
                  ),
              ],
              onChanged: (p) => setState(() {
                o.presentacion = p;
                _error = null;
              }),
            ),
          ],
          const SizedBox(height: 10),
          CampoTexto(
            controller: o.precio,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio de promoción (S/) · opcional',
              prefixText: 'S/ ',
              helperText:
                  'Vacío = precio normal con el descuento de la promoción',
              helperMaxLines: 2,
            ),
          ),
          // Al editar, un producto se puede desactivar sin quitarlo.
          if (o.existente != null)
            AppSwitchTile(
              contentPadding: EdgeInsets.zero,
              value: o.activa,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primaryGreen,
              title: const Text('Activo', style: TextStyle(fontSize: 13)),
              onChanged: (v) => setState(() => o.activa = v),
            ),
        ],
      ),
    );
  }

  Widget _componente(_ComponenteBorrador c, int indice) {
    final disponibles = subcategorias.where((s) => s.estado).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Componente ${indice + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              if (_componentes.length > 1)
                IconButton(
                  tooltip: 'Quitar componente',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _componentes.remove(c)),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.error,
                  ),
                ),
            ],
          ),
          AppSelect<Subcategoria>(
            label: 'Subcategoría',
            hint: 'Ej. Segundos, Bebidas',
            value: c.subcategoria,
            items: [
              for (final s in disponibles)
                AppSelectItem(value: s, label: etiquetaSubcategoria(s)),
            ],
            onChanged: (s) => setState(() {
              c.subcategoria = s;
              // Los productos dependen de la subcategoría.
              for (final o in c.opciones) {
                o.item = null;
                o.presentacion = null;
              }
              _error = null;
            }),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Cantidad que se entrega',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              _paso(
                Icons.remove,
                c.cantidad > 1 ? () => setState(() => c.cantidad--) : null,
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${c.cantidad}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _paso(Icons.add, () => setState(() => c.cantidad++)),
            ],
          ),
          for (var i = 0; i < c.opciones.length; i++)
            _opcion(c, c.opciones[i], i),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => c.opciones.add(_OpcionBorrador())),
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Otro producto (cambio posible)'),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Pasos tipo carrusel: Datos, Reglas y Combo, en un solo modal ----

  int _paso0 = 0;
  bool _haciaAdelante = true;
  static const _titulosPaso = ['Datos', 'Vigencia y reglas', 'Combo'];

  // Valida lo del paso actual antes de avanzar.
  String? _validarPaso(int paso) {
    if (paso == 0) {
      if (_nombre.text.trim().isEmpty) {
        return 'Ingresa el nombre de la promoción';
      }
      final textoPct = _porcentaje.text.trim();
      if (textoPct.isNotEmpty) {
        final pct = _num(_porcentaje);
        if (pct <= 0 || pct > 100) {
          return 'El descuento debe estar entre 0 y 100';
        }
      }
    }
    if (paso == 1 &&
        _inicio != null &&
        _fin != null &&
        _fin!.isBefore(_inicio!)) {
      return 'La fecha fin no puede ser anterior al inicio';
    }
    return null;
  }

  void _siguiente() {
    final e = _validarPaso(_paso0);
    if (e != null) {
      setState(() => _error = e);
      return;
    }
    setState(() {
      _error = null;
      _haciaAdelante = true;
      _paso0++;
    });
  }

  void _anterior() => setState(() {
    _error = null;
    _haciaAdelante = false;
    _paso0--;
  });

  Widget _indicador() => Row(
    children: [
      for (var i = 0; i < _titulosPaso.length; i++) ...[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= _paso0
                      ? AppColors.primaryGreen
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${i + 1}. ${_titulosPaso[i]}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: i == _paso0 ? FontWeight.w800 : FontWeight.w500,
                  color: i == _paso0 ? Colors.black87 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        if (i < _titulosPaso.length - 1) const SizedBox(width: 8),
      ],
    ],
  );

  Widget _pasoDatos() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CampoTexto(
        controller: _nombre,
        maxLength: 80,
        decoration: const InputDecoration(
          labelText: 'Nombre *',
          counterText: '',
        ),
      ),
      const SizedBox(height: 12),
      CampoTexto(
        controller: _descripcion,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
      ),
      const SizedBox(height: 12),
      CampoTexto(
        controller: _porcentaje,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Descuento (%) · opcional',
          helperText:
              'Se aplica al precio normal de los productos que no tienen '
              'precio de promoción propio',
          helperMaxLines: 2,
          suffixText: '%',
        ),
      ),
    ],
  );

  Widget _pasoReglas() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Vigencia (opcional)',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerLeft,
        child: SelectorRangoFechas(
          valor: _inicio == null
              ? null
              : DateTimeRange(start: _inicio!, end: _fin ?? _inicio!),
          permiteTodas: true,
          conAtajos: false,
          permiteFuturo: true,
          textoVacio: 'Sin fechas (siempre vigente)',
          textoTodas: 'Sin fechas',
          onChanged: (r) => setState(() {
            _inicio = r?.start;
            _fin = r == null
                ? null
                : DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59);
          }),
        ),
      ),
      const SizedBox(height: 12),
      AppSwitchTile(
        contentPadding: EdgeInsets.zero,
        value: _seMantiene,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.primaryGreen,
        title: const Text('Se mantiene al hacer un cambio'),
        subtitle: Text(
          _seMantiene
              ? 'El producto cambiado conserva su precio de promoción'
              : 'El producto cambiado se cobra a su precio normal',
          style: const TextStyle(fontSize: 12),
        ),
        onChanged: (v) => setState(() => _seMantiene = v),
      ),
      AppSwitchTile(
        contentPadding: EdgeInsets.zero,
        value: _estado,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.primaryGreen,
        title: const Text('Activa'),
        onChanged: (v) => setState(() => _estado = v),
      ),
      AppSwitchTile(
        contentPadding: EdgeInsets.zero,
        value: _destacada,
        activeThumbColor: Colors.white,
        activeTrackColor: const Color(0xFFEAB308),
        title: const Text('Destacada (color amarillo)'),
        subtitle: const Text(
          'Se resalta en amarillo, como Cumpleaños',
          style: TextStyle(fontSize: 12),
        ),
        onChanged: (v) => setState(() => _destacada = v),
      ),
    ],
  );

  Widget _pasoCombo() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Cada componente es un hueco (ej. 1 Segundo, 1 Bebida). El primer '
        'producto es el incluido; los demás son cambios que el mozo puede '
        'hacer si el cliente lo pide.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 10),
      for (var i = 0; i < _componentes.length; i++)
        _componente(_componentes[i], i),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () =>
              setState(() => _componentes.add(_ComponenteBorrador())),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Otro componente'),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final ultimo = _paso0 == _titulosPaso.length - 1;
    final contenido = switch (_paso0) {
      0 => _pasoDatos(),
      1 => _pasoReglas(),
      _ => _pasoCombo(),
    };
    return ModalPago(
      titulo: widget.existente == null ? 'Nueva promoción' : 'Editar promoción',
      subtitulo: 'Paso ${_paso0 + 1} de ${_titulosPaso.length}',
      anchoEscritorio: 560,
      pie: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ),
          Row(
            children: [
              if (_paso0 > 0) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _anterior,
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: const Text('Atrás'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: ultimo ? _guardar : _siguiente,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                  ),
                  child: Text(
                    ultimo
                        ? (widget.existente == null
                              ? 'Crear promoción'
                              : 'Guardar cambios')
                        : 'Siguiente',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _indicador(),
            const SizedBox(height: 16),
            // El paso entra deslizándose, como un carrusel.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, animacion) => SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(_haciaAdelante ? 0.25 : -0.25, 0),
                  end: Offset.zero,
                ).animate(animacion),
                child: FadeTransition(opacity: animacion, child: child),
              ),
              child: KeyedSubtree(key: ValueKey(_paso0), child: contenido),
            ),
          ],
        ),
      ),
    );
  }
}

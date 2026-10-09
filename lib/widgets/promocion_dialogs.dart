import 'package:flutter/material.dart';

import '../data/cartas_store.dart';
import '../data/categorias_store.dart';
import '../data/presentaciones_store.dart';
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
import 'pago_dialogs.dart';

String _fechaTexto(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// "Categoría › Subcategoría" para elegir sin confundirse entre categorías.
String etiquetaSubcategoria(Subcategoria s) {
  final cat = categorias
      .where((c) => c.id == s.categoriaComidaId)
      .map((c) => c.categoria)
      .firstOrNull;
  return cat == null ? s.subcategoria : '$cat › ${s.subcategoria}';
}

// ---------------------------------------------------------------------------
// Promoción: nombre, descuento, vigencia y si se mantiene al hacer un cambio.
// ---------------------------------------------------------------------------

class PromocionFormDialog extends StatefulWidget {
  final Promocion? promocion;

  const PromocionFormDialog({super.key, this.promocion});

  @override
  State<PromocionFormDialog> createState() => _PromocionFormDialogState();
}

class _PromocionFormDialogState extends State<PromocionFormDialog> {
  late final _nombre = TextEditingController(text: widget.promocion?.nombre);
  late final _descripcion = TextEditingController(
    text: widget.promocion?.descripcion,
  );
  late final _porcentaje = TextEditingController(
    text: widget.promocion?.porcentajeDescuento?.toString() ?? '',
  );
  late bool _seMantiene = widget.promocion?.seMantiene ?? true;
  late bool _estado = widget.promocion?.estado ?? true;
  late DateTime? _inicio = widget.promocion?.fechaInicio;
  late DateTime? _fin = widget.promocion?.fechaFin;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _porcentaje.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha(bool inicio) async {
    final base = (inicio ? _inicio : _fin) ?? DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (elegida == null) return;
    setState(() {
      if (inicio) {
        _inicio = DateTime(elegida.year, elegida.month, elegida.day);
      } else {
        _fin = DateTime(elegida.year, elegida.month, elegida.day, 23, 59, 59);
      }
    });
  }

  void _guardar() {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Ingresa el nombre de la promoción');
      return;
    }
    final texto = _porcentaje.text.trim().replaceAll(',', '.');
    double? pct;
    if (texto.isNotEmpty) {
      pct = double.tryParse(texto);
      if (pct == null || pct <= 0 || pct > 100) {
        setState(() => _error = 'El descuento debe estar entre 0 y 100');
        return;
      }
    }
    if (_inicio != null && _fin != null && _fin!.isBefore(_inicio!)) {
      setState(() => _error = 'La fecha fin no puede ser anterior al inicio');
      return;
    }
    final descripcion = _descripcion.text.trim();
    final anterior = widget.promocion;
    Navigator.of(context).pop(
      Promocion(
        id: anterior?.id ?? UuidHelper.v7(),
        nombre: nombre,
        descripcion: descripcion.isEmpty ? null : descripcion,
        porcentajeDescuento: pct,
        seMantiene: _seMantiene,
        fechaInicio: _inicio,
        fechaFin: _fin,
        estado: _estado,
        sedeId: anterior?.sedeId ?? AuthService.instance.currentUser?.sedeId,
      ),
    );
  }

  Widget _campoFecha(String etiqueta, DateTime? valor, bool inicio) {
    return Expanded(
      child: InkWell(
        onTap: () => _elegirFecha(inicio),
        borderRadius: BorderRadius.circular(AppRadii.tag),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: etiqueta,
            suffixIcon: valor == null
                ? const Icon(Icons.calendar_today_outlined, size: 18)
                : IconButton(
                    tooltip: 'Quitar fecha',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() {
                      if (inicio) {
                        _inicio = null;
                      } else {
                        _fin = null;
                      }
                    }),
                  ),
          ),
          child: Text(valor == null ? 'Sin límite' : _fechaTexto(valor)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModalPago(
      titulo: widget.promocion == null ? 'Nueva promoción' : 'Editar promoción',
      subtitulo: 'Luego agregas sus componentes y opciones',
      anchoEscritorio: 480,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nombre,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descripcion,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _porcentaje,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Descuento (%) (opcional)',
                helperText:
                    'Se aplica al precio normal de las opciones que no tienen '
                    'precio de promoción propio',
                helperMaxLines: 2,
                suffixText: '%',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _campoFecha('Desde', _inicio, true),
                const SizedBox(width: 10),
                _campoFecha('Hasta', _fin, false),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _seMantiene,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primaryGreen,
              title: const Text('La promoción se mantiene al hacer un cambio'),
              subtitle: Text(
                _seMantiene
                    ? 'El producto cambiado conserva su precio de promoción'
                    : 'El producto cambiado se cobra a su precio normal',
                style: const TextStyle(fontSize: 12),
              ),
              onChanged: (v) => setState(() => _seMantiene = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _estado,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primaryGreen,
              title: const Text('Activa'),
              onChanged: (v) => setState(() => _estado = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ],
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _guardar,
                child: Text(
                  widget.promocion == null
                      ? 'Crear promoción'
                      : 'Guardar cambios',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Componente: un hueco del combo definido por una subcategoría.
// ---------------------------------------------------------------------------

class ComponenteFormDialog extends StatefulWidget {
  final String promocionId;
  final PromocionComponente? componente;

  const ComponenteFormDialog({
    super.key,
    required this.promocionId,
    this.componente,
  });

  @override
  State<ComponenteFormDialog> createState() => _ComponenteFormDialogState();
}

class _ComponenteFormDialogState extends State<ComponenteFormDialog> {
  late Subcategoria? _subcategoria = subcategoriaPorId(
    widget.componente?.subcategoriaId,
  );
  late int _cantidad = widget.componente?.cantidad ?? 1;
  String? _error;

  void _guardar() {
    final sub = _subcategoria;
    if (sub == null) {
      setState(() => _error = 'Elige la subcategoría del componente');
      return;
    }
    final anterior = widget.componente;
    Navigator.of(context).pop(
      PromocionComponente(
        id: anterior?.id ?? UuidHelper.v7(),
        promocionId: widget.promocionId,
        subcategoriaId: sub.id,
        cantidad: _cantidad,
        orden: anterior?.orden ?? 0,
      ),
    );
  }

  Widget _paso(IconData icono, VoidCallback? onTap) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onTap == null
            ? Colors.grey.shade100
            : AppColors.primaryGreen.withValues(alpha: 0.12),
      ),
      child: Icon(
        icono,
        size: 18,
        color: onTap == null ? Colors.grey.shade400 : AppColors.primaryGreenDark,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final disponibles = subcategorias.where((s) => s.estado).toList();
    return ModalPago(
      titulo: widget.componente == null ? 'Nuevo componente' : 'Editar componente',
      subtitulo: 'Un hueco del combo (ej. 1 Segundo, 1 Bebida)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (disponibles.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Primero crea subcategorías desde Productos → Categorías.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          AppSelect<Subcategoria>(
            label: 'Subcategoría',
            hint: 'Selecciona una subcategoría',
            value: _subcategoria,
            items: [
              for (final s in disponibles)
                AppSelectItem(value: s, label: etiquetaSubcategoria(s)),
            ],
            onChanged: (s) => setState(() {
              _subcategoria = s;
              _error = null;
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Cantidad',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _paso(
                Icons.remove,
                _cantidad > 1 ? () => setState(() => _cantidad--) : null,
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '$_cantidad',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              _paso(Icons.add, () => setState(() => _cantidad++)),
            ],
          ),
          if (_cantidad > 1)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Se elige un solo producto y se entrega $_cantidad veces. Si '
                'necesitas productos distintos, crea otro componente.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _guardar,
              child: Text(
                widget.componente == null ? 'Agregar componente' : 'Guardar',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Opción: un producto permitido en el hueco (con su presentación si es bebida)
// y su precio de promoción.
// ---------------------------------------------------------------------------

class OpcionFormDialog extends StatefulWidget {
  final Promocion promocion;
  final PromocionComponente componente;
  final PromocionOpcion? opcion;

  const OpcionFormDialog({
    super.key,
    required this.promocion,
    required this.componente,
    this.opcion,
  });

  @override
  State<OpcionFormDialog> createState() => _OpcionFormDialogState();
}

class _OpcionFormDialogState extends State<OpcionFormDialog> {
  late CartaItem? _item = cartasNotifier.value
      .where((c) => c.id == widget.opcion?.cartaId)
      .firstOrNull;
  late CartaPresentacion? _presentacion = presentaciones
      .where((p) => p.id == widget.opcion?.cartaPresentacionId)
      .firstOrNull;
  late final _precio = TextEditingController(
    text: (widget.opcion?.precio ?? 0) > 0
        ? widget.opcion!.precio.toStringAsFixed(2)
        : '',
  );
  late bool _estado = widget.opcion?.estado ?? true;
  String? _error;

  @override
  void dispose() {
    _precio.dispose();
    super.dispose();
  }

  // Platos de la subcategoría del componente que aún no son opción de él.
  List<CartaItem> get _candidatos {
    final yaUsados = opcionesDe(widget.componente.id)
        .where((o) => o.id != widget.opcion?.id)
        .map((o) => '${o.cartaId}|${o.cartaPresentacionId}')
        .toSet();
    return cartasNotifier.value
        .where(
          (c) => c.subcategoriaIds.contains(widget.componente.subcategoriaId),
        )
        .where((c) {
          final pres = presentaciones.where((p) => p.cartaId == c.id).toList();
          if (pres.isEmpty) return !yaUsados.contains('${c.id}|null');
          return pres.any((p) => !yaUsados.contains('${c.id}|${p.id}'));
        })
        .toList();
  }

  List<CartaPresentacion> get _presentacionesDelItem {
    final item = _item;
    if (item == null) return const [];
    final yaUsados = opcionesDe(widget.componente.id)
        .where((o) => o.id != widget.opcion?.id)
        .map((o) => '${o.cartaId}|${o.cartaPresentacionId}')
        .toSet();
    return presentaciones
        .where((p) => p.cartaId == item.id)
        .where((p) => !yaUsados.contains('${item.id}|${p.id}'))
        .toList();
  }

  double get _precioValor =>
      double.tryParse(_precio.text.trim().replaceAll(',', '.')) ?? 0;

  PromocionOpcion? get _borrador {
    final item = _item;
    if (item == null) return null;
    return PromocionOpcion(
      id: widget.opcion?.id ?? 'borrador',
      componenteId: widget.componente.id,
      cartaId: item.id,
      cartaPresentacionId: _presentacion?.id,
      precio: _precioValor,
    );
  }

  void _guardar() {
    final item = _item;
    if (item == null) {
      setState(() => _error = 'Elige un producto');
      return;
    }
    if (_presentacionesDelItem.isNotEmpty && _presentacion == null) {
      setState(() => _error = 'Elige la presentación (vaso, jarra, etc.)');
      return;
    }
    if (_precio.text.trim().isNotEmpty && _precioValor < 0) {
      setState(() => _error = 'El precio no puede ser negativo');
      return;
    }
    Navigator.of(context).pop(
      PromocionOpcion(
        id: widget.opcion?.id ?? UuidHelper.v7(),
        componenteId: widget.componente.id,
        cartaId: item.id,
        cartaPresentacionId: _presentacion?.id,
        precio: _precioValor,
        estado: _estado,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final candidatos = _candidatos;
    // Al editar, el producto actual debe seguir en la lista.
    final items = {
      if (_item != null && !candidatos.any((c) => c.id == _item!.id)) _item!,
      ...candidatos,
    }.toList();
    final borrador = _borrador;
    final preciosPresentacion = _presentacionesDelItem;
    return ModalPago(
      titulo: widget.opcion == null ? 'Nueva opción' : 'Editar opción',
      subtitulo:
          '${nombreDeSubcategoria(widget.componente.subcategoriaId)} · '
          '${widget.promocion.nombre}',
      anchoEscritorio: 460,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'No hay productos disponibles en esta subcategoría. '
                  'Asigna la subcategoría a los productos desde Productos.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            AppSelect<CartaItem>(
              label: 'Producto',
              hint: 'Selecciona un producto',
              value: _item,
              items: [
                for (final c in items)
                  AppSelectItem(value: c, label: c.nombrePlato),
              ],
              onChanged: (c) => setState(() {
                _item = c;
                _presentacion = null;
                _error = null;
              }),
            ),
            if (_item != null && preciosPresentacion.isNotEmpty) ...[
              const SizedBox(height: 14),
              AppSelect<CartaPresentacion>(
                label: 'Presentación',
                hint: 'Vaso, jarra, botella…',
                value: _presentacion,
                items: [
                  for (final p in preciosPresentacion)
                    AppSelectItem(
                      value: p,
                      label:
                          '${p.unidad.unidadPresentacion} · ${p.volumenMl} ml · '
                          'S/ ${p.precioCliente.toStringAsFixed(2)}',
                    ),
                ],
                onChanged: (p) => setState(() {
                  _presentacion = p;
                  _error = null;
                }),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _precio,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(
                labelText: 'Precio de promoción (S/) (opcional)',
                prefixText: 'S/ ',
                helperText:
                    'Vacío = precio normal con el descuento de la promoción',
                helperMaxLines: 2,
              ),
            ),
            if (borrador != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Precio normal S/ ${precioNormalDeOpcion(borrador).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      'En la promoción S/ ${precioPromocionalDeOpcion(widget.promocion, borrador).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _estado,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primaryGreen,
              title: const Text('Activa'),
              onChanged: (v) => setState(() => _estado = v),
            ),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _guardar,
                child: Text(
                  widget.opcion == null ? 'Agregar opción' : 'Guardar',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../data/cartas_store.dart';
import '../models/carta_variante.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/uuid_helper.dart';
import 'app_select.dart';
import 'app_toast.dart';
import 'app_switch.dart';
import 'dialogo_app.dart';
import 'campo_texto.dart';

// Alta y edición de un tamaño de plato (`carta_variante`): a qué plato
// pertenece, su nombre, sus precios y el rango de peso (opcional). Se abre
// desde Inventario > Tamaños.
class TamanoFormDialog extends StatefulWidget {
  final CartaVariante? tamano; // null = nuevo tamaño
  final String? cartaIdInicial;

  const TamanoFormDialog({super.key, this.tamano, this.cartaIdInicial});

  @override
  State<TamanoFormDialog> createState() => _TamanoFormDialogState();
}

class _TamanoFormDialogState extends State<TamanoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.tamano?.nombre ?? '');
  late final _precioCliente = TextEditingController(
    text: widget.tamano?.precioCliente.toStringAsFixed(2) ?? '',
  );
  late final _precioPersonal = TextEditingController(
    text: widget.tamano?.precioPersonal.toStringAsFixed(2) ?? '',
  );
  late final _pesoMin = TextEditingController(
    text: widget.tamano?.pesoMinKg?.toString() ?? '',
  );
  late final _pesoMax = TextEditingController(
    text: widget.tamano?.pesoMaxKg?.toString() ?? '',
  );
  late String? _cartaId = widget.tamano?.cartaId ?? widget.cartaIdInicial;
  late bool _estado = widget.tamano?.estado ?? true;
  bool _guardando = false;

  bool get _editando => widget.tamano != null;

  @override
  void dispose() {
    _nombre.dispose();
    _precioCliente.dispose();
    _precioPersonal.dispose();
    _pesoMin.dispose();
    _pesoMax.dispose();
    super.dispose();
  }

  double? _numero(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  String? _validarPrecio(String? v) {
    final n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
    if (n == null || n < 0) return 'Precio inválido';
    return null;
  }

  String? _validarPeso(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = double.tryParse(v.trim().replaceAll(',', '.'));
    if (n == null || n <= 0) return 'Peso inválido';
    return null;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cartaId == null) {
      showAppToast(
        context,
        'Elige el plato de la variante.',
        type: ToastType.error,
      );
      return;
    }
    final min = _numero(_pesoMin);
    final max = _numero(_pesoMax);
    if (min != null && max != null && min > max) {
      showAppToast(
        context,
        'El peso mínimo no puede ser mayor que el máximo.',
        type: ToastType.error,
      );
      return;
    }
    final nuevo = CartaVariante(
      id: widget.tamano?.id ?? UuidHelper.v7(),
      cartaId: _cartaId!,
      nombre: _nombre.text.trim(),
      precioCliente: _numero(_precioCliente) ?? 0,
      precioPersonal: _numero(_precioPersonal) ?? 0,
      pesoMinKg: min,
      pesoMaxKg: max,
      estado: _estado,
    );
    setState(() => _guardando = true);
    try {
      final guardado = _editando
          ? await CatalogService.instance.actualizarVariante(nuevo)
          : await CatalogService.instance.crearVariante(nuevo);
      if (!mounted) return;
      Navigator.of(context).pop(guardado);
      showAppToast(
        context,
        _editando ? 'Variante actualizada.' : 'Variante creada.',
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'Error al guardar la variante: $e',
        type: ToastType.error,
      );
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final platos = [...cartasNotifier.value]
      ..sort((a, b) => a.nombrePlato.compareTo(b.nombrePlato));
    return DialogoApp(
      titulo: _editando ? 'Editar variante' : 'Nueva variante',
      ancho: 440,
      acciones: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
          ),
          child: Text(_editando ? 'Guardar' : 'Crear variante'),
        ),
      ],
      children: [
        Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // El plato no se cambia al editar: un tamaño pertenece a un plato.
                IgnorePointer(
                  ignoring: _editando,
                  child: Opacity(
                    opacity: _editando ? 0.6 : 1,
                    child: AppSelect<String>(
                      label: 'Plato *',
                      buscable: true,
                      hint: 'Elige el plato',
                      value: _cartaId,
                      items: [
                        for (final p in platos)
                          AppSelectItem(value: p.id, label: p.nombrePlato),
                      ],
                      onChanged: (v) => setState(() => _cartaId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                CampoTexto(
                  controller: _nombre,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la variante *',
                    hintText: 'Ej. Pequeño, Mediano, Grande',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'El nombre es obligatorio'
                      : null,
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CampoTexto(
                        controller: _precioCliente,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Precio cliente (S/) *',
                          prefixText: 'S/ ',
                        ),
                        validator: _validarPrecio,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CampoTexto(
                        controller: _precioPersonal,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Precio personal (S/) *',
                          prefixText: 'S/ ',
                        ),
                        validator: _validarPrecio,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CampoTexto(
                        controller: _pesoMin,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Peso mín. (kg)',
                          hintText: 'Opcional',
                        ),
                        validator: _validarPeso,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CampoTexto(
                        controller: _pesoMax,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Peso máx. (kg)',
                          hintText: 'Opcional',
                        ),
                        validator: _validarPeso,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AppSwitchTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _estado ? 'Activo' : 'Inactivo',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Una variante inactiva no se ofrece al tomar pedidos.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _estado,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primaryGreen,
                  onChanged: (v) => setState(() => _estado = v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

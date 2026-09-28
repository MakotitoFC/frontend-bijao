import 'package:flutter/material.dart';

import '../data/cartas_store.dart';
import '../data/promociones_store.dart';
import '../models/promocion.dart';

// Alta/edición de una promoción y los platos a los que aplica
// (simula `promocion` + `promocion_carta`).
class PromocionFormScreen extends StatefulWidget {
  final Promocion? promocion;

  const PromocionFormScreen({super.key, this.promocion});

  @override
  State<PromocionFormScreen> createState() => _PromocionFormScreenState();
}

class _PromocionFormScreenState extends State<PromocionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nombreController = TextEditingController(
    text: widget.promocion?.nombre ?? '',
  );
  late final _descripcionController = TextEditingController(
    text: widget.promocion?.descripcion ?? '',
  );
  late final _valorController = TextEditingController(
    text: widget.promocion?.valor.toString() ?? '',
  );

  late String _tipo = widget.promocion?.tipo ?? 'porcentaje';
  late DateTime _fechaInicio = widget.promocion?.fechaInicio ?? DateTime.now();
  late DateTime _fechaFin =
      widget.promocion?.fechaFin ??
      DateTime.now().add(const Duration(days: 30));
  late bool _activa = widget.promocion?.activa ?? true;
  late final Set<String> _cartasSeleccionadas = widget.promocion == null
      ? {}
      : cartasDePromocion(widget.promocion!.id);

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha({required bool esInicio}) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: esInicio ? _fechaInicio : _fechaFin,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (fecha != null) {
      setState(() => esInicio ? _fechaInicio = fecha : _fechaFin = fecha);
    }
  }

  String _formatearFecha(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaFin.isBefore(_fechaInicio)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha de fin debe ser posterior a la de inicio'),
        ),
      );
      return;
    }

    final id =
        widget.promocion?.id ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final resultado = Promocion(
      id: id,
      nombre: _nombreController.text.trim(),
      descripcion: _descripcionController.text.trim().isEmpty
          ? null
          : _descripcionController.text.trim(),
      tipo: _tipo,
      valor: double.parse(_valorController.text.trim()),
      fechaInicio: _fechaInicio,
      fechaFin: _fechaFin,
      activa: _activa,
    );

    if (widget.promocion == null) {
      agregarPromocion(resultado);
    } else {
      actualizarPromocion(resultado);
    }
    asignarCartasAPromocion(id, _cartasSeleccionadas);

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.promocion != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? 'Editar promoción' : 'Nueva promoción'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descripcionController,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo de descuento'),
              items: const [
                DropdownMenuItem(
                  value: 'porcentaje',
                  child: Text('Porcentaje (%)'),
                ),
                DropdownMenuItem(
                  value: 'monto',
                  child: Text('Monto fijo (S/)'),
                ),
              ],
              onChanged: (value) => setState(() => _tipo = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _valorController,
              decoration: InputDecoration(
                labelText: _tipo == 'porcentaje' ? 'Valor (%)' : 'Valor (S/)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa el valor';
                if (double.tryParse(v.trim()) == null) return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _elegirFecha(esInicio: true),
                    child: Text('Desde: ${_formatearFecha(_fechaInicio)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _elegirFecha(esInicio: false),
                    child: Text('Hasta: ${_formatearFecha(_fechaFin)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activa'),
              value: _activa,
              onChanged: (value) => setState(() => _activa = value),
            ),
            const SizedBox(height: 16),
            Text(
              'Platos aplicables',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            ...cartasNotifier.value.map(
              (carta) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(carta.nombrePlato),
                value: _cartasSeleccionadas.contains(carta.id),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _cartasSeleccionadas.add(carta.id);
                  } else {
                    _cartasSeleccionadas.remove(carta.id);
                  }
                }),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _guardar,
              child: Text(editando ? 'Guardar cambios' : 'Crear promoción'),
            ),
          ],
        ),
      ),
    );
  }
}

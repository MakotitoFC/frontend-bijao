import 'package:flutter/material.dart';

import '../data/presentaciones_store.dart';
import '../models/carta_item.dart';
import '../models/carta_presentacion.dart';
import '../models/unidad_bebida.dart';
import '../services/api_client.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/uuid_helper.dart';
import 'campo_texto.dart';
import 'app_select.dart';
import 'dialogo_app.dart';

// Agrega una presentación a un plato o bebida que ya existe (botón
// "+ Presentación" de la tarjeta del plato). Permite elegir una unidad de
// bebida existente (ej. Vaso, Jarra) o escribir una nueva, indicar el volumen
// en ml (opcional) y el precio. Devuelve la presentación creada, o null si se cancela.
class PresentacionRapidaDialog extends StatefulWidget {
  final CartaItem plato;

  const PresentacionRapidaDialog({super.key, required this.plato});

  @override
  State<PresentacionRapidaDialog> createState() =>
      _PresentacionRapidaDialogState();
}

class _PresentacionRapidaDialogState extends State<PresentacionRapidaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nuevaUnidad = TextEditingController();
  final _volumen = TextEditingController();
  final _precio = TextEditingController();

  String? _unidadIdSeleccionada;
  bool _creandoNuevaUnidad = false;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final activas = unidadesBebida.where((u) => u.estado).toList();
    if (activas.isNotEmpty) {
      _unidadIdSeleccionada = activas.first.id;
    } else {
      _creandoNuevaUnidad = true;
    }
    if (unidadesBebida.isEmpty) {
      CatalogService.instance.cargarUnidadesBebida().then((lista) {
        if (!mounted) return;
        final disp = lista.where((u) => u.estado).toList();
        if (disp.isNotEmpty && _unidadIdSeleccionada == null) {
          setState(() {
            _unidadIdSeleccionada = disp.first.id;
            _creandoNuevaUnidad = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nuevaUnidad.dispose();
    _volumen.dispose();
    _precio.dispose();
    super.dispose();
  }

  double? _numero(String t) => double.tryParse(t.trim().replaceAll(',', '.'));

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_creandoNuevaUnidad &&
        (_unidadIdSeleccionada == null || _unidadIdSeleccionada!.isEmpty)) {
      setState(() => _error = 'Selecciona una presentación');
      return;
    }
    final precio = _numero(_precio.text)!;
    final volumenMl = int.tryParse(_volumen.text.trim()) ?? 0;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      UnidadBebida unidad;
      if (_creandoNuevaUnidad) {
        final nombre = _nuevaUnidad.text.trim();
        final existente = unidadesBebida
            .where(
              (u) => u.unidadPresentacion.toLowerCase() == nombre.toLowerCase(),
            )
            .firstOrNull;
        unidad =
            existente ??
            await CatalogService.instance.crearUnidadBebida(nombre);
      } else {
        unidad = unidadesBebida.firstWhere(
          (u) => u.id == _unidadIdSeleccionada,
        );
      }

      final creada = await CatalogService.instance.crearPresentacion(
        CartaPresentacion(
          id: UuidHelper.v7(),
          cartaId: widget.plato.id,
          unidad: unidad,
          volumenMl: volumenMl,
          precioCliente: precio,
          precioPersonal: precio,
        ),
      );
      if (mounted) Navigator.of(context).pop(creada);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = e is ApiException
            ? e.message
            : e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final existentes = presentacionesDeCarta(widget.plato.id, soloActivas: true);
    final unidadesActivas = unidadesParaElegir(unidadesBebida);
    // Si el elegido era uno de los repetidos, se muestra su equivalente.
    final unidadElegida = idDeOpcion(
      unidadesActivas,
      unidadesBebida,
      _unidadIdSeleccionada,
    );

    return DialogoApp(
      titulo: 'Nueva presentación · ${widget.plato.nombrePlato}',
      ancho: 420,
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
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Agregar presentación'),
        ),
      ],
      children: [
        Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (unidadesActivas.isNotEmpty && !_creandoNuevaUnidad) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppSelect<String>(
                        label: 'Presentación (envase) *',
                        value: unidadElegida,
                        hint: 'Elige el envase',
                        items: [
                          for (final u in unidadesActivas)
                            AppSelectItem(
                              value: u.id,
                              label: u.unidadPresentacion,
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _unidadIdSeleccionada = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _creandoNuevaUnidad = true),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Nueva'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CampoTexto(
                        controller: _nuevaUnidad,
                        autofocus: true,
                        maxLength: 25,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la presentación *',
                          hintText: 'Ej. Vaso, Jarra, Botella',
                          counterText: '',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'El nombre es obligatorio'
                            : null,
                      ),
                    ),
                    if (unidadesActivas.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _creandoNuevaUnidad = false),
                          child: const Text('Elegir existente'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CampoTexto(
                      controller: _volumen,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Volumen (ml)',
                        hintText: 'Ej. 350, 1000',
                        suffixText: 'ml',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CampoTexto(
                      controller: _precio,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Precio (S/) *',
                        prefixText: 'S/ ',
                      ),
                      validator: (v) {
                        final n = _numero(v ?? '');
                        return (n == null || n < 0) ? 'Precio inválido' : null;
                      },
                    ),
                  ),
                ],
              ),
              if (existentes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Ya tiene: ${existentes.map((p) => '${p.unidad.unidadPresentacion}${p.volumenMl > 0 ? ' (${p.volumenMl} ml)' : ''} S/ ${p.precioCliente.toStringAsFixed(2)}').join(' · ')}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

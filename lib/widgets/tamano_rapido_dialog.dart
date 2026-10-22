import 'package:flutter/material.dart';

import '../data/variantes_store.dart';
import '../models/carta_item.dart';
import '../models/carta_variante.dart';
import '../services/api_client.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/uuid_helper.dart';
import 'campo_texto.dart';
import 'dialogo_app.dart';

// Agrega un tamaño a un plato que ya existe, con solo nombre y precio (botón
// "+ Tamaño" de la tarjeta del plato). El precio personal queda igual al
// público. Devuelve el tamaño creado, o null si se cancela.
class TamanoRapidoDialog extends StatefulWidget {
  final CartaItem plato;

  const TamanoRapidoDialog({super.key, required this.plato});

  @override
  State<TamanoRapidoDialog> createState() => _TamanoRapidoDialogState();
}

class _TamanoRapidoDialogState extends State<TamanoRapidoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _precio = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _precio.dispose();
    super.dispose();
  }

  double? _numero(String t) => double.tryParse(t.trim().replaceAll(',', '.'));

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final precio = _numero(_precio.text)!;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final creado = await CatalogService.instance.crearVariante(
        CartaVariante(
          id: UuidHelper.v7(),
          cartaId: widget.plato.id,
          nombre: _nombre.text.trim(),
          precioCliente: precio,
          precioPersonal: precio,
        ),
      );
      if (mounted) Navigator.of(context).pop(creado);
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
    final existentes = variantesDeCarta(widget.plato.id);
    return DialogoApp(
      titulo: 'Nueva variante · ${widget.plato.nombrePlato}',
      ancho: 400,
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
              : const Text('Agregar variante'),
        ),
      ],
      children: [
        Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoTexto(
                controller: _nombre,
                autofocus: true,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la variante *',
                  hintText: 'Ej. Pequeño, Grande',
                  counterText: '',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El nombre es obligatorio'
                    : null,
              ),
              const SizedBox(height: 14),
              CampoTexto(
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
              if (existentes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Ya tiene: ${existentes.map((v) => '${v.nombre} S/ ${v.precioCliente.toStringAsFixed(2)}').join(' · ')}',
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

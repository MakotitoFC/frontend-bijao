import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/cartas_store.dart';
import '../data/presentaciones_store.dart';
import '../data/variantes_store.dart';
import '../models/carta_item.dart';
import '../models/pedido_line.dart';
import '../theme/app_theme.dart';
import '../utils/motivo_precio.dart';
import '../utils/uuid_helper.dart';
import 'app_select.dart';
import 'campo_texto.dart';
import 'dialogo_app.dart';

// Promoción de cumpleaños: se elige cada producto y, al lado, su precio, que por
// defecto es S/ 0.00 (por ejemplo, el juane de cortesía). Devuelve las líneas
// listas para el pedido, con el precio cambiado a mano y "Cumpleaños" como
// motivo; null si se cancela.
class CumpleanosDialog extends StatefulWidget {
  const CumpleanosDialog({super.key});

  @override
  State<CumpleanosDialog> createState() => _CumpleanosDialogState();
}

class _Fila {
  String? cartaId;
  final TextEditingController precio = TextEditingController(text: '0.00');
}

class _CumpleanosDialogState extends State<CumpleanosDialog> {
  final List<_Fila> _filas = [_Fila()];

  List<CartaItem> get _platos => [
    for (final c in cartasNotifier.value)
      if (c.estado == estadoDisponible) c,
  ];

  @override
  void dispose() {
    for (final f in _filas) {
      f.precio.dispose();
    }
    super.dispose();
  }

  double _leer(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.')) ?? -1;

  bool get _completo =>
      _filas.isNotEmpty &&
      _filas.every((f) => f.cartaId != null && _leer(f.precio.text) >= 0);

  PedidoLine _linea(_Fila f) {
    final item = _platos.firstWhere((c) => c.id == f.cartaId);
    final variantes = variantesDeCarta(item.id, soloActivas: true);
    final variante = variantes.isNotEmpty ? variantes.first : null;
    final pres = variante == null
        ? presentaciones.where((p) => p.cartaId == item.id).firstOrNull
        : null;
    final precio = _leer(f.precio.text);
    return PedidoLine(
      id: UuidHelper.v7(),
      cartaId: item.id,
      nombrePlato: item.nombrePlato,
      cantidad: 1,
      modificadores: const [],
      presentacion: pres,
      variante: variante,
      promocion: null,
      comentario: lineaDeMotivoPrecio('Cumpleaños'),
      precioUnitario: precio,
      descuentoAplicado: 0,
      precioTotalLinea: precio,
      esLibre: false,
      precioBase:
          variante?.precioCliente ??
          pres?.precioCliente ??
          item.precioCliente ??
          0.0,
      precioManual: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final platos = _platos;
    return DialogoApp(
      titulo: 'Cumpleaños',
      ancho: 500,
      acciones: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _completo
              ? () =>
                    Navigator.of(context)
                        .pop([for (final f in _filas) _linea(f)])
              : null,
          icon: const Icon(LucideIcons.cake, size: 16),
          label: const Text('Agregar al pedido'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.naranja),
        ),
      ],
      children: [
        Text(
          'Elige cada producto y su precio. Por defecto es S/ 0.00; puedes '
          'cambiarlo en el que no sea de cortesía.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < _filas.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: AppSelect<String>(
                    compacto: true,
                    buscable: true,
                    value: _filas[i].cartaId,
                    hint: 'Producto',
                    items: [
                      for (final c in platos)
                        AppSelectItem(value: c.id, label: c.nombrePlato),
                    ],
                    onChanged: (v) => setState(() => _filas[i].cartaId = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: AppSizes.boton,
                    child: CampoTexto(
                      controller: _filas[i].precio,
                      expands: true,
                      maxLines: null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 12, right: 4),
                          child: Text(
                            'S/',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 0,
                          minHeight: 0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Opacity(
                  opacity: _filas.length > 1 ? 1 : 0.35,
                  child: BotonCerrarCircular(
                    tamano: 30,
                    onPressed: _filas.length > 1
                        ? () => setState(
                            () => _filas.removeAt(i).precio.dispose(),
                          )
                        : () {},
                  ),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _filas.add(_Fila())),
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('Agregar producto'),
          ),
        ),
      ],
    );
  }
}

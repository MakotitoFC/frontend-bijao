import 'package:flutter/material.dart';

import '../data/configuracion_store.dart';
import '../theme/app_theme.dart';
import 'pago_dialogs.dart';

// Tupper para llevar: cantidad y precio de cada tamaño (grande o mediano).
typedef TupperConfigurado = ({
  int grande,
  double precioGrande,
  int mediano,
  double precioMediano,
});

// Devuelve la selección (cantidades en 0 quitan el tupper) o null si se cierra.
class TupperDialog extends StatefulWidget {
  final int grande;
  final int mediano;

  const TupperDialog({super.key, this.grande = 0, this.mediano = 0});

  @override
  State<TupperDialog> createState() => _TupperDialogState();
}

class _TupperDialogState extends State<TupperDialog> {
  late int _grande = widget.grande;
  late int _mediano = widget.mediano;
  late final _precioGrande = TextEditingController(
    text: config.tupperGrande.toStringAsFixed(2),
  );
  late final _precioMediano = TextEditingController(
    text: config.tupperMediano.toStringAsFixed(2),
  );

  @override
  void dispose() {
    _precioGrande.dispose();
    _precioMediano.dispose();
    super.dispose();
  }

  double get _pGrande => leerMonto(_precioGrande.text);
  double get _pMediano => leerMonto(_precioMediano.text);
  double get _total => _grande * _pGrande + _mediano * _pMediano;
  bool get _editando => widget.grande + widget.mediano > 0;

  void _aplicar() {
    config.tupperGrande = _pGrande;
    config.tupperMediano = _pMediano;
    Navigator.of(context).pop<TupperConfigurado>((
      grande: _grande,
      precioGrande: _pGrande,
      mediano: _mediano,
      precioMediano: _pMediano,
    ));
  }

  void _quitar() {
    Navigator.of(context).pop<TupperConfigurado>((
      grande: 0,
      precioGrande: _pGrande,
      mediano: 0,
      precioMediano: _pMediano,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ModalPago(
      titulo: 'Tupper',
      subtitulo: 'Elige el tamaño y ajusta su precio',
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tamano(
              'Tupper grande',
              _grande,
              _precioGrande,
              (v) => setState(() => _grande = v),
            ),
            const SizedBox(height: 12),
            _tamano(
              'Tupper mediano',
              _mediano,
              _precioMediano,
              (v) => setState(() => _mediano = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total tupper',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  'S/ ${_total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_editando)
                  OutlinedButton(
                    onPressed: _quitar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Quitar'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _total > 0 ? _aplicar : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                  ),
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tamano(
    String nombre,
    int cantidad,
    TextEditingController precio,
    ValueChanged<int> onCantidad,
  ) {
    Widget boton(IconData icono, VoidCallback? onTap) => InkWell(
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
          size: 16,
          color: onTap == null
              ? Colors.grey.shade400
              : AppColors.primaryGreenDark,
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              boton(
                Icons.remove,
                cantidad > 0 ? () => onCantidad(cantidad - 1) : null,
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '$cantidad',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              boton(Icons.add, () => onCantidad(cantidad + 1)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: precio,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio por unidad (S/)',
              prefixText: 'S/ ',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

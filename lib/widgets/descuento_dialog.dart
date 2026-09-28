import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Resultado al crear un descuento para el pedido.
typedef DescuentoConfigurado =
    ({String nombre, bool esPorcentaje, double monto});

// Modal "Descuentos": nombre, tipo (porcentaje o soles) y monto.
class DescuentoDialog extends StatefulWidget {
  const DescuentoDialog({super.key});

  @override
  State<DescuentoDialog> createState() => _DescuentoDialogState();
}

class _DescuentoDialogState extends State<DescuentoDialog> {
  final _nombreController = TextEditingController();
  final _montoController = TextEditingController();
  bool _esPorcentaje = true;
  double _monto = 0;

  @override
  void initState() {
    super.initState();
    _montoController.addListener(() {
      setState(() {
        _monto =
            double.tryParse(_montoController.text.trim().replaceAll(',', '.')) ??
            0;
      });
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  void _guardar() {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty || _monto <= 0) return;
    Navigator.of(context).pop<DescuentoConfigurado>((
      nombre: nombre,
      esPorcentaje: _esPorcentaje,
      monto: _monto,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: esMobile ? MediaQuery.sizeOf(context).width : 420,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, esMobile ? 20 : 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Descuentos',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _cartilla(),
            ],
          ),
        ),
      ),
    );
  }

  // Cartilla tipo ticket: badge (% o S/) a la izquierda, formulario a la derecha.
  Widget _cartilla() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 92,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _esPorcentaje
                      ? '${_monto.toStringAsFixed(0)}%'
                      : 'S/${_monto.toStringAsFixed(0)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'DCTO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(16),
                ),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _campo(
                    controller: _nombreController,
                    hint: 'Nombre del descuento (ej. Cliente frecuente)',
                    autofocus: true,
                  ),
                  const SizedBox(height: 10),
                  _tipoTabs(),
                  const SizedBox(height: 10),
                  _campo(
                    controller: _montoController,
                    hint: _esPorcentaje ? 'Monto (%)' : 'Monto (S/)',
                    teclado: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _guardar,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Aplicar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Elige si el descuento es por porcentaje o en soles.
  Widget _tipoTabs() {
    Widget tab(String texto, bool valor, {bool izquierda = false}) {
      final activo = _esPorcentaje == valor;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _esPorcentaje = valor),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: activo ? AppColors.primaryGreen : Colors.white,
              border: izquierda
                  ? null
                  : Border(left: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: activo ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          tab('Porcentaje (%)', true, izquierda: true),
          tab('Soles (S/)', false),
        ],
      ),
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required String hint,
    bool autofocus = false,
    TextInputType? teclado,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: teclado,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: AppColors.primaryGreen),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Piezas de la pantalla de Configuración.

// Tarjeta blanca con título y filas de ajustes.
class SeccionConfig extends StatelessWidget {
  final String titulo;
  final String? descripcion;
  final List<Widget> filas;

  const SeccionConfig({
    super.key,
    required this.titulo,
    this.descripcion,
    required this.filas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          if (descripcion != null) ...[
            const SizedBox(height: 2),
            Text(
              descripcion!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 8),
          for (var i = 0; i < filas.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
            filas[i],
          ],
        ],
      ),
    );
  }
}

// Fila con título, descripción y un switch a la derecha. Si el switch está
// activo puede mostrar un `extra` debajo (ej. un porcentaje).
class FilaSwitch extends StatelessWidget {
  final String titulo;
  final String? descripcion;
  final bool valor;
  final ValueChanged<bool>? onChanged;
  final Widget? extra;

  const FilaSwitch({
    super.key,
    required this.titulo,
    this.descripcion,
    required this.valor,
    required this.onChanged,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (descripcion != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          descripcion!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: valor,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primaryGreen,
              ),
            ],
          ),
          if (valor && extra != null) ...[const SizedBox(height: 8), extra!],
        ],
      ),
    );
  }
}

// Campo numérico pequeño con prefijo/sufijo (%, S/) que guarda al escribir.
class CampoNumeroConfig extends StatelessWidget {
  final String etiqueta;
  final double valor;
  final String? sufijo;
  final String? prefijo;
  final ValueChanged<double> onChanged;

  const CampoNumeroConfig({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.sufijo,
    this.prefijo,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
        SizedBox(
          width: 120,
          child: TextFormField(
            initialValue: valor == valor.roundToDouble()
                ? valor.toStringAsFixed(0)
                : valor.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              prefixText: prefijo,
              suffixText: sufijo,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            onChanged: (v) {
              final n = double.tryParse(v.trim());
              if (n != null && n >= 0) onChanged(n);
            },
          ),
        ),
      ],
    );
  }
}

// Campo de texto que guarda al escribir.
class CampoTextoConfig extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final ValueChanged<String> onChanged;
  final TextInputType? teclado;

  const CampoTextoConfig({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.onChanged,
    this.teclado,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: valor,
      keyboardType: teclado,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: etiqueta,
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      onChanged: onChanged,
    );
  }
}

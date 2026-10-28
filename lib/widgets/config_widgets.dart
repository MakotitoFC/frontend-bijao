import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_switch.dart';
import 'campo_texto.dart';

// Piezas de la pantalla de Configuración.

// Sección de ajustes: título y descripción arriba, y debajo una tarjeta blanca
// con las filas separadas por líneas finas.
class SeccionConfig extends StatelessWidget {
  final String titulo;
  final String? descripcion;
  final List<Widget> filas;
  // Botón u otro control a la derecha del título (ej. "+ Usuario").
  final Widget? accion;

  const SeccionConfig({
    super.key,
    required this.titulo,
    this.descripcion,
    required this.filas,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?accion,
          ],
        ),
        if (descripcion != null) ...[
          const SizedBox(height: 4),
          Text(
            descripcion!,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < filas.length; i++) ...[
                if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
                filas[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// Ruta de la vista (ej. "Configuración › Servicio"): la última parte en negrita.
class EncabezadoRuta extends StatelessWidget {
  final List<String> ruta;

  const EncabezadoRuta({super.key, required this.ruta});

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(fontSize: 14, color: Colors.grey.shade600);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        for (var i = 0; i < ruta.length; i++) ...[
          if (i > 0)
            Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade500),
          Text(
            ruta[i],
            style: i == ruta.length - 1
                ? const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)
                : estilo,
          ),
        ],
      ],
    );
  }
}

// Fila de solo lectura: etiqueta a la izquierda y valor a la derecha.
class FilaDato extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const FilaDato({super.key, required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              etiqueta,
              style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
              AppSwitch(
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
          child: CampoTexto(
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
  // false: solo se lee (hasta que se pulse "Editar").
  final bool habilitado;

  const CampoTextoConfig({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.onChanged,
    this.teclado,
    this.habilitado = true,
  });

  @override
  Widget build(BuildContext context) {
    return CampoTexto(
      initialValue: valor,
      enabled: habilitado,
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

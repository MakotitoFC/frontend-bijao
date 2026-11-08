import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_switch.dart';
import 'campo_texto.dart';
import 'indice_subvistas.dart';

// Piezas de la pantalla de Configuración.

// Sección de ajustes: título y descripción arriba, y debajo una tarjeta blanca
// con las filas separadas por líneas finas.
class SeccionConfig extends StatelessWidget {
  final String titulo;
  final String? descripcion;
  final List<Widget> filas;
  // Botón u otro control a la derecha del título (ej. "+ Usuario"). En celular
  // pasa debajo de la descripción para no apretar el título.
  final Widget? accion;
  // Enlace bajo la descripción (ej. "Editar en Restaurantes →").
  final ({String texto, VoidCallback onTap})? enlace;

  const SeccionConfig({
    super.key,
    required this.titulo,
    this.descripcion,
    required this.filas,
    this.accion,
    this.enlace,
  });

  @override
  Widget build(BuildContext context) {
    final movil = AppBreakpoints.esMobile(context);
    // En celular, si el título repite al de la cabecera de la subvista, se omite
    // (con su descripción) y la acción sube a esa cabecera.
    final ctx = movil ? ContextoSubvista.de(context) : null;
    final oculto = ctx != null && ctx.repite(titulo);
    final tituloTexto = Text(
      titulo,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    );
    final cuerpo = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!oculto) ...[
          if (movil || accion == null)
            tituloTexto
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: tituloTexto),
                ?accion,
              ],
            ),
          // En celular las descripciones no se muestran.
          if (descripcion != null && !movil) ...[
            const SizedBox(height: 4),
            Text(
              descripcion!,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ],
        if (enlace != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: enlace!.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        enlace!.texto,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreenDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      size: 15,
                      color: AppColors.primaryGreenDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (movil && accion != null && !oculto) ...[
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: accion!),
        ],
        if (!oculto || enlace != null) const SizedBox(height: 14),
        Container(
          // Sin tarjeta: las filas se apoyan sobre el fondo blanco, entre dos
          // líneas finas.
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade200),
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < filas.length; i++) ...[
                // Los encabezados de grupo no llevan línea alrededor.
                if (i > 0 &&
                    filas[i] is! FilaGrupo &&
                    filas[i - 1] is! FilaGrupo)
                  Divider(height: 1, color: Colors.grey.shade200),
                filas[i],
              ],
            ],
          ),
        ),
      ],
    );
    if (oculto && accion != null) {
      return RegistroAccionSubvista(
        contexto: ctx,
        accion: accion!,
        child: cuerpo,
      );
    }
    return cuerpo;
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

// Título de un grupo de datos dentro de una sección (ej. "Datos fiscales").
class FilaGrupo extends StatelessWidget {
  final String titulo;

  const FilaGrupo(this.titulo, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 2),
      child: Text(
        titulo.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}

// Fila de solo lectura. En pantalla ancha, etiqueta a la izquierda y valor a la
// derecha; en celular, la etiqueta chica arriba y el valor debajo, alineado a la
// izquierda (así los textos largos, como una dirección, se leen de corrido).
class FilaDato extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const FilaDato({super.key, required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    final texto = valor.trim().isEmpty ? '—' : valor;
    if (AppBreakpoints.esMobile(context)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              etiqueta,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              texto,
              style: const TextStyle(
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
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
              texto,
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
    final movil = AppBreakpoints.esMobile(context);
    final etiquetaTexto = Text(
      etiqueta,
      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
    );
    // Celular: la etiqueta (a veces larga) arriba y el campo debajo, con letra
    // de 16 px (con menos, Safari agranda la pantalla al tocarlo).
    Widget campo() => SizedBox(
      width: movil ? 160 : 120,
      child: CampoTexto(
        initialValue: valor == valor.roundToDouble()
            ? valor.toStringAsFixed(0)
            : valor.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: movil ? 16 : 13),
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
    );
    if (movil) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [etiquetaTexto, const SizedBox(height: 6), campo()],
      );
    }
    return Row(
      children: [
        Expanded(child: etiquetaTexto),
        campo(),
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

import 'package:flutter/material.dart';

import '../models/taper.dart';
import '../theme/app_theme.dart';
import 'campo_texto.dart';

// Selector de táper con buscador: se puede escribir para filtrar o desplazarse
// por la lista. Muestra el stock de cada uno, pero no impide elegir uno que no
// alcance: el stock es solo informativo.
//
// Con [seleccionados] y [onAlternar] es de selección múltiple (se marca y se
// desmarca cada táper); con [seleccionado] y [onElegir] elige solo uno.
class SelectorTaper extends StatefulWidget {
  final List<Taper> tapers;
  final Taper? seleccionado;
  final Set<String>? seleccionados;
  // Cuántos tápers hacen falta (uno por unidad del plato).
  final int cantidadNecesaria;
  final ValueChanged<Taper>? onElegir;
  final ValueChanged<Taper>? onAlternar;
  // Solo en modo múltiple: cuántos de cada táper marcado (por id) y cómo
  // cambiarlos. Sin esto no se muestra la cantidad por táper.
  final Map<String, int>? cantidades;
  final void Function(Taper taper, int cantidad)? onCantidad;

  const SelectorTaper({
    super.key,
    required this.tapers,
    this.seleccionado,
    this.seleccionados,
    required this.cantidadNecesaria,
    this.onElegir,
    this.onAlternar,
    this.cantidades,
    this.onCantidad,
  }) : assert(
         (seleccionados != null && onAlternar != null) ||
             (seleccionados == null && onElegir != null),
       );

  bool get _multiple => seleccionados != null;

  // Cuántos hacen falta de este táper.
  int _necesita(Taper t) => cantidades?[t.id] ?? cantidadNecesaria;

  bool get _conCantidad =>
      _multiple && cantidades != null && onCantidad != null;

  bool _esElegido(Taper t) =>
      _multiple ? seleccionados!.contains(t.id) : seleccionado?.id == t.id;

  // Primer táper con stock suficiente (para elegirlo por defecto).
  static Taper? primeroConStock(List<Taper> tapers, int cantidad) {
    for (final t in tapers) {
      if (t.stock >= cantidad) return t;
    }
    return null;
  }

  @override
  State<SelectorTaper> createState() => _SelectorTaperState();
}

class _SelectorTaperState extends State<SelectorTaper> {
  String _busqueda = '';

  String _stock(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final termino = _busqueda.trim().toLowerCase();
    final visibles = [
      for (final t in widget.tapers)
        if (termino.isEmpty || t.nombre.toLowerCase().contains(termino)) t,
    ];
    final sinStock = [
      for (final t in widget.tapers)
        if (widget._esElegido(t) && t.stock < widget._necesita(t)) t,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampoTexto(
          onChanged: (v) => setState(() => _busqueda = v),
          decoration: InputDecoration(
            hintText: 'Buscar táper...',
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 170),
          child: Scrollbar(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (visibles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  ),
                for (final t in visibles) _fila(t),
              ],
            ),
          ),
        ),
        for (final e in sinStock)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Stock de "${e.nombre}": ${_stock(e.stock)} '
              '(necesitas ${widget._necesita(e)}). Igual se puede agregar.',
              style: const TextStyle(fontSize: 12, color: AppColors.naranja),
            ),
          ),
      ],
    );
  }

  Widget _paso(IconData icono, VoidCallback? onTap) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Icon(
        icono,
        size: 18,
        color: onTap == null ? Colors.grey.shade300 : AppColors.primaryGreen,
      ),
    ),
  );

  Widget _fila(Taper t) {
    final activo = widget._esElegido(t);
    final alcanza = t.stock >= widget._necesita(t);
    final cant = widget._necesita(t);
    return Opacity(
      opacity: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () =>
            widget._multiple ? widget.onAlternar!(t) : widget.onElegir!(t),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: activo
                ? AppColors.primaryGreen.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: activo ? AppColors.primaryGreen : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    widget._multiple
                        ? (activo
                              ? Icons.check_box
                              : Icons.check_box_outline_blank)
                        : (activo
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off),
                    size: 18,
                    color: activo
                        ? AppColors.primaryGreen
                        : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    'Stock ${_stock(t.stock)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: alcanza ? Colors.grey.shade600 : AppColors.naranja,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '+S/ ${t.precio.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreenDark,
                    ),
                  ),
                ],
              ),
              if (activo && widget._conCantidad)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Cantidad',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _paso(
                        Icons.remove,
                        cant > 1 ? () => widget.onCantidad!(t, cant - 1) : null,
                      ),
                      SizedBox(
                        width: 30,
                        child: Text(
                          '$cant',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _paso(
                        Icons.add,
                        cant < 99
                            ? () => widget.onCantidad!(t, cant + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

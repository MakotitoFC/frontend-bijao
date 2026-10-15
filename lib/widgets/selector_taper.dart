import 'package:flutter/material.dart';

import '../models/taper.dart';
import '../theme/app_theme.dart';
import 'campo_texto.dart';

// Selector de táper con buscador: se puede escribir para filtrar o desplazarse
// por la lista. Muestra el stock de cada uno y bloquea los que no alcanzan para
// la cantidad pedida (el backend vuelve a validar el stock al guardar).
class SelectorTaper extends StatefulWidget {
  final List<Taper> tapers;
  final Taper? seleccionado;
  // Cuántos tápers hacen falta (uno por unidad del plato).
  final int cantidadNecesaria;
  final ValueChanged<Taper> onElegir;

  const SelectorTaper({
    super.key,
    required this.tapers,
    required this.seleccionado,
    required this.cantidadNecesaria,
    required this.onElegir,
  });

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

  String _stock(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final termino = _busqueda.trim().toLowerCase();
    final visibles = [
      for (final t in widget.tapers)
        if (termino.isEmpty || t.nombre.toLowerCase().contains(termino)) t,
    ];
    final elegido = widget.seleccionado;
    final faltaStock =
        elegido != null && elegido.stock < widget.cantidadNecesaria;
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
        if (faltaStock)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'No hay stock suficiente de "${elegido.nombre}" '
              '(necesitas ${widget.cantidadNecesaria}). Elige otro táper.',
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
      ],
    );
  }

  Widget _fila(Taper t) {
    final activo = widget.seleccionado?.id == t.id;
    final alcanza = t.stock >= widget.cantidadNecesaria;
    return Opacity(
      opacity: alcanza ? 1 : 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: alcanza ? () => widget.onElegir(t) : null,
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
          child: Row(
            children: [
              Icon(
                activo ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: activo ? AppColors.primaryGreen : Colors.grey.shade500,
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
                alcanza ? 'Stock ${_stock(t.stock)}' : 'Sin stock',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: alcanza ? Colors.grey.shade600 : AppColors.error,
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
        ),
      ),
    );
  }
}

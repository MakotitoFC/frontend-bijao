import 'package:flutter/material.dart';

import '../models/subcategoria.dart';
import '../theme/app_theme.dart';

// Acordeón para elegir las subcategorías de un producto: al abrirlo muestra
// un checklist de 2 columnas con scroll.
class SubcategoriasAcordeon extends StatefulWidget {
  final List<Subcategoria> opciones;
  final Set<String> seleccion;
  final ValueChanged<Set<String>> onChanged;

  const SubcategoriasAcordeon({
    super.key,
    required this.opciones,
    required this.seleccion,
    required this.onChanged,
  });

  @override
  State<SubcategoriasAcordeon> createState() => _SubcategoriasAcordeonState();
}

class _SubcategoriasAcordeonState extends State<SubcategoriasAcordeon> {
  bool _abierto = false;

  void _alternar(String id) {
    final nueva = Set.of(widget.seleccion);
    if (!nueva.remove(id)) nueva.add(id);
    widget.onChanged(nueva);
  }

  String get _resumen {
    final nombres = [
      for (final s in widget.opciones)
        if (widget.seleccion.contains(s.id)) s.subcategoria,
    ];
    return nombres.isEmpty ? 'Selecciona subcategorías' : nombres.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final hayAlgo = widget.seleccion.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _abierto ? AppColors.primaryGreen : Colors.grey.shade400,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _abierto = !_abierto),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.account_tree_outlined, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subcategorías *',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _resumen,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: hayAlgo
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: hayAlgo
                                ? Colors.black87
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _abierto ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _abierto ? _lista() : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _lista() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: Colors.grey.shade300),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: LayoutBuilder(
                builder: (context, c) {
                  final ancho = c.maxWidth / 2;
                  return Wrap(
                    children: [
                      for (final s in widget.opciones)
                        SizedBox(
                          width: ancho,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _alternar(s.id),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: widget.seleccion.contains(s.id),
                                  activeColor: AppColors.primaryGreen,
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  onChanged: (_) => _alternar(s.id),
                                ),
                                Expanded(
                                  child: Text(
                                    s.subcategoria,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

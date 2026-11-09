import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

// Una subvista del índice: su fila (icono y nombre), el grupo en el que va y lo
// que muestra al abrirse.
typedef SubvistaIndice = ({
  String clave,
  String etiqueta,
  IconData icono,
  String grupo,
  WidgetBuilder contenido,
});

// Navegación de celular para vistas con subvistas (Inventario, Configuración):
// un índice con filas agrupadas y flechas, y cada fila abre su subvista a
// pantalla completa, con un botón para volver al índice. Reemplaza a la barra
// oscura de pestañas. Es controlado: [abierta] es la clave de la subvista que se
// ve (null = el índice) y [onAbrir] pide abrir otra o volver (null).
class IndiceSubvistas extends StatefulWidget {
  final String titulo;
  final String? descripcion;
  final List<SubvistaIndice> subvistas;
  final String? abierta;
  final ValueChanged<String?> onAbrir;
  // Control a la derecha de la cabecera de la subvista (ej. "actualizar").
  final Widget? accionSubvista;

  const IndiceSubvistas({
    super.key,
    required this.titulo,
    this.descripcion,
    required this.subvistas,
    required this.abierta,
    required this.onAbrir,
    this.accionSubvista,
  });

  @override
  State<IndiceSubvistas> createState() => _IndiceSubvistasState();
}

// Lo que una subvista le pide a la cabecera: la acción principal de su primera
// sección (ej. "+ Método"), para que no se repita dentro de la página.
class ContextoSubvista extends InheritedWidget {
  final String etiqueta;
  final ValueNotifier<Widget?> accion;

  const ContextoSubvista({
    super.key,
    required this.etiqueta,
    required this.accion,
    required super.child,
  });

  static ContextoSubvista? de(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ContextoSubvista>();

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .trim();

  // El título de una sección repite al de la cabecera cuando es el mismo o uno
  // contiene al otro ("Usuarios" / "Usuarios y roles").
  bool repite(String titulo) {
    final a = _norm(titulo), b = _norm(etiqueta);
    return a == b || a.contains(b) || b.contains(a);
  }

  @override
  bool updateShouldNotify(ContextoSubvista old) =>
      old.etiqueta != etiqueta || old.accion != accion;
}

// Entrega [accion] a la cabecera de la subvista mientras esté en pantalla.
class RegistroAccionSubvista extends StatefulWidget {
  final ContextoSubvista contexto;
  final Widget accion;
  final Widget child;

  const RegistroAccionSubvista({
    super.key,
    required this.contexto,
    required this.accion,
    required this.child,
  });

  @override
  State<RegistroAccionSubvista> createState() => _RegistroAccionState();
}

class _RegistroAccionState extends State<RegistroAccionSubvista> {
  Widget? _puesta;

  @override
  void dispose() {
    final n = widget.contexto.accion;
    final mia = _puesta;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (n.value == mia) n.value = null;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.contexto.accion;
    final accion = widget.accion;
    _puesta = accion;
    // Se entrega después de construir: la cabecera se reconstruye aparte.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) n.value = accion;
    });
    return widget.child;
  }
}

class _IndiceSubvistasState extends State<IndiceSubvistas> {
  ValueNotifier<Widget?> _accion = ValueNotifier<Widget?>(null);

  String get titulo => widget.titulo;
  String? get descripcion => widget.descripcion;
  List<SubvistaIndice> get subvistas => widget.subvistas;
  String? get abierta => widget.abierta;
  ValueChanged<String?> get onAbrir => widget.onAbrir;
  Widget? get accionSubvista => widget.accionSubvista;

  @override
  void didUpdateWidget(IndiceSubvistas old) {
    super.didUpdateWidget(old);
    // Cada subvista empieza sin acción en la cabecera.
    if (old.abierta != widget.abierta) _accion = ValueNotifier<Widget?>(null);
  }

  @override
  Widget build(BuildContext context) {
    final actual = subvistas.where((s) => s.clave == abierta).firstOrNull;
    return PopScope(
      // El botón "atrás" del celular vuelve al índice antes de salir.
      canPop: actual == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onAbrir(null);
      },
      child: actual == null ? _indice() : _subvista(context, actual),
    );
  }

  Widget _indice() {
    // Los grupos, en el orden en que aparecen.
    final grupos = <String, List<SubvistaIndice>>{};
    for (final s in subvistas) {
      grupos.putIfAbsent(s.grupo, () => []).add(s);
    }
    return Container(
      color: const Color(0xFFF6F7F5),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
            child: Text(
              titulo,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          for (final e in grupos.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
              child: Text(
                e.key.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < e.value.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
                    _fila(e.value[i]),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fila(SubvistaIndice s) {
    return InkWell(
      onTap: () => onAbrir(s.clave),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(s.icono, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                s.etiqueta,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _subvista(BuildContext context, SubvistaIndice s) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Tooltip(
                  message: 'Volver',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onAbrir(null),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Icon(Icons.arrow_back, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Con poco ancho la acción se achica en vez de desbordar.
                ValueListenableBuilder<Widget?>(
                  valueListenable: _accion,
                  builder: (context, a, _) => a == null
                      ? const SizedBox.shrink()
                      : Flexible(
                          flex: 0,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: FittedBox(fit: BoxFit.scaleDown, child: a),
                          ),
                        ),
                ),
                if (accionSubvista != null) ...[
                  const SizedBox(width: 8),
                  accionSubvista!,
                ],
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(s.clave),
              child: ContextoSubvista(
                etiqueta: s.etiqueta,
                accion: _accion,
                child: Builder(builder: s.contenido),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

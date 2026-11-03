import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/mesas_por_liberar_store.dart';
import '../models/mesa.dart';
import '../services/pedido_mozo_service.dart';
import '../services/pedido_service.dart';
import '../utils/blur_dialog.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';
import 'pago_dialogs.dart';

const _azul = Color(0xFF2563EB);

// Campana del header: cuenta lo que hay por atender y, al tocarla, abre el
// modal de notificaciones. Hoy avisa de las mesas por liberar (ya pagaron y la
// mesa sigue ocupada); la lista la da el servidor y llega en vivo.
class CampanaNotificaciones extends StatefulWidget {
  const CampanaNotificaciones({super.key});

  @override
  State<CampanaNotificaciones> createState() => _CampanaNotificacionesState();
}

class _CampanaNotificacionesState extends State<CampanaNotificaciones> {
  // Mesas por liberar que ya se avisaron en pantalla: solo se avisa de las
  // nuevas. Siguen en la campana hasta que se liberen.
  Set<String> _avisadas = {};
  // Aviso en pantalla (tarjeta con una "x" gris); se queda hasta cerrarlo.
  OverlayEntry? _aviso;

  @override
  void initState() {
    super.initState();
    mesasPorLiberarNotifier.addListener(_avisarNuevas);
    if (PedidoMozoService.instance.activo) {
      recargarMesasPorLiberar().catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    mesasPorLiberarNotifier.removeListener(_avisarNuevas);
    _cerrarAviso();
    super.dispose();
  }

  void _cerrarAviso() {
    _aviso?.remove();
    _aviso = null;
  }

  // Cada mesa nueva por liberar se muestra en pantalla como una tarjeta que
  // queda hasta que se cierre con la "x"; la notificación sigue en la campana
  // hasta que se libere la mesa.
  void _avisarNuevas() {
    if (!mounted) return;
    final lista = mesasPorLiberarNotifier.value;
    final ids = {for (final m in lista) m.id};
    final nuevas = [
      for (final m in lista)
        if (!_avisadas.contains(m.id)) m,
    ];
    _avisadas = ids;
    // Ya no queda nada por liberar: el aviso sobra.
    if (lista.isEmpty) {
      _cerrarAviso();
      return;
    }
    if (nuevas.isEmpty) return;
    _cerrarAviso();
    final overlay = Overlay.of(context, rootOverlay: true);
    _aviso = OverlayEntry(
      builder: (_) => _AvisoMesas(
        nuevas: nuevas,
        onAbrir: () {
          _cerrarAviso();
          _abrir();
        },
        onCerrar: _cerrarAviso,
      ),
    );
    overlay.insert(_aviso!);
  }

  Future<void> _abrir() async {
    _cerrarAviso();
    if (PedidoMozoService.instance.activo) {
      recargarMesasPorLiberar().catchError((Object _) {});
    }
    await showBlurDialog<void>(
      context: context,
      builder: (_) => const PanelNotificaciones(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Mesa>>(
      valueListenable: mesasPorLiberarNotifier,
      builder: (context, lista, _) {
        final n = lista.length;
        return Tooltip(
          message: n == 0 ? 'Notificaciones' : '$n por liberar',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _abrir,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Icon(
                      LucideIcons.bell,
                      size: 20,
                      color: n == 0 ? Colors.grey.shade600 : _azul,
                    ),
                  ),
                ),
                if (n > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _azul,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        '$n',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Modal con las notificaciones: una tarjeta por mesa por liberar, con su botón
// Liberar.
class PanelNotificaciones extends StatelessWidget {
  const PanelNotificaciones({super.key});

  Future<void> _liberar(BuildContext context, Mesa mesa) async {
    try {
      await PedidoService.instance.liberarMesa(mesa.id, mesa.numero);
      quitarMesaPorLiberar(mesa.id);
      if (!context.mounted) return;
      showAppToast(
        context,
        'Mesa ${mesa.numero} liberada.',
        type: ToastType.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppToast(
        context,
        'No se pudo liberar la mesa ${mesa.numero}: '
        '${e.toString().replaceFirst('Exception: ', '')}',
        type: ToastType.error,
      );
    }
  }

  Widget _tarjeta(BuildContext context, Mesa m) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _azul,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.armchair,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mesa ${m.numero} por liberar',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ya pagaron. Libera la mesa cuando se retiren.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => _liberar(context, m),
                  style: FilledButton.styleFrom(
                    backgroundColor: _azul,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text(
                    'Liberar',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Mesa>>(
      valueListenable: mesasPorLiberarNotifier,
      builder: (context, lista, _) {
        return ModalPago(
          titulo: 'Notificaciones',
          subtitulo: lista.isEmpty
              ? 'Estás al día.'
              : lista.length == 1
              ? '1 mesa por liberar'
              : '${lista.length} mesas por liberar',
          anchoEscritorio: 440,
          child: lista.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.bellOff,
                          size: 34,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No hay notificaciones.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < lista.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _tarjeta(context, lista[i]),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

// Aviso en pantalla de mesas por liberar: tarjeta arriba a la derecha con una
// "x" gris para cerrarla. Al tocarla se abre el modal de notificaciones.
class _AvisoMesas extends StatelessWidget {
  final List<Mesa> nuevas;
  final VoidCallback onAbrir;
  final VoidCallback onCerrar;

  const _AvisoMesas({
    required this.nuevas,
    required this.onAbrir,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    final una = nuevas.length == 1;
    final alineacion = AppBreakpoints.esMobile(context)
        ? Alignment.topCenter
        : Alignment.topRight;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: alineacion,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 320, maxWidth: 400),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onAbrir,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _azul,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              LucideIcons.armchair,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  una
                                      ? 'Mesa ${nuevas.first.numero} por liberar'
                                      : 'Mesas por liberar',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  una
                                      ? 'Ya pagaron. Libera la mesa cuando se retiren.'
                                      : 'Mesas ${nuevas.map((m) => m.numero).join(', ')}: ya pagaron. Libéralas cuando se retiren.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Tooltip(
                            message: 'Cerrar aviso',
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: onCerrar,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

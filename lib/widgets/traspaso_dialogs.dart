import 'package:flutter/material.dart';

import '../data/pedidos_store.dart';
import '../data/traspasos_store.dart';
import '../models/pedido.dart';
import '../models/traspaso_pedido.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/traspaso_service.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';
import 'app_toast.dart';
import 'pago_dialogs.dart';

String _mensaje(Object e) => e is ApiException
    ? e.message
    : e.toString().replaceFirst('Exception: ', '');

// El mozo que se va elige a quién deja su pedido. Solo puede haber una
// solicitud pendiente por pedido: hasta que respondan, no hay otra.
class TraspasarPedidoDialog extends StatefulWidget {
  final Pedido pedido;
  // Administrador: reasigna el pedido a otro mozo sin que tenga que aceptar.
  final bool directo;

  const TraspasarPedidoDialog({
    super.key,
    required this.pedido,
    this.directo = false,
  });

  @override
  State<TraspasarPedidoDialog> createState() => _TraspasarPedidoDialogState();
}

class _TraspasarPedidoDialogState extends State<TraspasarPedidoDialog> {
  List<({String id, String nombre})>? _mozos;
  ({String id, String nombre})? _destino;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    TraspasoService.instance.mozosDisponibles().then((m) {
      if (mounted) setState(() => _mozos = m);
    });
  }

  Future<void> _enviar() async {
    final d = _destino;
    if (d == null || _enviando) return;
    setState(() => _enviando = true);
    try {
      if (widget.directo) {
        await TraspasoService.instance.reasignar(widget.pedido.id, d.id);
      } else {
        await TraspasoService.instance.solicitar(widget.pedido.id, d.id);
      }
      if (!mounted) return;
      Navigator.of(context).pop(d.nombre);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      showAppToast(context, _mensaje(e), type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mozos = _mozos;
    return ModalPago(
      titulo: widget.directo
          ? 'Reasignar pedido #${widget.pedido.numeroPedido}'
          : 'Traspasar pedido #${widget.pedido.numeroPedido}',
      subtitulo: widget.directo
          ? 'Pasa de inmediato al mozo que elijas'
          : 'El otro mozo debe aceptarlo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mozos == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (mozos.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'No se encontraron otros mozos activos a quienes traspasar.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            AppSelect<({String id, String nombre})>(
              label: 'Mozo que lo recibe',
              hint: 'Elige un mozo',
              value: _destino,
              items: [
                for (final m in mozos) AppSelectItem(value: m, label: m.nombre),
              ],
              onChanged: (m) => setState(() => _destino = m),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            widget.directo
                ? 'El pedido pasa a ser del mozo elegido ahora mismo, sin '
                      'que tenga que aceptarlo.'
                : 'Hasta que acepte, el pedido sigue siendo tuyo. Si lo '
                      'rechaza, continúa contigo y puedes enviarlo a otro '
                      'mozo. Solo puedes ofrecerlo a un mozo a la vez.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _destino == null || _enviando ? null : _enviar,
              child: Text(
                _enviando
                    ? 'Enviando…'
                    : (widget.directo ? 'Reasignar' : 'Enviar solicitud'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Traspasos que otros mozos le enviaron al usuario: aceptar o rechazar.
class BandejaTraspasosDialog extends StatefulWidget {
  const BandejaTraspasosDialog({super.key});

  @override
  State<BandejaTraspasosDialog> createState() => _BandejaTraspasosDialogState();
}

class _BandejaTraspasosDialogState extends State<BandejaTraspasosDialog> {
  String? _procesando;

  Future<void> _responder(TraspasoPedido t, bool aceptar) async {
    if (_procesando != null) return;
    setState(() => _procesando = t.id);
    try {
      if (aceptar) {
        await TraspasoService.instance.aceptar(t.id);
      } else {
        await TraspasoService.instance.rechazar(t.id);
      }
      if (!mounted) return;
      showAppToast(
        context,
        aceptar
            ? 'Aceptaste el pedido: ahora es tuyo.'
            : 'Rechazaste el traspaso: el pedido sigue con ${t.origenNombre}.',
        type: aceptar ? ToastType.success : ToastType.info,
      );
    } catch (e) {
      if (mounted) showAppToast(context, _mensaje(e), type: ToastType.error);
    }
    if (!mounted) return;
    setState(() => _procesando = null);
    final yo = AuthService.instance.currentUser?.id ?? '';
    if (traspasosPorResponder(yo).isEmpty) Navigator.of(context).pop();
  }

  String _detalle(TraspasoPedido t) {
    final p = pedidos.where((x) => x.id == t.pedidoId).firstOrNull;
    final numero = t.pedidoNumero ?? p?.numeroPedido ?? '';
    final donde = t.ubicacion ?? p?.ubicacion ?? '';
    return [
      if (numero.isNotEmpty) 'Pedido #$numero',
      if (donde.isNotEmpty) donde,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final yo = AuthService.instance.currentUser?.id ?? '';
    return ValueListenableBuilder<int>(
      valueListenable: traspasosRevision,
      builder: (context, _, _) {
        final lista = traspasosPorResponder(yo);
        return ModalPago(
          titulo: 'Traspasos por aceptar',
          subtitulo: 'Pedidos que otros mozos te dejan',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (lista.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No tienes traspasos pendientes',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                ),
              for (final t in lista)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _detalle(t),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'De ${t.origenNombre}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _procesando == null
                                  ? () => _responder(t, false)
                                  : null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                              ),
                              child: const Text('Rechazar'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: _procesando == null
                                  ? () => _responder(t, true)
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                              ),
                              child: const Text('Aceptar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

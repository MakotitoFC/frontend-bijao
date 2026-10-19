import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/configuracion_store.dart';
import '../data/pagos_store.dart';
import '../models/medio_pago.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';
import 'dialogo_app.dart';

const naranjaPago = Color(0xFFF07F13);

// Lo que devuelve un modal de pago cuando se toca "Regresar": el que lo abrió
// vuelve a mostrar la elección entre pago único y compartido.
class _VolverAElegirPago {
  const _VolverAElegirPago();
}

const Object volverAElegirPago = _VolverAElegirPago();

double leerMonto(String texto) =>
    double.tryParse(texto.trim().replaceAll(',', '.')) ?? 0;

// Contenedor común de los modales de pago (hoja en mobile, tarjeta en escritorio).
class ModalPago extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Widget child;
  final double anchoEscritorio;
  // Si viene, se muestra un botón "Regresar" junto al título.
  final VoidCallback? onVolver;

  const ModalPago({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.child,
    this.anchoEscritorio = 440,
    this.onVolver,
  });

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final ancho = MediaQuery.sizeOf(context).width;
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: esMobile ? ancho : anchoEscritorio,
          maxWidth: esMobile ? ancho : anchoEscritorio,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, esMobile ? 28 : 22, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (onVolver != null) ...[
                    Tooltip(
                      message: 'Regresar',
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onVolver,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Icon(
                            LucideIcons.chevronLeft,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitulo,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  BotonCerrarCircular(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SeparadorDialogo(),
              Flexible(child: SingleChildScrollView(child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

Widget tarjetaSaldo(String etiqueta, double monto) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          'S/ ${monto.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryGreen,
          ),
        ),
      ],
    ),
  );
}

// Cobra de una vez todo el saldo pendiente con un solo método de pago.
// Devuelve true si el cobro se registró, o [volverAElegirPago] si se tocó
// "Regresar".
class PagarPedidoDialog extends StatefulWidget {
  final Pedido pedido;
  final String titulo;
  final bool permiteVolver;

  const PagarPedidoDialog({
    super.key,
    required this.pedido,
    required this.titulo,
    this.permiteVolver = false,
  });

  @override
  State<PagarPedidoDialog> createState() => _PagarPedidoDialogState();
}

class _PagarPedidoDialogState extends State<PagarPedidoDialog> {
  late MedioPago _medio = mediosPagoActivos.first;
  double get _saldo => saldoPendienteDePedido(widget.pedido.id);
  // Recargo del método elegido (p. ej. tarjeta): se suma al total del cliente.
  double get _recargo => _medio.recargoSobre(_saldo);

  void _pagar() {
    final saldo = _saldo;
    if (saldo <= 0.01) return;
    final recargo = _medio.recargoSobre(saldo);
    registrarPago(
      pedido: widget.pedido,
      medioPago: _medio,
      montoAbonado: saldo,
      propina: 0,
    );
    showAppToast(
      context,
      'Cobro registrado · ${widget.titulo} · '
      'S/ ${(saldo + recargo).toStringAsFixed(2)}'
      '${recargo > 0 ? ' (incluye recargo S/ ${recargo.toStringAsFixed(2)})' : ''}',
      type: ToastType.success,
      titulo: 'Pago registrado',
    );
    Navigator.of(context).pop(true);
  }

  void _volver() => Navigator.of(context).pop(volverAElegirPago);

  // Una línea "texto ........ S/ monto" del resumen con recargo.
  Widget _filaMonto(
    String texto,
    double monto, {
    bool mas = false,
    bool fuerte = false,
  }) {
    final estilo = TextStyle(
      fontSize: fuerte ? 14 : 13,
      fontWeight: fuerte ? FontWeight.w800 : FontWeight.w500,
    );
    return Row(
      children: [
        Expanded(child: Text(texto, style: estilo)),
        Text('${mas ? '+' : ''}S/ ${monto.toStringAsFixed(2)}', style: estilo),
      ],
    );
  }

  // Un ícono que oriente según el nombre del método.
  IconData _icono(MedioPago m) {
    final n = m.medioPago.toLowerCase();
    if (n.contains('efectivo')) return LucideIcons.banknote;
    if (n.contains('tarjeta') || n.contains('visa') || n.contains('credito')) {
      return LucideIcons.creditCard;
    }
    if (n.contains('yape') || n.contains('plin') || n.contains('digital')) {
      return LucideIcons.smartphone;
    }
    return LucideIcons.wallet;
  }

  Widget _tileMedio(MedioPago m, double ancho) {
    final activo = m.id == _medio.id;
    return SizedBox(
      width: ancho,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _medio = m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            color: activo
                ? AppColors.primaryGreen.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: activo ? AppColors.primaryGreen : Colors.grey.shade300,
              width: activo ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _icono(m),
                size: 20,
                color: activo
                    ? AppColors.primaryGreenDark
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.medioPago,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: activo ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    if (m.aplicaComision)
                      Text(
                        '+${m.porcentajeComision.toStringAsFixed(1)}% recargo',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              if (activo)
                const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: AppColors.primaryGreen,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saldo = _saldo;
    return ModalPago(
      titulo: 'Pago único',
      subtitulo: 'Pedido #${widget.pedido.numeroPedido} · ${widget.titulo}',
      onVolver: widget.permiteVolver ? _volver : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tarjetaSaldo('Total a pagar', saldo),
          const SizedBox(height: 18),
          const Text(
            'Método de pago',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final ancho = (c.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final m in mediosPagoActivos) _tileMedio(m, ancho),
                ],
              );
            },
          ),
          if (_recargo > 0)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.platoDelDia.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _filaMonto('Cuenta', saldo),
                  const SizedBox(height: 4),
                  _filaMonto(
                    'Recargo ${_medio.medioPago.toLowerCase()} '
                    '(${_medio.porcentajeComision.toStringAsFixed(1)}%)',
                    _recargo,
                    mas: true,
                  ),
                  const Divider(height: 14),
                  _filaMonto('Total a cobrar', saldo + _recargo, fuerte: true),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (widget.permiteVolver) ...[
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _volver,
                    icon: const Icon(LucideIcons.chevronLeft, size: 16),
                    label: const Text('Regresar'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: saldo > 0.01 ? _pagar : null,
                  icon: const Icon(LucideIcons.banknote, size: 18),
                  label: Text(
                    'Pagar · S/ ${(saldo + _recargo).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(backgroundColor: naranjaPago),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

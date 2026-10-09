import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/configuracion_store.dart';
import '../theme/app_theme.dart';
import 'app_tag.dart';
import 'pago_dialogs.dart';

// Resultado al elegir un ticket de descuento: aplicarlo o quitar el ya aplicado.
typedef DescuentoConfigurado = ({
  String nombre,
  bool esPorcentaje,
  double monto,
  bool quitar,
});

class _TipoDescuento {
  final IconData icono;
  final String nombre;
  final bool esPorcentaje;
  final double monto;

  const _TipoDescuento({
    required this.icono,
    required this.nombre,
    required this.esPorcentaje,
    required this.monto,
  });
}

// Descuento extra del pedido: tickets de distintos tipos de descuento.
class DescuentoDialog extends StatefulWidget {
  // Consumo sobre el que se calculan los porcentajes.
  final double base;
  // Nombres de los descuentos que ya tiene aplicados el pedido.
  final Set<String> aplicados;

  const DescuentoDialog({
    super.key,
    required this.base,
    this.aplicados = const {},
  });

  @override
  State<DescuentoDialog> createState() => _DescuentoDialogState();
}

class _DescuentoDialogState extends State<DescuentoDialog> {
  final _nombre = TextEditingController();
  final _monto = TextEditingController();
  bool _esPorcentaje = true;

  @override
  void dispose() {
    _nombre.dispose();
    _monto.dispose();
    super.dispose();
  }

  List<_TipoDescuento> get _tipos => [
    const _TipoDescuento(
      icono: LucideIcons.heart,
      nombre: 'Cliente frecuente',
      esPorcentaje: true,
      monto: 10,
    ),
    const _TipoDescuento(
      icono: LucideIcons.gift,
      nombre: 'Cortesía de la casa',
      esPorcentaje: true,
      monto: 15,
    ),
    if (config.descuentoEmpleadoHabilitado)
      _TipoDescuento(
        icono: LucideIcons.users,
        nombre: 'Empleado',
        esPorcentaje: true,
        monto: config.descuentoEmpleadoPorcentaje,
      ),
    const _TipoDescuento(
      icono: LucideIcons.banknote,
      nombre: 'Descuento S/ 5',
      esPorcentaje: false,
      monto: 5,
    ),
    const _TipoDescuento(
      icono: LucideIcons.coins,
      nombre: 'Descuento S/ 10',
      esPorcentaje: false,
      monto: 10,
    ),
  ];

  double get _montoPersonalizado =>
      double.tryParse(_monto.text.trim().replaceAll(',', '.')) ?? 0;

  void _resolver(String nombre, bool esPorcentaje, double monto, bool quitar) {
    Navigator.of(context).pop<DescuentoConfigurado>((
      nombre: nombre,
      esPorcentaje: esPorcentaje,
      monto: monto,
      quitar: quitar,
    ));
  }

  void _aplicarPersonalizado() {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty || _montoPersonalizado <= 0) return;
    _resolver(nombre, _esPorcentaje, _montoPersonalizado, false);
  }

  String _valor(bool esPorcentaje, double monto) => esPorcentaje
      ? '${monto.toStringAsFixed(monto % 1 == 0 ? 0 : 1)}%'
      : 'S/ ${monto.toStringAsFixed(monto % 1 == 0 ? 0 : 2)}';

  @override
  Widget build(BuildContext context) {
    return ModalPago(
      titulo: 'Descuento extra',
      subtitulo: 'Elige un ticket de descuento',
      anchoEscritorio: 460,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          4,
          4,
          4,
          4 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final t in _tipos) ...[_ticket(t), const SizedBox(height: 14)],
            _ticketPersonalizado(),
          ],
        ),
      ),
    );
  }

  Widget _ticket(_TipoDescuento t) {
    final aplicado = widget.aplicados.contains(t.nombre);
    final ahorro = t.esPorcentaje ? widget.base * t.monto / 100 : t.monto;
    return _MarcoTicket(
      icono: t.icono,
      lateral: t.esPorcentaje ? 'PORCENTAJE' : 'SOLES',
      centro: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.nombre.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _valor(t.esPorcentaje, t.monto),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryGreenDark,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'OFF',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          Text(
            'Ahorras S/ ${ahorro.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          aplicado
              ? OutlinedButton(
                  onPressed: () =>
                      _resolver(t.nombre, t.esPorcentaje, t.monto, true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text('Quitar'),
                )
              : FilledButton(
                  onPressed: () =>
                      _resolver(t.nombre, t.esPorcentaje, t.monto, false),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                  ),
                  child: const Text('Aplicar'),
                ),
        ],
      ),
    );
  }

  Widget _ticketPersonalizado() {
    return _MarcoTicket(
      icono: LucideIcons.pencil,
      lateral: 'A MEDIDA',
      centro: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PERSONALIZADO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nombre,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Nombre del descuento'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              AppTag(
                etiqueta: '%',
                activo: _esPorcentaje,
                onTap: () => setState(() => _esPorcentaje = true),
              ),
              AppTag(
                etiqueta: 'S/',
                activo: !_esPorcentaje,
                onTap: () => setState(() => _esPorcentaje = false),
              ),
              Expanded(
                child: TextField(
                  controller: _monto,
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    hintText: _esPorcentaje ? 'Monto (%)' : 'Monto (S/)',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed:
                  _nombre.text.trim().isNotEmpty && _montoPersonalizado > 0
                  ? _aplicarPersonalizado
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Aplicar'),
            ),
          ),
        ],
      ),
    );
  }
}

// Ticket: ícono a la izquierda, línea punteada, contenido, texto vertical a la
// derecha y muescas en los costados.
class _MarcoTicket extends StatelessWidget {
  final IconData icono;
  final String lateral;
  final Widget centro;

  const _MarcoTicket({
    required this.icono,
    required this.lateral,
    required this.centro,
  });

  @override
  Widget build(BuildContext context) {
    return PhysicalShape(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      clipper: const _TicketClipper(),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 84,
              child: Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icono,
                    size: 22,
                    color: AppColors.primaryGreenDark,
                  ),
                ),
              ),
            ),
            CustomPaint(
              size: const Size(1, double.infinity),
              painter: _LineaPunteada(Colors.grey.shade400),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Align(alignment: Alignment.centerLeft, child: centro),
              ),
            ),
            SizedBox(
              width: 32,
              child: Center(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    lateral,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper();

  static const _radio = 14.0;
  static const _muesca = 10.0;

  @override
  Path getClip(Size size) {
    final tarjeta = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(_radio),
        ),
      );
    final y = size.height / 2;
    final muescas = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, y), radius: _muesca))
      ..addOval(
        Rect.fromCircle(center: Offset(size.width, y), radius: _muesca),
      );
    return Path.combine(PathOperation.difference, tarjeta, muescas);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _LineaPunteada extends CustomPainter {
  final Color color;

  _LineaPunteada(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    const trazo = 5.0;
    const hueco = 4.0;
    for (var y = 12.0; y < size.height - 12; y += trazo + hueco) {
      canvas.drawLine(Offset(0, y), Offset(0, y + trazo), pincel);
    }
  }

  @override
  bool shouldRepaint(covariant _LineaPunteada old) => old.color != color;
}

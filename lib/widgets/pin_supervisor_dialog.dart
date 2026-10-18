import 'package:flutter/material.dart';

import '../services/pedido_mozo_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'dialogo_app.dart';
import 'campo_texto.dart';

// Pide a un supervisor (con permiso de otorgar descuentos) que ingrese su PIN y
// devuelve su id, o null si se cancela.
Future<String?> pedirAutorizacionSupervisor(
  BuildContext context, {
  String motivo = 'Este descuento necesita la autorización de un supervisor.',
}) {
  return showBlurDialog<String>(
    context: context,
    builder: (_) => PinSupervisorDialog(motivo: motivo),
  );
}

class PinSupervisorDialog extends StatefulWidget {
  final String motivo;

  const PinSupervisorDialog({super.key, required this.motivo});

  @override
  State<PinSupervisorDialog> createState() => _PinSupervisorDialogState();
}

class _PinSupervisorDialogState extends State<PinSupervisorDialog> {
  final _pin = TextEditingController();
  bool _validando = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _validar() async {
    final pin = _pin.text.trim();
    if (pin.isEmpty || _validando) return;
    setState(() {
      _validando = true;
      _error = null;
    });
    final r = await PedidoMozoService.instance.validarPin(pin);
    if (!mounted) return;
    if (r.valido && r.usuarioId != null) {
      Navigator.of(context).pop(r.usuarioId);
      return;
    }
    setState(() {
      _validando = false;
      _error = r.mensaje ?? 'PIN incorrecto o sin permiso.';
      _pin.clear();
    });
  }

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
          minWidth: esMobile ? ancho : 380,
          maxWidth: esMobile ? ancho : 380,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            esMobile ? 28 : 22,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Autorización de supervisor',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  BotonCerrarCircular(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SeparadorDialogo(),
              Text(
                widget.motivo,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),
              CampoTexto(
                controller: _pin,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _validar(),
                decoration: InputDecoration(
                  labelText: 'PIN del supervisor',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _validando ? null : _validar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
                child: _validando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Autorizar',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

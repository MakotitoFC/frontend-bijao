import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'campo_texto.dart';
import 'dialogo_app.dart';

// El usuario cambia su propio PIN de supervisor (el que autoriza descuentos).
// El PIN tiene de 4 a 10 dígitos. Devuelve true si se guardó.
//
// Con [obligatorio] (el backend pide cambiar el PIN predeterminado) la ventana
// no se puede cerrar sin guardarlo.
class CambiarPinDialog extends StatefulWidget {
  final bool obligatorio;

  const CambiarPinDialog({super.key, this.obligatorio = false});

  @override
  State<CambiarPinDialog> createState() => _CambiarPinDialogState();
}

class _CambiarPinDialogState extends State<CambiarPinDialog> {
  static final _formatoPin = RegExp(r'^\d{4,10}$');

  final _nuevo = TextEditingController();
  final _repetir = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nuevo.dispose();
    _repetir.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nuevo = _nuevo.text.trim();
    if (!_formatoPin.hasMatch(nuevo)) {
      setState(() => _error = 'El PIN debe tener de 4 a 10 dígitos.');
      return;
    }
    if (nuevo != _repetir.text.trim()) {
      setState(() => _error = 'Los dos PIN no coinciden.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ApiClient.instance.put('/api/auth/pin', body: {'nuevo_pin': nuevo});
      await AuthService.instance.marcarPinCambiado();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = e is ApiException ? e.message : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.obligatorio,
      child: DialogoApp(
        titulo: widget.obligatorio ? 'Cambia tu PIN' : 'Cambiar mi PIN',
        ancho: 400,
        mostrarCerrar: !widget.obligatorio,
        acciones: [
          if (!widget.obligatorio)
            OutlinedButton(
              onPressed: _guardando
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            child: _guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Guardar PIN'),
          ),
        ],
        children: [
          Text(
            widget.obligatorio
                ? 'Tu PIN todavía es el predeterminado. Elige uno nuevo para '
                      'poder autorizar descuentos. Debe tener de 4 a 10 dígitos.'
                : 'Es el código con el que autorizas descuentos de otros '
                      'usuarios. De 4 a 10 dígitos.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          CampoTexto(
            controller: _nuevo,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10,
            decoration: const InputDecoration(
              labelText: 'Nuevo PIN',
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          CampoTexto(
            controller: _repetir,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10,
            onSubmitted: (_) => _guardar(),
            decoration: InputDecoration(
              labelText: 'Repetir el PIN',
              counterText: '',
              errorText: _error,
            ),
          ),
        ],
      ),
    );
  }
}

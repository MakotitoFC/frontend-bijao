import 'package:flutter/material.dart';

import '../data/pedidos_store.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';

// Edita los datos de un pedido ya registrado: cliente, celular, dirección
// (delivery) y notas. Devuelve true si se guardó.
class EditarPedidoDialog extends StatefulWidget {
  final Pedido pedido;

  const EditarPedidoDialog({super.key, required this.pedido});

  @override
  State<EditarPedidoDialog> createState() => _EditarPedidoDialogState();
}

class _EditarPedidoDialogState extends State<EditarPedidoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.pedido.clienteNombre);
  late final _celular = TextEditingController(
    text: widget.pedido.clienteCelular,
  );
  late final _direccion = TextEditingController(
    text: widget.pedido.direccionDelivery,
  );
  late final _notas = TextEditingController(text: widget.pedido.notas);

  bool get _esDelivery => widget.pedido.tipoPedido == 'delivery';

  @override
  void dispose() {
    _nombre.dispose();
    _celular.dispose();
    _direccion.dispose();
    _notas.dispose();
    super.dispose();
  }

  String? _texto(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    actualizarDatosPedido(
      widget.pedido.id,
      clienteNombre: _texto(_nombre),
      clienteCelular: _esDelivery
          ? _texto(_celular)
          : widget.pedido.clienteCelular,
      direccionDelivery: _esDelivery
          ? _texto(_direccion)
          : widget.pedido.direccionDelivery,
      notas: _texto(_notas),
    );
    Navigator.of(context).pop(true);
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
          minWidth: esMobile ? ancho : 440,
          maxWidth: esMobile ? ancho : 440,
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              28,
              esMobile ? 28 : 22,
              28,
              28 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Editar pedido #${widget.pedido.numeroPedido}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nombre,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del cliente',
                  ),
                ),
                if (_esDelivery) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _celular,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Celular / WhatsApp',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa el celular'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _direccion,
                    decoration: const InputDecoration(
                      labelText: 'Dirección de entrega',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa la dirección'
                        : null,
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notas,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notas del pedido',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 22),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _guardar,
                    child: const Text('Guardar cambios'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../data/mesas_store.dart';
import '../models/pedido.dart';
import '../services/pedido_mozo_mapper.dart';
import '../theme/app_theme.dart';
import 'dialogo_app.dart';
import 'icono_mesa.dart';
import 'campo_texto.dart';

// Cómo queda el pedido tras el cambio.
class CambioEntrega {
  final String tipo; // 'mesa' | 'llevar' | 'delivery'
  final String? mesaId;
  final bool aplicaTaper;
  final DatosDelivery? delivery;

  const CambioEntrega({
    required this.tipo,
    this.mesaId,
    this.aplicaTaper = false,
    this.delivery,
  });
}

// Cambia el pedido de mesa, o entre mesa / para llevar / delivery.
class CambiarEntregaDialog extends StatefulWidget {
  final Pedido pedido;

  const CambiarEntregaDialog({super.key, required this.pedido});

  @override
  State<CambiarEntregaDialog> createState() => _CambiarEntregaDialogState();
}

class _CambiarEntregaDialogState extends State<CambiarEntregaDialog> {
  late String _tipo = switch (widget.pedido.tipoPedido) {
    'delivery' => 'delivery',
    'llevar' => 'llevar',
    _ => widget.pedido.mesaNumero > 0 ? 'mesa' : 'llevar',
  };
  String? _mesaId;
  bool _aplicaTaper = false;
  final _direccion = TextEditingController();
  final _telefono = TextEditingController();
  final _envio = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _direccion.dispose();
    _telefono.dispose();
    _envio.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (_tipo == 'mesa' && _mesaId == null) {
      setState(() => _error = 'Elige la mesa de destino.');
      return;
    }
    DatosDelivery? delivery;
    if (_tipo == 'delivery') {
      if (_direccion.text.trim().isEmpty) {
        setState(() => _error = 'Ingresa la dirección de entrega.');
        return;
      }
      delivery = DatosDelivery(
        direccion: _direccion.text.trim(),
        telefono: _telefono.text.trim(),
        costoEnvio: double.tryParse(_envio.text.trim().replaceAll(',', '.')),
      );
    }
    Navigator.of(context).pop(
      CambioEntrega(
        tipo: _tipo,
        mesaId: _tipo == 'mesa' ? _mesaId : null,
        aplicaTaper: _tipo != 'mesa' && _aplicaTaper,
        delivery: delivery,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final ancho = MediaQuery.sizeOf(context).width;
    // Todas las mesas; la actual sale marcada y no se puede elegir de nuevo.
    final destinos = [...mesas]..sort((a, b) => a.numero.compareTo(b.numero));
    final actual = widget.pedido.mesaNumero;
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: esMobile ? ancho : 600,
          maxWidth: esMobile ? ancho : 600,
        ),
        child: SingleChildScrollView(
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
                      'Cambiar mesa o entrega',
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (valor, texto) in const [
                    ('mesa', 'Mesa'),
                    ('llevar', 'Para llevar'),
                    ('delivery', 'Delivery'),
                  ])
                    _PildoraTipo(
                      texto: texto,
                      activa: _tipo == valor,
                      onTap: () => setState(() {
                        _tipo = valor;
                        _error = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (_tipo == 'mesa') ...[
                Text(
                  actual > 0
                      ? 'Mesa de destino (ahora en la mesa $actual)'
                      : 'Mesa de destino',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                // La grilla reparte todo el ancho: sin hueco a la derecha.
                LayoutBuilder(
                  builder: (context, c) {
                    const hueco = 10.0;
                    const minimo = 62.0;
                    final columnas = ((c.maxWidth + hueco) / (minimo + hueco))
                        .floor()
                        .clamp(1, 50);
                    final ancho =
                        (c.maxWidth - hueco * (columnas - 1)) / columnas;
                    return Wrap(
                      spacing: hueco,
                      runSpacing: 12,
                      children: [
                        for (final m in destinos)
                          IconoMesa(
                            ancho: ancho,
                            numero: m.numero,
                            ocupada: m.estaOcupada,
                            actual: m.numero == actual && actual > 0,
                            seleccionada: _mesaId == m.id,
                            onTap: () => setState(() {
                              _mesaId = m.id;
                              _error = null;
                            }),
                          ),
                      ],
                    );
                  },
                ),
                if (_mesaId != null &&
                    destinos.any((m) => m.id == _mesaId && m.estaOcupada))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'La mesa está ocupada: el pedido se traspasa a esa cuenta.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ] else ...[
                if (_tipo == 'delivery') ...[
                  CampoTexto(
                    controller: _direccion,
                    decoration: const InputDecoration(labelText: 'Dirección'),
                  ),
                  const SizedBox(height: 8),
                  CampoTexto(
                    controller: _telefono,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Celular'),
                  ),
                  const SizedBox(height: 8),
                  CampoTexto(
                    controller: _envio,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Costo de envío (S/)',
                    ),
                  ),
                ],
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _aplicaTaper,
                  onChanged: (v) => setState(() => _aplicaTaper = v ?? false),
                  title: const Text('Cobrar táper (el cliente no trajo)'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _confirmar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
                child: const Text(
                  'Aplicar cambio',
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

// Tipo de entrega: píldora negra con texto blanco al elegirla.
class _PildoraTipo extends StatelessWidget {
  final String texto;
  final bool activa;
  final VoidCallback onTap;

  const _PildoraTipo({
    required this.texto,
    required this.activa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: activa ? AppColors.navbar : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: activa ? AppColors.navbar : Colors.grey.shade300,
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: activa ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

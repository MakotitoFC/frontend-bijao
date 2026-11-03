import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../theme/app_theme.dart';

// Para quién es el pedido y de qué tipo.
typedef EleccionNuevoPedido = ({String destinatario, String tipo});

// "Nuevo pedido" en un solo modal tipo carrusel, con dos pasos: para quién es
// (cliente, familia o empleado) y el tipo (mesa, para llevar o delivery). Los
// dos pasos usan el mismo diseño de tarjetas y el cambio de uno a otro desliza
// el contenido sin saltos; la flecha de arriba vuelve al paso anterior. Sin
// [conDestinatario] (el mozo) empieza directo en el tipo.
class ElegirNuevoPedidoDialog extends StatefulWidget {
  final bool conDestinatario;

  const ElegirNuevoPedidoDialog({super.key, required this.conDestinatario});

  @override
  State<ElegirNuevoPedidoDialog> createState() =>
      _ElegirNuevoPedidoDialogState();
}

class _ElegirNuevoPedidoDialogState extends State<ElegirNuevoPedidoDialog> {
  late int _paso = widget.conDestinatario ? 0 : 1;
  late final PageController _paginas = PageController(initialPage: _paso);
  String _destinatario = 'cliente';

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  void _ir(int paso) {
    setState(() => _paso = paso);
    _paginas.animateToPage(
      paso,
      // Lenta y con arranque y frenada suaves: se nota el deslizamiento.
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutQuart,
    );
  }

  void _elegirTipo(String tipo) =>
      Navigator.of(context)
          .pop<EleccionNuevoPedido>((destinatario: _destinatario, tipo: tipo));

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    // Las dos páginas miden lo mismo: así el modal no cambia de alto al pasar
    // de una a otra.
    // Ancho amplio, sin pasarse de la pantalla; con menos ancho las tarjetas
    // necesitan más alto para el texto.
    final ancho = esMobile ? anchoPantalla : min(780.0, anchoPantalla - 32);
    final alto = esMobile ? 376.0 : (ancho >= 740 ? 224.0 : 276.0);
    final conAtras = widget.conDestinatario && _paso == 1;
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: ancho,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    child: conAtras
                        ? Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _BotonCircular(
                              icono: Icons.chevron_left,
                              tamanoIcono: 20,
                              onTap: () => _ir(0),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const Expanded(
                    child: Text(
                      'Nuevo pedido',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _BotonCircular(
                    icono: Icons.close,
                    tamanoIcono: 16,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                child: Align(
                  key: ValueKey(_paso),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _paso == 0
                        ? '¿Para quién es este pedido?'
                        : '¿Dónde va este pedido?',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: alto,
                child: PageView(
                  controller: _paginas,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _Pagina(
                      esMobile: esMobile,
                      tarjetas: [
                        _DatoTarjeta(
                          icono: LucideIcons.userRound,
                          titulo: 'Cliente',
                          descripcion: 'Un cliente del local: se cobra la cuenta normal.',
                          onTap: () {
                            _destinatario = 'cliente';
                            _ir(1);
                          },
                        ),
                        _DatoTarjeta(
                          icono: LucideIcons.house,
                          titulo: 'Familia',
                          descripcion:
                              'Hijos y familia de los dueños: cuenta cero '
                              '(descuento del 100 %), sin cobro.',
                          onTap: () {
                            _destinatario = 'familia';
                            _ir(1);
                          },
                        ),
                        _DatoTarjeta(
                          icono: LucideIcons.users,
                          titulo: 'Empleado',
                          descripcion:
                              'Consumo del personal: cada plato con su precio '
                              'de empleado, pagado por abonos.',
                          onTap: () {
                            _destinatario = 'empleado';
                            _ir(1);
                          },
                        ),
                      ],
                    ),
                    _Pagina(
                      esMobile: esMobile,
                      tarjetas: [
                        _DatoTarjeta(
                          icono: LucideIcons.utensils,
                          titulo: 'Mesa',
                          descripcion:
                              'Pedido para consumir en una mesa del local.',
                          onTap: () => _elegirTipo('mesa'),
                        ),
                        _DatoTarjeta(
                          icono: LucideIcons.packageCheck,
                          titulo: 'Para llevar',
                          descripcion:
                              'El cliente recoge su pedido en el local.',
                          onTap: () => _elegirTipo('llevar'),
                        ),
                        _DatoTarjeta(
                          icono: LucideIcons.bike,
                          titulo: 'Delivery',
                          descripcion: 'Pedido para entregar a domicilio.',
                          onTap: () => _elegirTipo('delivery'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonCircular extends StatelessWidget {
  final IconData icono;
  final double tamanoIcono;
  final VoidCallback onTap;

  const _BotonCircular({
    required this.icono,
    required this.tamanoIcono,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icono, size: tamanoIcono, color: Colors.grey.shade700),
      ),
    );
  }
}

class _DatoTarjeta {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;

  const _DatoTarjeta({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.onTap,
  });
}

// Una página del carrusel: tres tarjetas, en fila en escritorio y una bajo otra
// en el celular.
class _Pagina extends StatelessWidget {
  final bool esMobile;
  final List<_DatoTarjeta> tarjetas;

  const _Pagina({required this.esMobile, required this.tarjetas});

  @override
  Widget build(BuildContext context) {
    if (esMobile) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tarjetas.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _Tarjeta(dato: tarjetas[i], compacta: true),
            ],
          ],
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tarjetas.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(child: _Tarjeta(dato: tarjetas[i])),
        ],
      ],
    );
  }
}

// Tarjeta que se sombrea de verde al pasar el cursor por encima.
class _Tarjeta extends StatefulWidget {
  final _DatoTarjeta dato;
  // En celular: ícono a la izquierda y el texto al lado, para que las tres
  // tarjetas quepan sin desplazarse.
  final bool compacta;

  const _Tarjeta({required this.dato, this.compacta = false});

  @override
  State<_Tarjeta> createState() => _TarjetaState();
}

class _TarjetaState extends State<_Tarjeta> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.dato;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: d.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _hover
                ? AppColors.primaryGreen.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hover ? AppColors.primaryGreen : Colors.grey.shade300,
              width: _hover ? 1.5 : 1,
            ),
          ),
          child: widget.compacta
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        d.icono,
                        size: 22,
                        color: _hover
                            ? AppColors.primaryGreenDark
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            d.titulo,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            d.descripcion,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      d.icono,
                      size: 26,
                      color: _hover
                          ? AppColors.primaryGreenDark
                          : Colors.grey.shade700,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      d.titulo,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _hover
                            ? AppColors.primaryGreenDark
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      d.descripcion,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

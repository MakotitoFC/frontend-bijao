import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/inventario_store.dart';
import '../data/mesas_por_liberar_store.dart';
import '../models/mesa.dart';
import '../models/producto_inventario.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../services/pedido_mozo_service.dart';
import '../services/pedido_service.dart';
import '../utils/blur_dialog.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';
import 'inventario/inventario_comun.dart' show cantidadTexto, unidadDe;
import 'pago_dialogs.dart';

const _azul = Color(0xFF2563EB);
const _ambar = Color(0xFFD97706);

// Quien puede entrar a Inventario ve también los avisos de stock.
bool _veInventario() =>
    AuthService.instance.currentUser?.tienePermiso('VER.VISTA_INVENTARIO') ??
    false;

// Productos con el stock por agotarse que este usuario debe ver.
List<ProductoInventario> _stockPorAgotarse() =>
    _veInventario() ? stockBajoNotifier.value : const [];

// Una notificación: lo que se muestra en el aviso de pantalla.
class _ItemAviso {
  final IconData icono;
  final Color color;
  final String titulo;
  final String texto;

  const _ItemAviso({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.texto,
  });
}

// Aviso de mesas nuevas por liberar.
_ItemAviso _avisoDeMesas(List<Mesa> nuevas) {
  final una = nuevas.length == 1;
  return _ItemAviso(
    icono: LucideIcons.armchair,
    color: _azul,
    titulo: una
        ? 'Mesa ${nuevas.first.numero} por liberar'
        : 'Mesas por liberar',
    texto: una
        ? 'Ya pagaron. Libera la mesa cuando se retiren.'
        : 'Mesas ${nuevas.map((m) => m.numero).join(', ')}: ya pagaron. '
              'Libéralas cuando se retiren.',
  );
}

String _detalleStock(ProductoInventario p) => p.stockActual <= 0
    ? 'Se agotó. Repón pronto.'
    : 'Quedan ${cantidadTexto(p.stockActual)} ${unidadDe(p.unidadProductoId)} '
          '(mínimo ${cantidadTexto(p.stockMinimo)}).';

// Aviso de productos nuevos con el stock por agotarse.
_ItemAviso _avisoDeStock(List<ProductoInventario> nuevos) {
  final una = nuevos.length == 1;
  final algunoAgotado = nuevos.any((p) => p.stockActual <= 0);
  String nombres() {
    final primeros = nuevos.take(4).map((p) => p.nombre).join(', ');
    return nuevos.length > 4
        ? '$primeros y ${nuevos.length - 4} más'
        : primeros;
  }

  return _ItemAviso(
    icono: LucideIcons.package,
    color: algunoAgotado ? AppColors.error : _ambar,
    titulo: una
        ? '${nuevos.first.nombre}: '
              '${nuevos.first.stockActual <= 0 ? 'sin stock' : 'stock bajo'}'
        : 'Stock por agotarse',
    texto: una ? _detalleStock(nuevos.first) : '${nombres()}: repón pronto.',
  );
}

// Campana del header: cuenta lo que hay por atender y, al tocarla, abre el
// modal de notificaciones. Avisa de las mesas por liberar (ya pagaron y la mesa
// sigue ocupada; la lista la da el servidor y llega en vivo) y del stock de
// inventario que se está acabando.
class CampanaNotificaciones extends StatefulWidget {
  // Lleva a Inventario desde un aviso de stock (si el usuario puede entrar).
  final VoidCallback? onIrAInventario;

  const CampanaNotificaciones({super.key, this.onIrAInventario});

  @override
  State<CampanaNotificaciones> createState() => _CampanaNotificacionesState();
}

class _CampanaNotificacionesState extends State<CampanaNotificaciones> {
  // Lo que ya se avisó en pantalla: solo se avisa de lo nuevo. Sigue en la
  // campana hasta que se atienda.
  Set<String> _avisadas = {};
  Set<String> _avisadasStock = {};
  // Aviso en pantalla (tarjeta con una "x" gris); se queda hasta cerrarlo.
  OverlayEntry? _aviso;
  late final Listenable _fuentes = Listenable.merge([
    mesasPorLiberarNotifier,
    stockBajoNotifier,
  ]);

  @override
  void initState() {
    super.initState();
    _fuentes.addListener(_avisarNuevas);
    if (PedidoMozoService.instance.activo) {
      recargarMesasPorLiberar().catchError((Object _) {});
    }
    if (_veInventario()) {
      // Lee el inventario para saber qué stock está bajo.
      CatalogService.instance.cargarProductosInventario().ignore();
    }
  }

  @override
  void dispose() {
    _fuentes.removeListener(_avisarNuevas);
    _cerrarAviso();
    super.dispose();
  }

  void _cerrarAviso() {
    _aviso?.remove();
    _aviso = null;
  }

  // Cada mesa por liberar o producto con stock bajo nuevo se muestra en pantalla
  // como una tarjeta que queda hasta cerrarla con la "x"; la notificación sigue
  // en la campana hasta que se atienda.
  void _avisarNuevas() {
    if (!mounted) return;
    final lista = mesasPorLiberarNotifier.value;
    final stock = _stockPorAgotarse();
    final nuevas = [
      for (final m in lista)
        if (!_avisadas.contains(m.id)) m,
    ];
    final nuevosStock = [
      for (final p in stock)
        if (!_avisadasStock.contains(p.id)) p,
    ];
    _avisadas = {for (final m in lista) m.id};
    _avisadasStock = {for (final p in stock) p.id};
    // Ya no queda nada por atender: el aviso sobra.
    if (lista.isEmpty && stock.isEmpty) {
      _cerrarAviso();
      return;
    }
    if (nuevas.isEmpty && nuevosStock.isEmpty) return;
    _cerrarAviso();
    final overlay = Overlay.of(context, rootOverlay: true);
    _aviso = OverlayEntry(
      builder: (_) => _AvisoPantalla(
        items: [
          if (nuevas.isNotEmpty) _avisoDeMesas(nuevas),
          if (nuevosStock.isNotEmpty) _avisoDeStock(nuevosStock),
        ],
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
    if (_veInventario()) {
      CatalogService.instance.cargarProductosInventario().ignore();
    }
    await showBlurDialog<void>(
      context: context,
      builder: (_) => PanelNotificaciones(
        onIrAInventario: widget.onIrAInventario == null
            ? null
            : () {
                Navigator.of(context).pop();
                widget.onIrAInventario!();
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _fuentes,
      builder: (context, _) {
        final mesas = mesasPorLiberarNotifier.value.length;
        final stock = _stockPorAgotarse().length;
        final n = mesas + stock;
        final agotado = _stockPorAgotarse().any((p) => p.stockActual <= 0);
        final color = n == 0
            ? Colors.grey.shade600
            : (mesas == 0 ? (agotado ? AppColors.error : _ambar) : _azul);
        return Tooltip(
          message: n == 0
              ? 'Notificaciones'
              : [
                  if (mesas > 0) '$mesas por liberar',
                  if (stock > 0) '$stock con stock bajo',
                ].join(' · '),
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
                    child: Icon(LucideIcons.bell, size: 20, color: color),
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
                        color: color,
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

// Modal con las notificaciones: una tarjeta por mesa por liberar (con su botón
// Liberar) y una por producto con el stock por agotarse.
class PanelNotificaciones extends StatelessWidget {
  // Lleva a Inventario desde una tarjeta de stock (null: sin botón).
  final VoidCallback? onIrAInventario;

  const PanelNotificaciones({super.key, this.onIrAInventario});

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

  // Tarjeta de una notificación: icono de color, título, texto y, si hay, su
  // botón.
  Widget _tarjetaBase({
    required IconData icono,
    required Color color,
    required String titulo,
    required String texto,
    Widget? boton,
  }) {
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
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icono, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  texto,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
                if (boton != null) ...[const SizedBox(height: 10), boton],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _boton(String texto, Color color, VoidCallback onPressed) =>
      FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(
          texto,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      );

  Widget _tarjetaMesa(BuildContext context, Mesa m) => _tarjetaBase(
    icono: LucideIcons.armchair,
    color: _azul,
    titulo: 'Mesa ${m.numero} por liberar',
    texto: 'Ya pagaron. Libera la mesa cuando se retiren.',
    boton: _boton('Liberar', _azul, () => _liberar(context, m)),
  );

  Widget _tarjetaStock(ProductoInventario p) {
    final agotado = p.stockActual <= 0;
    final color = agotado ? AppColors.error : _ambar;
    return _tarjetaBase(
      icono: LucideIcons.package,
      color: color,
      titulo: '${p.nombre}: ${agotado ? 'sin stock' : 'stock bajo'}',
      texto: _detalleStock(p),
      boton: onIrAInventario == null
          ? null
          : _boton('Ir a Inventario', color, onIrAInventario!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        mesasPorLiberarNotifier,
        stockBajoNotifier,
      ]),
      builder: (context, _) {
        final mesas = mesasPorLiberarNotifier.value;
        final stock = _stockPorAgotarse();
        final total = mesas.length + stock.length;
        final resumen = [
          if (mesas.isNotEmpty)
            mesas.length == 1
                ? '1 mesa por liberar'
                : '${mesas.length} mesas por liberar',
          if (stock.isNotEmpty)
            stock.length == 1
                ? '1 producto con stock bajo'
                : '${stock.length} productos con stock bajo',
        ].join(' · ');
        final tarjetas = <Widget>[
          for (final m in mesas) _tarjetaMesa(context, m),
          for (final p in stock) _tarjetaStock(p),
        ];
        return ModalPago(
          titulo: 'Notificaciones',
          subtitulo: total == 0 ? 'Estás al día.' : resumen,
          anchoEscritorio: 440,
          child: total == 0
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
                    for (var i = 0; i < tarjetas.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      tarjetas[i],
                    ],
                  ],
                ),
        );
      },
    );
  }
}

// Aviso en pantalla: tarjetas arriba a la derecha (una por tipo de aviso) con
// una "x" gris para cerrarlas. Al tocarlas se abre el modal de notificaciones.
class _AvisoPantalla extends StatelessWidget {
  final List<_ItemAviso> items;
  final VoidCallback onAbrir;
  final VoidCallback onCerrar;

  const _AvisoPantalla({
    required this.items,
    required this.onAbrir,
    required this.onCerrar,
  });

  Widget _tarjeta(_ItemAviso item, {required bool conCerrar}) {
    return Container(
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
                  color: item.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icono, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.titulo,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.texto,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (conCerrar)
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
                )
              else
                const SizedBox(width: 30),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      // La "x" de la primera cierra todo el aviso.
                      _tarjeta(items[i], conCerrar: i == 0),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

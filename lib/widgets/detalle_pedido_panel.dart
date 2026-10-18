import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../config/app_config.dart';
import '../data/disponibilidad_store.dart';
import '../data/incidencias_store.dart';
import '../data/insumos_store.dart';
import '../data/mesas_store.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../data/promociones_store.dart';
import '../data/usuarios_store.dart';
import '../models/incidencia.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/disponibilidad_service.dart';
import '../services/impresion_service.dart';
import '../services/pedido_mozo_service.dart';
import '../services/pedido_service.dart';
import '../utils/blur_dialog.dart';
import '../utils/nota_pedido.dart';
import '../utils/uuid_helper.dart';
import 'anulacion_dialog.dart';
import 'app_toast.dart';
import 'cambiar_entrega_dialog.dart';
import 'pin_supervisor_dialog.dart';
import 'boleta_pedido_dialog.dart';
import 'agregar_producto_dialog.dart';
import 'app_tag.dart';
import 'descuento_dialog.dart';
import 'boletas_pagadores_dialog.dart';
import 'menu_flotante.dart';
import 'pago_compartido_dialog.dart';
import 'pago_dialogs.dart';
import 'promocion_pedido_dialogs.dart';
import 'propina_dialog.dart';
import 'reportar_problema_dialog.dart';
import 'tupper_dialog.dart';
import 'dialogo_app.dart';
import 'campo_texto.dart';

const _naranjaPago = Color(0xFFF07F13);
const _prefijoDescuento = 'Descuento: ';

String tituloPedido(Pedido p) => p.ubicacion;

String nombreMeseroDe(Pedido p) {
  final nombre = p.mozoNombre;
  if (nombre != null && nombre.isNotEmpty) return nombre;
  for (final u in usuarios) {
    if (u.id == p.usuarioId) return u.nombre;
  }
  return '—';
}

// Color por `pedidos.estado`.
({Color color, String texto}) paletaEstadoPedido(String estado) {
  switch (estado.toLowerCase()) {
    case 'servido':
      return (color: const Color(0xFF0284C7), texto: 'Servido');
    case 'pagado':
      return (color: const Color(0xFF16A34A), texto: 'Pagado');
    case 'devuelto':
      return (color: const Color(0xFFDC2626), texto: 'Devuelto');
    case 'anulado':
      return (color: const Color(0xFF6B7280), texto: 'Anulado');
    case 'pendiente':
    case 'pedido':
    default:
      return (color: AppColors.pendiente, texto: 'Pendiente');
  }
}

// Etiqueta que identifica un pedido para el personal (empleado).
class TagEmpleado extends StatelessWidget {
  const TagEmpleado({super.key});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF7C3AED);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.users, size: 11, color: color),
          SizedBox(width: 4),
          Text(
            'Empleado',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Píldora sólida con el estado del pedido, interactiva con selector de estados.
class BadgeEstadoPedido extends StatelessWidget {
  final String estado;
  final ValueChanged<String>? onCambiarEstado;

  const BadgeEstadoPedido(this.estado, {super.key, this.onCambiarEstado});

  Widget _pastilla(Color color, String texto, {bool abierto = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            texto,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onCambiarEstado != null) ...[
            const SizedBox(width: 4),
            AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: abierto ? 0.5 : 0,
              child: const Icon(
                Icons.keyboard_arrow_down,
                size: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = paletaEstadoPedido(estado);
    if (onCambiarEstado == null) return _pastilla(p.color, p.texto);

    // Mismo menú que los selectores de la app; cada estado conserva su color.
    final pendiente = paletaEstadoPedido('pendiente');
    final servido = paletaEstadoPedido('servido');
    final anulado = paletaEstadoPedido('anulado');
    return MenuFlotante<String>(
      tooltip: 'Cambiar estado del pedido',
      seleccionada: estado == 'pedido' ? 'pendiente' : estado,
      onSeleccionar: onCambiarEstado!,
      opciones: [
        OpcionMenu(
          valor: 'pendiente',
          etiqueta: 'Pendiente',
          color: pendiente.color,
        ),
        OpcionMenu(valor: 'servido', etiqueta: 'Servido', color: servido.color),
        OpcionMenu(
          valor: 'anulado',
          etiqueta: 'Anular pedido',
          color: anulado.color,
        ),
      ],
      disparador: (context, abierto) =>
          _pastilla(p.color, p.texto, abierto: abierto),
    );
  }
}

// Sección derecha de Pedidos: detalle del pedido elegido (`pedidos` +
// `pedidos_detalle`) con Imprimir, Devolución, Pagar y Pago compartido.
class DetallePedidoPanel extends StatelessWidget {
  final Pedido pedido;
  final VoidCallback onCambio;
  final VoidCallback? onVolver;
  final bool esAdmin;

  const DetallePedidoPanel({
    super.key,
    required this.pedido,
    required this.onCambio,
    this.onVolver,
    this.esAdmin = false,
  });

  String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _metodoPago() {
    final metodos = <String>{
      for (final pago in pagos.where((x) => x.pedidoId == pedido.id))
        pago.medioPago.medioPago,
    };
    return metodos.isEmpty ? 'Sin pago' : metodos.join(', ');
  }

  String _descripcionLinea(PedidoLine l) {
    final partes = <String>[
      if (l.variante != null) l.variante!.nombre,
      if (l.presentacion != null)
        '${l.presentacion!.unidad.unidadPresentacion} ${l.presentacion!.volumenMl}ml',
      ...l.modificadores.map((m) => m.nombre),
      if (l.promocion != null) l.promocion!.nombre,
    ];
    return partes.join(' · ');
  }

  // ---------- servidor ----------

  // Pedidos manejados por la API del mozo.
  bool get _api =>
      AppConfig.usarApiPedidosMozo &&
      PedidoMozoService.instance.activo &&
      UuidHelper.isValid(pedido.id);

  // Con la API del mozo, solo el mozo que tomó el pedido puede modificarlo.
  bool _puedeModificar(BuildContext context) {
    if (!_api || PedidoMozoService.instance.puedeOperar(pedido)) return true;
    showAppToast(
      context,
      'Solo el mozo que tomó este pedido puede modificarlo.',
      type: ToastType.info,
    );
    return false;
  }

  String _textoError(Object e) => e is ApiException
      ? e.message
      : e.toString().replaceFirst('Exception: ', '');

  // Ejecuta una operación del servidor y refresca la pantalla; los errores se
  // muestran como aviso. Devuelve true si salió bien.
  Future<bool> _ejecutar(
    BuildContext context,
    Future<void> Function() operacion,
  ) async {
    try {
      await operacion();
      // Lo pedido o anulado cambia las porciones que quedan hoy.
      DisponibilidadService.instance.cargarHoy();
      onCambio();
      return true;
    } on PedidoCambioException catch (e) {
      onCambio();
      if (context.mounted) {
        showAppToast(context, e.mensaje, type: ToastType.info);
      }
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, _textoError(e), type: ToastType.error);
      }
    }
    return false;
  }

  // ---------- acciones ----------

  void _imprimir(BuildContext context) {
    marcarPedidoImpreso(pedido.id);
    showBlurDialog<void>(
      context: context,
      builder: (dialogContext) => BoletaPedidoDialog(
        pedido: pedido,
        mesero: nombreMeseroDe(pedido),
        titulo: tituloPedido(pedido),
        metodoPago: _metodoPago(),
        onImprimir: () {
          if (_api && PedidoMozoService.instance.puedeOperar(pedido)) {
            ImpresionService.instance
                .reimprimirPedido(pedido.id)
                .then((_) {
                  if (context.mounted) {
                    showAppToast(
                      context,
                      'Comanda del pedido #${pedido.numeroPedido} reenviada a '
                      'cocina (REIMPRESIÓN).',
                      type: ToastType.success,
                    );
                  }
                })
                .catchError((Object e) {
                  if (context.mounted) {
                    showAppToast(
                      context,
                      'No se pudo imprimir: ${_textoError(e)}',
                      type: ToastType.error,
                    );
                  }
                });
          } else {
            showAppToast(
              dialogContext,
              'Pedido #${pedido.numeroPedido} enviado a imprimir.',
              type: ToastType.success,
            );
          }
          Navigator.of(dialogContext).pop();
        },
        onCerrar: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  Future<void> _devolucion(BuildContext context) async {
    final linea = await showBlurDialog<PedidoLine>(
      context: context,
      builder: (_) => _ElegirLineaDialog(pedido: pedido),
    );
    if (linea == null || !context.mounted) return;
    final resultado = await showBlurDialog<ReporteProblema>(
      context: context,
      builder: (_) => ReportarProblemaDialog(
        nombrePlato: linea.nombrePlato,
        precioLinea: linea.precioTotalLinea,
        pagadoLinea: montoPagadoDeLinea(linea.id),
        medioOriginalId: medioDeUltimoPago(pedido.id),
      ),
    );
    if (resultado == null || !context.mounted) return;
    var reporte = resultado;
    // La foto se sube al servidor y la incidencia guarda su dirección.
    if (resultado.foto != null && PedidoMozoService.instance.activo) {
      try {
        final url = await PedidoMozoService.instance.subirEvidencia(
          resultado.foto!,
          resultado.nombreFoto ?? 'evidencia.jpg',
        );
        reporte = (
          categoria: resultado.categoria,
          detalle: resultado.detalle,
          evidencia: url,
          foto: resultado.foto,
          nombreFoto: resultado.nombreFoto,
          resolucion: resultado.resolucion,
          reemplazoNombre: resultado.reemplazoNombre,
          reemplazoPrecio: resultado.reemplazoPrecio,
          reemplazoCartaId: resultado.reemplazoCartaId,
          medioReembolsoId: resultado.medioReembolsoId,
        );
      } catch (_) {
        if (context.mounted) {
          showAppToast(
            context,
            'No se pudo subir la foto; la devolución se registra sin ella.',
            type: ToastType.info,
          );
        }
      }
    }
    if (!context.mounted) return;
    final efecto = registrarIncidencia(
      pedido: pedido,
      linea: linea,
      reporte: reporte,
    );
    showAppToast(
      context,
      '${linea.nombrePlato}: ${etiquetaDeResolucion(resultado.resolucion)}. ${efecto.resumen}',
      type: resultado.resolucion == 'rechazado'
          ? ToastType.info
          : ToastType.success,
      titulo: 'Devolución',
    );
    onCambio();
  }

  // "Pagar": pago único o compartido. El delivery solo admite pago único. Desde
  // cada forma de pago se puede regresar a esta elección.
  Future<void> _elegirPago(BuildContext context) async {
    if (pedido.tipoPedido == 'delivery') {
      await _pagar(context, compartido: false, permiteVolver: false);
      return;
    }
    while (true) {
      if (!context.mounted) return;
      final compartido = await showBlurDialog<bool>(
        context: context,
        builder: (_) => _ModoPagoDialog(titulo: tituloPedido(pedido)),
      );
      if (compartido == null || !context.mounted) return;
      final volver = await _pagar(context, compartido: compartido);
      if (!volver) return;
    }
  }

  // Devuelve true si el usuario pidió regresar a la elección del tipo de pago.
  Future<bool> _pagar(
    BuildContext context, {
    required bool compartido,
    bool permiteVolver = true,
  }) async {
    if (compartido) {
      final r = await showBlurDialog<Object>(
        context: context,
        builder: (_) => PagoCompartidoDialog(
          pedido: pedido,
          titulo: tituloPedido(pedido),
          permiteVolver: permiteVolver,
        ),
      );
      if (r == null) return false;
      if (identical(r, volverAElegirPago)) return true;
      final resultado = r as ResultadoPagoCompartido;
      // Las boletas se muestran antes de refrescar: si el pedido quedó
      // pagado, este panel deja de existir.
      if (resultado.boletasIndividuales && context.mounted) {
        await showBlurDialog<void>(
          context: context,
          builder: (_) => BoletasPagadoresDialog(
            pedido: pedido,
            boletas: resultado.boletas,
          ),
        );
      }
      onCambio();
      return false;
    }
    final r = await showBlurDialog<Object>(
      context: context,
      builder: (_) => PagarPedidoDialog(
        pedido: pedido,
        titulo: tituloPedido(pedido),
        permiteVolver: permiteVolver,
      ),
    );
    if (identical(r, volverAElegirPago)) return true;
    if (r == true) onCambio();
    return false;
  }

  Future<void> _anularPedidoApi(BuildContext context) async {
    if (!_puedeModificar(context)) return;
    final r = await showBlurDialog<ResultadoAnulacion>(
      context: context,
      builder: (_) => AnulacionDialog(
        titulo: 'Anular pedido #${pedido.numeroPedido}',
        detalle:
            '${tituloPedido(pedido)}. Se liberará la mesa y desaparecerá de '
            'la cola y de cocina.',
      ),
    );
    if (r == null || !context.mounted) return;
    final ok = await _ejecutar(context, () async {
      String? url;
      if (r.foto != null) {
        url = await PedidoMozoService.instance.subirEvidencia(
          r.foto!,
          r.nombreFoto ?? 'evidencia.jpg',
        );
      }
      await PedidoMozoService.instance.anularPedido(
        pedido.id,
        motivo: r.motivo,
        urlEvidencia: url,
      );
    });
    if (ok && context.mounted) {
      showAppToast(
        context,
        'El pedido #${pedido.numeroPedido} se anuló.',
        type: ToastType.info,
        titulo: 'Pedido anulado',
      );
    }
  }

  Future<void> _cancelar(BuildContext context) async {
    if (_api) return _anularPedidoApi(context);
    final confirmar = await showBlurDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertaApp(
        title: Text('Cancelar pedido #${pedido.numeroPedido}'),
        content: Text(
          '¿Seguro que deseas cancelar este pedido de ${tituloPedido(pedido)}? '
          'Se liberarán sus mesas y desaparecerá de la cola y de cocina.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;
    actualizarEstadoPedido(pedido.id, 'anulado');
    for (final n in pedido.todasLasMesas) {
      if (n == 0) continue;
      actualizarEstadoMesa(n, 'disponible');
      separarMesas(n);
    }
    if (UuidHelper.isValid(pedido.id)) {
      PedidoService.instance
          .cambiarEstadoPedido(pedido.id, 'anulado')
          .catchError((_) {});
    }
    onCambio();
    showAppToast(
      context,
      'El pedido #${pedido.numeroPedido} se canceló.',
      type: ToastType.info,
      titulo: 'Pedido cancelado',
    );
  }

  // Un producto con cobros registrados ya no se puede editar ni quitar.
  bool _bloqueadaPorPago(BuildContext context, PedidoLine l) {
    if (montoPagadoDeLinea(l.id).abs() < 0.001) return false;
    showAppToast(
      context,
      'Este producto ya tiene pagos registrados.',
      type: ToastType.error,
    );
    return true;
  }

  Future<void> _quitarLineaApi(BuildContext context, PedidoLine l) async {
    if (!_puedeModificar(context)) return;
    final servicio = PedidoMozoService.instance;
    if (!esLineaDeProducto(l)) {
      // Descuento del servidor.
      await _ejecutar(context, () => servicio.quitarDescuento(pedido.id, l.id));
      return;
    }
    final productos = (detallesPorPedido[pedido.id] ?? []).where(
      esLineaDeProducto,
    );
    if (productos.length <= 1 && l.cantidad <= 1) {
      showAppToast(
        context,
        'El pedido necesita al menos un producto. Para anularlo, anula el pedido.',
        type: ToastType.error,
      );
      return;
    }
    final r = await showBlurDialog<ResultadoAnulacion>(
      context: context,
      builder: (_) => AnulacionDialog(
        titulo: 'Anular "${l.nombrePlato}"',
        detalle: 'Cantidad en el pedido: ${l.cantidad}.',
        maxCantidad: l.cantidad,
      ),
    );
    if (r == null || !context.mounted) return;
    final ok = await _ejecutar(context, () async {
      String? url;
      if (r.foto != null) {
        url = await servicio.subirEvidencia(
          r.foto!,
          r.nombreFoto ?? 'evidencia.jpg',
        );
      }
      await servicio.anularFila(
        pedido.id,
        l,
        cantidad: r.cantidad,
        motivo: r.motivo,
        urlEvidencia: url,
      );
    });
    if (ok && context.mounted) {
      showAppToast(
        context,
        '"${l.nombrePlato}" se anuló del pedido.',
        type: ToastType.info,
      );
    }
  }

  void _quitarLinea(BuildContext context, PedidoLine l) {
    if (_bloqueadaPorPago(context, l)) return;
    final esDescuentoServidor =
        l.cartaId == cartaIdAjuste &&
        l.nombrePlato.startsWith(_prefijoDescuento) &&
        UuidHelper.isValid(l.id);
    if (_api && (esLineaDeProducto(l) || esDescuentoServidor)) {
      _quitarLineaApi(context, l);
      return;
    }
    if (esLineaDeProducto(l)) {
      final productos = (detallesPorPedido[pedido.id] ?? []).where(
        esLineaDeProducto,
      );
      if (productos.length <= 1) {
        showAppToast(
          context,
          'El pedido necesita al menos un producto. Para anularlo, cancélalo.',
          type: ToastType.error,
        );
        return;
      }
    }
    quitarLineaDePedido(pedido.id, l.id);
    onCambio();
    showAppToast(
      context,
      '"${l.nombrePlato}" se quitó del pedido.',
      type: ToastType.info,
    );
  }

  // Porciones que todavía se pueden sumar a esta línea hoy (null = sin tope).
  // Lo que ya está en el pedido ya se descontó de "Abrir el día".
  int? _topeDeLinea(PedidoLine l) => topeDeUnidades(
    l.cartaId,
    presentacionId: l.presentacion?.id,
    varianteId: l.variante?.id,
  );

  void _cambiarCantidad(BuildContext context, PedidoLine l, int delta) {
    if (_bloqueadaPorPago(context, l)) return;
    final tope = _topeDeLinea(l);
    if (delta > 0 && tope != null && delta > tope) {
      showAppToast(
        context,
        tope == 0
            ? '"${l.nombrePlato}" ya no tiene porciones disponibles hoy.'
            : 'Solo quedan $tope de "${l.nombrePlato}".',
        type: ToastType.error,
      );
      return;
    }
    if (_api) {
      if (!_puedeModificar(context)) return;
      final nueva = l.cantidad + delta;
      if (nueva < 1) return;
      _ejecutar(
        context,
        () => PedidoMozoService.instance.cambiarCantidad(pedido.id, l, nueva),
      );
      return;
    }
    cambiarCantidadLineaDePedido(pedido.id, l.id, delta);
    onCambio();
  }

  // Nota general del pedido (aparte de las notas de cada producto): se ve en la
  // comanda y en cocina.
  Future<void> _editarNotaPedido(BuildContext context) async {
    final nota = await showBlurDialog<String>(
      context: context,
      builder: (_) => _NotaDialog(
        titulo: 'Nota del pedido',
        subtitulo:
            'Pedido #${pedido.numeroPedido}. Vale para todo el pedido, no solo '
            'para un producto.',
        inicial: notaGeneralDe(pedido.notas),
        hint: 'Ej. cliente alérgico, llevar todo junto, cumpleaños',
      ),
    );
    if (nota == null) return;
    if (_api) {
      if (!context.mounted || !_puedeModificar(context)) return;
      await _ejecutar(
        context,
        // El nombre del cliente va en el mismo texto: se conserva.
        () => PedidoMozoService.instance.comentarioPedido(
          pedido.id,
          comentariosConNota(pedido.notas, nota),
        ),
      );
      return;
    }
    actualizarNotaPedido(pedido.id, comentariosConNota(pedido.notas, nota));
    onCambio();
  }

  // Bloque de la nota del pedido, arriba de los productos.
  Widget _notaDelPedido(BuildContext context) {
    final nota = notaGeneralDe(pedido.notas) ?? '';
    final editable = !pedido.terminado;
    if (nota.isEmpty && !editable) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: nota.isEmpty ? Colors.white : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: nota.isEmpty ? Colors.grey.shade300 : const Color(0xFFF5D98B),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: editable ? () => _editarNotaPedido(context) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  LucideIcons.notebookPen,
                  size: 16,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nota del pedido',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nota.isEmpty
                          ? 'Sin nota. Toca para agregar una nota general.'
                          : nota,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: nota.isEmpty
                            ? Colors.grey.shade500
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              if (editable)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    nota.isEmpty ? Icons.add : LucideIcons.pencil,
                    size: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editarNota(BuildContext context, PedidoLine l) async {
    final nota = await showBlurDialog<String>(
      context: context,
      builder: (_) => _NotaDialog(
        titulo: 'Nota del producto',
        subtitulo: l.nombrePlato,
        inicial: l.comentario,
      ),
    );
    if (nota == null) return;
    if (_api) {
      if (!context.mounted || !_puedeModificar(context)) return;
      await _ejecutar(
        context,
        () => PedidoMozoService.instance.comentarioFila(
          pedido.id,
          l,
          nota.isEmpty ? null : nota,
        ),
      );
      return;
    }
    actualizarNotaLinea(pedido.id, l.id, nota.isEmpty ? null : nota);
    onCambio();
  }

  // Descuento del pedido por el servidor; si el usuario no tiene permiso para
  // otorgarlo, pide el PIN de un supervisor.
  Future<void> _descuentoApi(
    BuildContext context,
    DescuentoConfigurado r,
    List<PedidoLine> lineas,
  ) async {
    if (!_puedeModificar(context)) return;
    final servicio = PedidoMozoService.instance;
    if (r.quitar) {
      final nombre = '$_prefijoDescuento${r.nombre}';
      final l = lineas
          .where(
            (x) =>
                x.cartaId == cartaIdAjuste &&
                x.nombrePlato == nombre &&
                UuidHelper.isValid(x.id),
          )
          .firstOrNull;
      if (l == null) return;
      await _ejecutar(context, () => servicio.quitarDescuento(pedido.id, l.id));
      return;
    }
    Future<void> aplicar(String? autorizoId) => servicio.aplicarDescuento(
      pedido.id,
      motivo: r.nombre,
      porcentaje: r.esPorcentaje,
      valor: r.monto,
      autorizoId: autorizoId,
    );
    await _ejecutar(context, () async {
      try {
        await aplicar(null);
      } on ApiException catch (e) {
        if (e.statusCode != 403) rethrow;
        if (!context.mounted) return;
        final autorizo = await pedirAutorizacionSupervisor(context);
        if (autorizo == null) return;
        await aplicar(autorizo);
      }
    });
  }

  Future<void> _agregarAjuste(BuildContext context) async {
    if (!_puedeModificar(context)) return;
    final lineas = detallesPorPedido[pedido.id] ?? [];
    final base = lineas
        .where(esLineaDeProducto)
        .fold(0.0, (s, l) => s + l.precioTotalLinea);
    final aplicados = {
      for (final l in lineas)
        if (l.cartaId == cartaIdAjuste &&
            l.nombrePlato.startsWith(_prefijoDescuento))
          l.nombrePlato.substring(_prefijoDescuento.length),
    };
    final r = await showBlurDialog<DescuentoConfigurado>(
      context: context,
      builder: (_) => DescuentoDialog(base: base, aplicados: aplicados),
    );
    if (r == null || !context.mounted) return;
    if (_api) return _descuentoApi(context, r, lineas);
    final nombre = '$_prefijoDescuento${r.nombre}';
    if (r.quitar) {
      lineas.removeWhere(
        (l) => l.cartaId == cartaIdAjuste && l.nombrePlato == nombre,
      );
      onCambio();
      return;
    }
    final monto = r.esPorcentaje ? base * r.monto / 100 : r.monto;
    if (monto > saldoPendienteDePedido(pedido.id) + 0.01) {
      showAppToast(
        context,
        'El descuento no puede superar el saldo del pedido.',
        type: ToastType.error,
      );
      return;
    }
    agregarAjusteAPedido(pedido.id, nombre, monto);
    onCambio();
  }

  Future<void> _agregarProducto(BuildContext context) async {
    if (!_puedeModificar(context)) return;
    final agregado = await showBlurDialog<bool>(
      context: context,
      builder: (_) => AgregarProductoDialog(pedido: pedido, esAdmin: esAdmin),
    );
    if (agregado != true) return;
    onCambio();
    if (context.mounted) {
      showAppToast(
        context,
        'Producto agregado al pedido #${pedido.numeroPedido}.',
        type: ToastType.success,
      );
    }
  }

  // Propina para el mesero: se agrega al card de totales y se puede editar.
  Future<void> _editarPropina(BuildContext context) async {
    final lineas = detallesPorPedido[pedido.id] ?? [];
    if (lineas
        .where(esLineaPropina)
        .any((l) => montoPagadoDeLinea(l.id).abs() > 0.001)) {
      showAppToast(
        context,
        'La propina ya tiene pagos registrados.',
        type: ToastType.error,
      );
      return;
    }
    final base = lineas
        .where(esLineaDeProducto)
        .fold(0.0, (s, l) => s + l.precioTotalLinea);
    final monto = await showBlurDialog<double>(
      context: context,
      builder: (_) =>
          PropinaDialog(base: base, actual: propinaDePedido(pedido.id)),
    );
    if (monto == null) return;
    establecerPropinaPedido(pedido.id, monto);
    onCambio();
  }

  // Tupper para llevar: grande o mediano, con precio editable.
  Future<void> _editarTupper(BuildContext context) async {
    final lineas = detallesPorPedido[pedido.id] ?? [];
    if (lineas
        .where(esLineaTupper)
        .any((l) => montoPagadoDeLinea(l.id).abs() > 0.001)) {
      showAppToast(
        context,
        'El tupper ya tiene pagos registrados.',
        type: ToastType.error,
      );
      return;
    }
    final actual = tupperCantidades(pedido.id);
    final r = await showBlurDialog<TupperConfigurado>(
      context: context,
      builder: (_) =>
          TupperDialog(grande: actual.grande, mediano: actual.mediano),
    );
    if (r == null) return;
    establecerTupperPedido(
      pedido.id,
      grande: r.grande,
      precioGrande: r.precioGrande,
      mediano: r.mediano,
      precioMediano: r.precioMediano,
    );
    onCambio();
  }

  // Tag naranja: agrega al pedido el plato del día registrado en Productos.
  // Agrega una promoción tal como la configuró el admin al pedido.
  Future<void> _agregarPromocion(BuildContext context) async {
    if (!_puedeModificar(context)) return;
    final r = await elegirPromocion(context);
    if (r == null || !context.mounted) return;
    final linea = lineaDePromocion(r);
    if (_api) {
      final ok = await _ejecutar(
        context,
        () => PedidoMozoService.instance.agregarProducto(pedido.id, linea),
      );
      if (!ok) return;
    } else {
      agregarLineaAPedido(pedido.id, linea);
      registrarConsumoAutomaticoDeLinea(linea);
      onCambio();
    }
    if (context.mounted) {
      showAppToast(
        context,
        '"${r.promocion.nombre}" se agregó al pedido #${pedido.numeroPedido}.',
        type: ToastType.success,
        titulo: 'Promoción',
      );
    }
  }

  // El cliente pide cambiar un producto de la promoción: solo entre las
  // opciones que registró el admin.
  Future<void> _cambiarProductosPromocion(
    BuildContext context,
    PedidoLine l,
  ) async {
    final promo = l.promocion;
    if (promo == null || _bloqueadaPorPago(context, l)) return;
    if (_api) {
      // El servidor no permite cambiar los productos de una promoción ya
      // pedida: se anula y se vuelve a agregar.
      showAppToast(
        context,
        'Para cambiar los productos de una promoción, anula esa línea y '
        'agrégala de nuevo.',
        type: ToastType.info,
      );
      return;
    }
    final r = await showBlurDialog<PromocionConfigurada>(
      context: context,
      builder: (_) => PromocionOpcionesDialog(
        promocion: promo,
        inicial: l.componentes,
        edicion: true,
      ),
    );
    if (r == null) return;
    final nueva = l.conComponentes(r.componentes, r.precioUnitario);
    reajustarConsumoDePromocion(l, nueva);
    reemplazarLineaDePedido(pedido.id, nueva);
    onCambio();
  }

  Future<void> _cambiarEntrega(BuildContext context) async {
    if (!_puedeModificar(context)) return;
    final c = await showBlurDialog<CambioEntrega>(
      context: context,
      builder: (_) => CambiarEntregaDialog(pedido: pedido),
    );
    if (c == null || !context.mounted) return;
    final s = PedidoMozoService.instance;
    final eraMesa = pedido.tipoPedido == 'mesa' && pedido.mesaNumero > 0;
    final ok = await _ejecutar(context, () {
      if (c.tipo == 'mesa' && eraMesa) {
        return s.cambiarMesa(pedido.id, c.mesaId!);
      }
      return s.tipoEntregaPedido(
        pedido.id,
        c.tipo,
        nuevaMesaId: c.mesaId,
        aplicaTaper: c.aplicaTaper,
        delivery: c.delivery,
      );
    });
    if (ok && context.mounted) {
      showAppToast(
        context,
        'El pedido #${pedido.numeroPedido} se actualizó.',
        type: ToastType.success,
      );
    }
  }

  // 'mesa', 'llevar' o 'llevar_taper' (para llevar cobrando táper).
  Future<void> _cambiarEntregaFila(
    BuildContext context,
    PedidoLine l,
    String opcion,
  ) async {
    if (!_puedeModificar(context)) return;
    await _ejecutar(
      context,
      () => PedidoMozoService.instance.tipoEntregaFila(
        pedido.id,
        l,
        opcion == 'mesa' ? 'mesa' : 'llevar',
        aplicaTaper: opcion == 'llevar_taper',
      ),
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final detalles = detallesPorPedido[pedido.id] ?? [];
    final productos = detalles.where(esLineaDeProducto).toList();
    final subtotal = productos.fold(
      0.0,
      (s, l) => s + l.precioTotalLinea + l.descuentoAplicado,
    );
    final descProductos = productos.fold(
      0.0,
      (s, l) => s + l.descuentoAplicado,
    );
    double sumaAjustes(String prefijo) => -detalles
        .where(
          (l) =>
              l.cartaId == cartaIdAjuste && l.nombrePlato.startsWith(prefijo),
        )
        .fold(0.0, (s, l) => s + l.precioTotalLinea);
    final descExtra = sumaAjustes(_prefijoDescuento);
    final tupper = tupperDePedido(pedido.id);
    final propina = propinaDePedido(pedido.id);
    final devoluciones = detalles
        .where(esAjusteDeDevolucion)
        .fold(0.0, (s, l) => s + l.precioTotalLinea);
    final cargo = detalles
        .where((l) => l.cartaId == cartaIdCargoDelivery)
        .fold(0.0, (s, l) => s + l.precioTotalLinea);
    final total = totalDePedido(pedido.id);
    final saldo = saldoPendienteDePedido(pedido.id);
    final pagado = total - saldo;
    final puedePagar = saldo > 0.01;

    // En pantallas bajas (mobile) los totales y botones van dentro del scroll,
    // para que los productos no queden aplastados.
    final pieEnLista = MediaQuery.sizeOf(context).height < 760;
    final pieTotales = Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          _filaTotal('Subtotal', subtotal),
          if (cargo > 0) _filaTotal('Cargo por delivery', cargo),
          if (descProductos > 0)
            _filaTotal('Descuento de productos', -descProductos),
          _filaTotal(
            'Descuento extra',
            -descExtra,
            onEditar: () => _agregarAjuste(context),
          ),
          if (devoluciones.abs() > 0.001)
            _filaTotal('Ajustes por devolución', devoluciones),
          if (propina > 0)
            _filaTotal(
              'Propina',
              propina,
              onEditar: () => _editarPropina(context),
            ),
          if (tupper > 0)
            _filaTotal(
              'Tupper',
              tupper,
              onEditar: () => _editarTupper(context),
            ),
          if (pagado > 0.01) _filaTotal('Pagado', pagado),
          if (pagado > 0.01 && saldo > 0.01)
            _filaTotal('Saldo pendiente', saldo, color: AppColors.mesaOcupada),
          const SizedBox(height: 4),
          _filaTotal('Total', total, fuerte: true),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              runSpacing: 8,
              children: [
                AppTag(
                  etiqueta: 'Promoción',
                  icono: LucideIcons.tag,
                  activo: false,
                  color: AppColors.platoDelDia,
                  onTap: () => _agregarPromocion(context),
                ),
                AppTag(
                  etiqueta: 'Propina',
                  icono: LucideIcons.handCoins,
                  activo: false,
                  color: AppColors.platoDelDia,
                  onTap: () => _editarPropina(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final pieBotones = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: _botones(context, productos.isNotEmpty, puedePagar),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cabecera(context),
          Divider(height: 1, color: Colors.grey.shade200),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              children: [
                _notaDelPedido(context),
                if (detalles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Este pedido aún no tiene ítems.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  )
                else
                  for (final l in detalles) _filaLinea(context, l),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _agregarProducto(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Agregar producto'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGreenDark,
                        side: const BorderSide(color: AppColors.primaryGreen),
                      ),
                    ),
                  ),
                ),
                if (pieEnLista) ...[
                  Divider(height: 24, color: Colors.grey.shade200),
                  pieTotales,
                  pieBotones,
                ],
              ],
            ),
          ),
          if (!pieEnLista) ...[
            Divider(height: 1, color: Colors.grey.shade200),
            pieTotales,
            pieBotones,
          ],
        ],
      ),
    );
  }

  Widget _cabecera(BuildContext context) {
    final cliente = pedido.clienteNombre;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onVolver != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onVolver,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Icon(Icons.arrow_back, size: 17),
                ),
              ),
            ),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              LucideIcons.receipt,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Pedido #${pedido.numeroPedido}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (esPedidoDeEmpleado(pedido)) ...[
                      const SizedBox(width: 6),
                      const TagEmpleado(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${tituloPedido(pedido)} · ${_hora(pedido.fechaPedido)} · ${nombreMeseroDe(pedido)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (cliente != null)
                  Text(
                    cliente,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          BadgeEstadoPedido(
            pedido.estado,
            onCambiarEstado: (nuevo) async {
              if (!_puedeModificar(context)) return;
              if (_api && nuevo == 'anulado') {
                await _cancelar(context);
                return;
              }
              await _ejecutar(
                context,
                () => PedidoService.instance.cambiarEstadoPedido(
                  pedido.id,
                  nuevo,
                ),
              );
            },
          ),
          if (_api) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Cambiar mesa o entrega',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _cambiarEntrega(context),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade100,
                  ),
                  child: Icon(
                    LucideIcons.arrowLeftRight,
                    size: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          _botonCirculoRojo(
            tooltip: 'Cancelar pedido',
            onTap: () => _cancelar(context),
          ),
        ],
      ),
    );
  }

  Widget _botonCirculoRojo({
    required String tooltip,
    required VoidCallback onTap,
    double size = 26,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.error.withValues(alpha: 0.1),
          ),
          child: Icon(
            LucideIcons.trash2,
            size: size * 0.5,
            color: AppColors.error,
          ),
        ),
      ),
    );
  }

  // Línea del pedido: checklist al extremo izquierdo, datos y acciones.
  Widget _filaLinea(BuildContext context, PedidoLine l) {
    final esProducto = esLineaDeProducto(l);
    final esCargo = l.cartaId == cartaIdCargoDelivery;
    final desc = _descripcionLinea(l);
    final pagadoLinea = montoPagadoDeLinea(l.id);
    final incidencia = l.estado == 'incidencia'
        ? incidenciaDeLinea(l.id)
        : null;
    final entregado = esProducto && lineasEntregadas.contains(l.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (esProducto)
            Tooltip(
              message: entregado
                  ? 'Marcar como pendiente de entrega'
                  : 'Marcar como entregado',
              child: SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: entregado,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  onChanged: (_) {
                    if (_api) {
                      if (!_puedeModificar(context)) return;
                      _ejecutar(
                        context,
                        () => PedidoMozoService.instance.marcarServido(
                          pedido.id,
                          l,
                          !entregado,
                        ),
                      );
                      return;
                    }
                    alternarLineaEntregada(l.id);
                    onCambio();
                  },
                  activeColor: AppColors.primaryGreen,
                ),
              ),
            )
          else
            const SizedBox(width: 4),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        l.nombrePlato,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: entregado
                              ? TextDecoration.lineThrough
                              : null,
                          color: entregado
                              ? Colors.grey.shade500
                              : Colors.black87,
                        ),
                      ),
                    ),
                    if (!esCargo && !esAjusteDeDevolucion(l))
                      _botonCirculoRojo(
                        tooltip: esProducto
                            ? 'Quitar producto'
                            : (esLineaPropina(l)
                                  ? 'Quitar propina'
                                  : esLineaTupper(l)
                                  ? 'Quitar tupper'
                                  : 'Quitar descuento'),
                        onTap: () => _quitarLinea(context, l),
                      ),
                  ],
                ),
                if (desc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                if (l.promocion != null) ...[
                  for (final e in l.componentes)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        textoDeComponente(e),
                        style: TextStyle(
                          fontSize: 11,
                          color: e.esCambio
                              ? AppColors.platoDelDia
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  if (l.componentes.any(
                    (e) =>
                        opcionesDe(e.componenteId, soloActivas: true).length >
                        1,
                  ))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () => _cambiarProductosPromocion(context, l),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'Cambiar productos',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.platoDelDia,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                if (l.comentario != null && esProducto)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l.comentario!,
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                if (esProducto)
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreenDark,
                      ),
                      children: [
                        TextSpan(
                          text:
                              'S/ ${l.precioUnitario.toStringAsFixed(2)} × ${l.cantidad} = ',
                        ),
                        TextSpan(
                          text: 'S/ ${l.precioTotalLinea.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  )
                else if (esLineaTupper(l))
                  Text(
                    'S/ ${l.precioUnitario.toStringAsFixed(2)} × ${l.cantidad} = S/ ${l.precioTotalLinea.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryGreenDark,
                    ),
                  )
                else
                  Text(
                    '${l.precioTotalLinea < 0 ? '-' : ''}S/ ${l.precioTotalLinea.abs().toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryGreenDark,
                    ),
                  ),
                if (pagadoLinea > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Pagado S/ ${pagadoLinea.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                if (incidencia != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _tagIncidencia(incidencia),
                  ),
                if (esProducto)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        _stepper(context, l),
                        const Spacer(),
                        if (_api && !esLineaTaper(l)) ...[
                          _botonEntregaFila(context, l),
                          const SizedBox(width: 6),
                        ],
                        _botonNota(context, l),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // − n + : cambia la cantidad de la línea.
  Widget _stepper(BuildContext context, PedidoLine l) {
    Widget boton(IconData icono, VoidCallback? onTap) => InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap == null
              ? Colors.grey.shade100
              : AppColors.primaryGreen.withValues(alpha: 0.12),
        ),
        child: Icon(
          icono,
          size: 14,
          color: onTap == null
              ? Colors.grey.shade400
              : AppColors.primaryGreenDark,
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        boton(
          Icons.remove,
          l.cantidad > 1 ? () => _cambiarCantidad(context, l, -1) : null,
        ),
        SizedBox(
          width: 28,
          child: Text(
            '${l.cantidad}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
        boton(
          Icons.add,
          (_topeDeLinea(l) ?? 1) > 0
              ? () => _cambiarCantidad(context, l, 1)
              : null,
        ),
      ],
    );
  }

  // Entrega del producto: en mesa o para llevar (con o sin cobro de táper).
  Widget _botonEntregaFila(BuildContext context, PedidoLine l) {
    final llevar = l.tipoEntrega == 'llevar' || l.tipoEntrega == 'delivery';
    return MenuFlotante<String>(
      tooltip: llevar ? 'Para llevar' : 'En mesa',
      seleccionada: !llevar
          ? 'mesa'
          : (l.aplicaTaper ? 'llevar_taper' : 'llevar'),
      opciones: const [
        OpcionMenu(valor: 'mesa', etiqueta: 'En mesa'),
        OpcionMenu(valor: 'llevar', etiqueta: 'Para llevar'),
        OpcionMenu(
          valor: 'llevar_taper',
          etiqueta: 'Para llevar (cobrar táper)',
        ),
      ],
      anchoMinimo: 220,
      onSeleccionar: (v) => _cambiarEntregaFila(context, l, v),
      disparador: (context, abierto) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          llevar ? LucideIcons.package : LucideIcons.utensils,
          size: 13,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _botonNota(BuildContext context, PedidoLine l) {
    final tieneNota = l.comentario != null;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _editarNota(context, l),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.notebookPen,
              size: 12,
              color: Colors.grey.shade700,
            ),
            const SizedBox(width: 5),
            Text(
              tieneNota ? 'Editar nota' : 'Agregar nota',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagIncidencia(Incidencia i) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE4EC),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Devolución: ${i.etiquetaResolucion}',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFFC2185B),
        ),
      ),
    );
  }

  // Fila de totales; con [onEditar] muestra el lápiz para editar el monto.
  Widget _filaTotal(
    String etiqueta,
    double monto, {
    bool fuerte = false,
    Color? color,
    VoidCallback? onEditar,
  }) {
    final estilo = TextStyle(
      fontSize: fuerte ? 16 : 13,
      fontWeight: fuerte ? FontWeight.w800 : FontWeight.w500,
      color: color ?? (fuerte ? Colors.black87 : Colors.grey.shade700),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: estilo)),
          if (onEditar != null)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onEditar,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  LucideIcons.pencil,
                  size: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          const SizedBox(width: 6),
          Text(
            '${monto < -0.004 ? '-' : ''}S/ ${monto.abs().toStringAsFixed(2)}',
            style: estilo,
          ),
        ],
      ),
    );
  }

  // Imprimir (oscuro) + Devolución, y debajo Pagar (naranja) + Pago compartido (verde).
  Widget _botones(BuildContext context, bool hayProductos, bool puedePagar) {
    const texto = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                onPressed: () => _imprimir(context),
                icon: const Icon(LucideIcons.printer, size: 16),
                label: const Text('Imprimir', style: texto),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navbar,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: hayProductos && pedido.tipoPedido != 'delivery'
                    ? () => _devolucion(context)
                    : null,
                icon: const Icon(LucideIcons.undo2, size: 15),
                label: const Text(
                  'Devolución',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: texto,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Servido y Pagar en la misma fila. "Pagar" abre la elección entre pago
        // único y compartido.
        Row(
          children: [
            // Siempre visible: queda desactivado cuando el pedido ya no está
            // pendiente (ya se sirvió o se cerró).
            Expanded(
              child: FilledButton.icon(
                onPressed:
                    (pedido.estado == 'pendiente' || pedido.estado == 'pedido')
                    ? () {
                        if (!_puedeModificar(context)) return;
                        _ejecutar(
                          context,
                          () => PedidoService.instance.cambiarEstadoPedido(
                            pedido.id,
                            'servido',
                          ),
                        );
                      }
                    : null,
                icon: const Icon(LucideIcons.utensilsCrossed, size: 16),
                label: const Text('Servido', style: texto),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: puedePagar ? () => _elegirPago(context) : null,
                icon: const Icon(LucideIcons.banknote, size: 16),
                label: const Text('Pagar', style: texto),
                style: FilledButton.styleFrom(backgroundColor: _naranjaPago),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Cómo se va a pagar: devuelve false (pago único) o true (pago compartido).
class _ModoPagoDialog extends StatelessWidget {
  final String titulo;

  const _ModoPagoDialog({required this.titulo});

  Widget _opcion(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    required String detalle,
    required bool compartido,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).pop(compartido),
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, size: 20, color: AppColors.primaryGreenDark),
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
                    detalle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DialogoApp(
      titulo: 'Pagar · $titulo',
      ancho: 420,
      children: [
        _opcion(
          context,
          icono: LucideIcons.banknote,
          titulo: 'Pago único',
          detalle: 'Una sola persona paga todo el pedido.',
          compartido: false,
        ),
        _opcion(
          context,
          icono: LucideIcons.users,
          titulo: 'Pago compartido',
          detalle: 'Se divide entre varios: por partes iguales, por platos…',
          compartido: true,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// Nota de un producto o del pedido completo; devuelve el texto ('' = quitar la
// nota).
class _NotaDialog extends StatefulWidget {
  final String titulo;
  final String? subtitulo;
  final String? inicial;
  final String hint;

  const _NotaDialog({
    required this.titulo,
    this.subtitulo,
    this.inicial,
    this.hint = 'Ej. sin cebolla, poco picante',
  });

  @override
  State<_NotaDialog> createState() => _NotaDialogState();
}

class _NotaDialogState extends State<_NotaDialog> {
  late final _controller = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tiene = (widget.inicial ?? '').isNotEmpty;
    return DialogoApp(
      titulo: widget.titulo,
      ancho: 420,
      acciones: [
        if (tiene)
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Quitar nota'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
          ),
          child: const Text('Guardar nota'),
        ),
      ],
      children: [
        if (widget.subtitulo != null) ...[
          Text(
            widget.subtitulo!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
        ],
        CampoTexto(
          controller: _controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: widget.hint),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// Elige qué producto del pedido se devuelve (los ya devueltos quedan marcados).
class _ElegirLineaDialog extends StatelessWidget {
  final Pedido pedido;

  const _ElegirLineaDialog({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final ancho = MediaQuery.sizeOf(context).width;
    final lineas = (detallesPorPedido[pedido.id] ?? [])
        .where(esLineaDeProducto)
        .toList();
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: esMobile ? ancho : 400,
          maxWidth: esMobile ? ancho : 400,
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, esMobile ? 28 : 22, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '¿Qué producto se devuelve?',
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
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final l in lineas)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: l.estado == 'incidencia'
                              ? null
                              : () => Navigator.of(context).pop(l),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${l.cantidad}x',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryGreenDark,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l.nombrePlato,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: l.estado == 'incidencia'
                                          ? Colors.grey.shade400
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (l.estado == 'incidencia')
                                  Text(
                                    'Ya devuelto',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
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

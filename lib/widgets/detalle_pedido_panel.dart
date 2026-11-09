import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../config/app_config.dart';
import '../data/disponibilidad_store.dart';
import '../data/incidencias_store.dart';
import '../data/insumos_store.dart';
import '../data/mesas_store.dart';
import '../data/pagos_store.dart';
import '../data/cargos_extra_store.dart';
import '../data/cartas_store.dart';
import '../services/pago_service.dart';
import '../data/pedidos_store.dart';
import '../data/promociones_destacadas_store.dart';
import '../data/promociones_store.dart';
import '../models/incidencia.dart';
import '../models/pedido.dart';
import '../models/taper.dart';
import '../models/pedido_line.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/disponibilidad_service.dart';
import '../services/impresion_service.dart';
import '../services/auth_service.dart';
import '../data/configuracion_store.dart';
import '../services/catalog_service.dart';
import '../services/devolucion_service.dart';
import '../services/pedido_mozo_service.dart';

import '../services/pedido_service.dart';
import '../utils/blur_dialog.dart';
import '../utils/motivo_precio.dart';
import '../utils/nota_pedido.dart';
import '../utils/uuid_helper.dart';
import 'anulacion_dialog.dart';
import 'app_toast.dart';
import 'cambiar_entrega_dialog.dart';
import 'traspaso_dialogs.dart';
import '../data/traspasos_store.dart';
import '../services/traspaso_service.dart';
import 'pin_supervisor_dialog.dart';
import 'boleta_pedido_dialog.dart';
import 'comprobante_en_cobro.dart' show ComprobanteEmitidoDialog;
import '../services/facturacion_service.dart';
import 'boton_imprimir_whatsapp.dart';
import 'agregar_producto_dialog.dart';
import 'producto_opciones_dialog.dart';
import 'descuento_dialog.dart';
import 'menu_flotante.dart';
import 'indicador_abajo.dart';
import 'pago_dialogs.dart';
import 'promocion_pedido_dialogs.dart';
import 'propina_dialog.dart';
import 'reportar_problema_dialog.dart';
import 'taper_catalogo_dialog.dart';
import 'tupper_dialog.dart';
import 'dialogo_app.dart';
import 'campo_texto.dart';
import 'whatsapp_cuenta_dialog.dart';

const _naranjaPago = Color(0xFFF07F13);
const _prefijoDescuento = 'Descuento: ';

String tituloPedido(Pedido p) => p.ubicacion;

// Abre el ticket del pedido (comanda de cocina y cuenta) y reimprime lo que se
// pida, las veces que haga falta. Lo usan la comanda del cajero y el Historial.
void mostrarTicketDelPedido(BuildContext context, Pedido p) {
  String metodos() {
    final m = mediosDePagoDe(p.id);
    return m.isEmpty ? 'Sin pago' : m.join(', ');
  }

  String texto(Object e) => e is ApiException
      ? e.message
      : e.toString().replaceFirst('Exception: ', '');

  void imprimir(
    BuildContext dialogContext, {
    required String tipo,
    required String exito,
    required String fallo,
  }) {
    ImpresionService.instance
        .reimprimirPedido(p.id, tipo: tipo)
        .then((_) {
          if (context.mounted) {
            showAppToast(context, exito, type: ToastType.success);
          }
        })
        .catchError((Object e) {
          if (context.mounted) {
            showAppToast(context, '$fallo: ${texto(e)}', type: ToastType.error);
          }
        });
    Navigator.of(dialogContext).pop();
  }

  marcarPedidoImpreso(p.id);
  showBlurDialog<void>(
    context: context,
    builder: (dialogContext) => BoletaPedidoDialog(
      pedido: p,
      mesero: nombreMeseroDe(p),
      titulo: tituloPedido(p),
      metodoPago: metodos(),
      onImprimir: () => imprimir(
        dialogContext,
        tipo: 'cocina',
        exito:
            'Comanda del pedido #${p.numeroPedido} reenviada a cocina '
            '(REIMPRESIÓN).',
        fallo: 'No se pudo imprimir',
      ),
      onImprimirCuenta: () => imprimir(
        dialogContext,
        tipo: 'cuenta',
        exito:
            'Cuenta del pedido #${p.numeroPedido} enviada a la impresora de '
            'caja.',
        fallo: 'No se pudo imprimir la cuenta',
      ),
      onCerrar: () => Navigator.of(dialogContext).pop(),
    ),
  );
}

String nombreMeseroDe(Pedido p) {
  final nombre = p.mozoNombre;
  if (nombre != null && nombre.isNotEmpty) return nombre;
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

// Nombre del cliente del pedido o, en uno de empleado, el del empleado.
String? nombreClienteDe(Pedido p) {
  final n = (p.clienteNombre ?? '').trim();
  return n.isNotEmpty ? n : nombreEnComentarios(p.notas);
}

// Etiqueta que identifica un pedido para el personal (empleado).
class TagEmpleado extends StatelessWidget {
  // Nombre del empleado: la etiqueta dice "Empleado: Nombre".
  final String? nombre;

  const TagEmpleado({super.key, this.nombre});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF2563EB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.users, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            (nombre ?? '').isEmpty ? 'Empleado' : 'Empleado: $nombre',
            style: const TextStyle(
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

// Etiqueta de una cuenta de familia (cuenta cero): como la del empleado pero
// en ámbar.
class TagFamilia extends StatelessWidget {
  final String? nombre;

  const TagFamilia({super.key, this.nombre});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFB45309);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.house, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            (nombre ?? '').isEmpty ? 'Familia' : 'Familia: $nombre',
            style: const TextStyle(
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
  // En bloque: más alto y de esquinas poco redondas, para ir sobre los
  // botones de la cabecera del detalle.
  final bool bloque;

  const BadgeEstadoPedido(
    this.estado, {
    super.key,
    this.onCambiarEstado,
    this.bloque = false,
  });

  Widget _pastilla(Color color, String texto, {bool abierto = false}) {
    return Container(
      padding: bloque
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 9)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(bloque ? 8 : 100),
      ),
      child: Row(
        // En bloque la flecha va pegada al extremo derecho.
        mainAxisSize: bloque ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (bloque)
            Expanded(
              child: Text(
                texto,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
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

  // Abre directo la elección de pago (único o compartido), sin mostrar todo el
  // detalle del pedido: la usa el cajero desde su comanda.
  Future<void> iniciarCobro(BuildContext context) => _elegirPago(context);

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
    // Un mozo nunca modifica el pedido de otro mozo, ni siquiera sin servidor.
    final u = AuthService.instance.currentUser;
    final ajeno =
        u != null &&
        u.esMozo &&
        pedido.usuarioId != null &&
        pedido.usuarioId != u.id;
    if (!ajeno && (!_api || PedidoMozoService.instance.puedeOperar(pedido))) {
      return true;
    }
    showAppToast(
      context,
      'Este pedido es de ${nombreMeseroDe(pedido)}: solo ese mozo puede '
      'modificarlo.',
      type: ToastType.info,
    );
    return false;
  }

  String _textoError(Object e) => e is ApiException
      ? e.message
      : e.toString().replaceFirst('Exception: ', '');

  // Ejecuta una operación del servidor y refresca la pantalla; los errores se
  // muestran como aviso. Devuelve true si salió bien; con [exito] además
  // avisa que se guardó.
  Future<bool> _ejecutar(
    BuildContext context,
    Future<void> Function() operacion, {
    String? exito,
  }) async {
    try {
      await operacion();
      // Lo pedido o anulado cambia las porciones que quedan hoy.
      DisponibilidadService.instance.cargarHoy();
      onCambio();
      if (exito != null && context.mounted) {
        showAppToast(
          context,
          exito,
          type: ToastType.success,
          duration: const Duration(milliseconds: 2200),
        );
      }
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

  // Manda la cuenta del pedido al cliente por WhatsApp.
  void _enviarWhatsapp(BuildContext context) {
    final total = totalDePedido(pedido.id);
    final pagado = total - saldoPendienteDePedido(pedido.id);
    final metodo = _metodoPago();
    enviarCuentaPorWhatsapp(
      context,
      pedido: pedido,
      lineas: detallesPorPedido[pedido.id] ?? const [],
      metodoPago: metodo == 'Sin pago' ? '' : metodo,
      pagado: pagado > 0.001 ? pagado : 0,
      recargo: recargoCobradoDePedido(pedido.id),
    );
  }

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
        // Caja y administración reimprimen la cuenta las veces que quieran, esté
        // o no pagado; el mozo solo la de sus pedidos.
        onImprimirCuenta: () {
          ImpresionService.instance
              .reimprimirPedido(pedido.id, tipo: 'cuenta')
              .then((_) {
                if (context.mounted) {
                  showAppToast(
                    context,
                    'Cuenta del pedido #${pedido.numeroPedido} enviada a '
                    'la impresora de caja.',
                    type: ToastType.success,
                  );
                }
              })
              .catchError((Object e) {
                if (context.mounted) {
                  showAppToast(
                    context,
                    'No se pudo imprimir la cuenta: ${_textoError(e)}',
                    type: ToastType.error,
                  );
                }
              });
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
    // Con el servidor, la devolución se hace allá (da de baja la línea, devuelve
    // el dinero o emite el vale); la app solo guarda el registro. Sin servidor
    // se aplica en memoria, como antes.
    var enServidor = false;
    String? resumenServidor;
    if (reporte.resolucion != 'rechazado' &&
        DevolucionService.instance.puedeEnServidor(pedido, linea)) {
      try {
        resumenServidor = await DevolucionService.instance.devolver(
          pedido: pedido,
          linea: linea,
          reporte: reporte,
        );
        enServidor = true;
      } catch (e) {
        if (context.mounted) {
          showAppToast(
            context,
            'No se pudo registrar la devolución: ${_textoError(e)}',
            type: ToastType.error,
            titulo: 'Devolución no registrada',
          );
        }
        return;
      }
    }
    if (!context.mounted) return;
    final ({Incidencia incidencia, String resumen}) efecto;
    try {
      efecto = registrarIncidencia(
        pedido: pedido,
        linea: linea,
        reporte: reporte,
        aplicarEfecto: !enServidor,
      );
    } on StateError catch (e) {
      showAppToast(
        context,
        e.message,
        type: ToastType.error,
        titulo: 'Devolución no registrada',
      );
      return;
    }
    showAppToast(
      context,
      '${linea.nombrePlato}: ${etiquetaDeResolucion(resultado.resolucion)}. ${resumenServidor ?? efecto.resumen}',
      type: resultado.resolucion == 'rechazado'
          ? ToastType.info
          : ToastType.success,
      titulo: 'Devolución',
    );
    onCambio();
  }

  // "Pagar": abre el modal de pago (pago único; con "Por montos" se reparte entre
  // varios medios).
  Future<void> _elegirPago(BuildContext context) async {
    // Se lee lo ya cobrado en el servidor: así no se cobra dos veces algo que
    // otro equipo ya cobró. Sin conexión se sigue con lo que hay en pantalla.
    try {
      await PagoService.instance.cargarDePedido(pedido);
    } catch (_) {}
    if (!context.mounted) return;
    // Si el servidor ya tiene la cuenta cobrada, no se abre un cobro en cero:
    // se avisa con lo que ya está registrado y se actualiza el estado (el
    // pedido pasa a Pagados).
    final cobrado = abonadoDePedido(pedido.id);
    final yaPagado =
        pedidos.where((x) => x.id == pedido.id).firstOrNull?.estado == 'pagado';
    if (yaPagado ||
        (saldoCuentaDePedido(pedido.id) <= 0.01 && cobrado > 0.01)) {
      final detalle = abonosDePedido(pedido.id)
          .map(
            (a) =>
                '${a.medio} S/ ${a.monto.toStringAsFixed(2)} '
                '(${a.fecha.day.toString().padLeft(2, '0')}/'
                '${a.fecha.month.toString().padLeft(2, '0')} '
                '${a.fecha.hour.toString().padLeft(2, '0')}:'
                '${a.fecha.minute.toString().padLeft(2, '0')})',
          )
          .join(' · ');
      showAppToast(
        context,
        detalle.isEmpty
            ? 'El servidor ya tiene este pedido como pagado.'
            : 'Este pedido ya tiene su cuenta cobrada: $detalle.',
        type: ToastType.info,
        titulo: 'Pedido ya pagado',
        duration: const Duration(seconds: 6),
      );
      onCambio();
      return;
    }
    await _pagar(context);
  }

  // Los métodos de pago vienen del servidor: sin ninguno no se puede cobrar.
  Future<bool> _hayMediosPago(BuildContext context) async {
    if (mediosPagoActivos.isEmpty) {
      try {
        await CatalogService.instance.cargarMediosPago();
      } catch (_) {}
    }
    if (mediosPagoActivos.isNotEmpty) return true;
    if (context.mounted) {
      showAppToast(
        context,
        'No hay métodos de pago activos en el servidor. Pide al administrador '
        'que los configure en Configuración.',
        type: ToastType.error,
        titulo: 'Sin métodos de pago',
      );
    }
    return false;
  }

  Future<void> _pagar(BuildContext context) async {
    if (!await _hayMediosPago(context)) return;
    if (!context.mounted) return;
    final r = await showBlurDialog<Object>(
      context: context,
      builder: (_) =>
          PagarPedidoDialog(pedido: pedido, titulo: tituloPedido(pedido)),
    );
    if (r == true) onCambio();
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
        fueServido: r.fueServido,
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
      await _ejecutar(
        context,
        () => servicio.quitarDescuento(pedido.id, l.id),
        exito: 'Descuento quitado.',
      );
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
        fueServido: r.fueServido,
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
        exito: 'Cantidad de "${l.nombrePlato}": $nueva.',
      );
      return;
    }
    cambiarCantidadLineaDePedido(pedido.id, l.id, delta);
    onCambio();
  }

  // Nota general del pedido (aparte de las notas de cada producto): se ve en la
  // comanda y en cocina. Se escribe en línea, igual que al registrar el pedido.
  Future<void> _guardarNotaPedido(BuildContext context, String nota) async {
    if (_api) {
      if (!context.mounted || !_puedeModificar(context)) return;
      await _ejecutar(
        context,
        // El nombre del cliente va en el mismo texto: se conserva.
        () => PedidoMozoService.instance.comentarioPedido(
          pedido.id,
          comentariosConNota(pedido.notas, nota),
        ),
        exito: nota.isEmpty
            ? 'Nota del pedido eliminada.'
            : 'Nota del pedido guardada.',
      );
      return;
    }
    actualizarNotaPedido(pedido.id, comentariosConNota(pedido.notas, nota));
    onCambio();
  }

  // Nota del pedido, arriba de los productos: mismo diseño que al registrar.
  Widget _notaDelPedido(BuildContext context) {
    final nota = notaGeneralDe(pedido.notas) ?? '';
    final editable = !pedido.terminado;
    if (nota.isEmpty && !editable) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _NotaPedidoEnLinea(
        key: ValueKey('nota-${pedido.id}'),
        inicial: nota,
        editable: editable,
        onGuardar: (texto) => _guardarNotaPedido(context, texto),
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
        exito: nota.isEmpty
            ? 'Nota del producto eliminada.'
            : 'Nota del producto guardada.',
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
      await _ejecutar(
        context,
        () => servicio.quitarDescuento(pedido.id, l.id),
        exito: 'Descuento quitado.',
      );
      return;
    }
    Future<void> aplicar(String? autorizoId) => servicio.aplicarDescuento(
      pedido.id,
      motivo: r.nombre,
      porcentaje: r.esPorcentaje,
      valor: r.monto,
      autorizoId: autorizoId,
    );
    // Si el supervisor cancela, no se aplicó nada y no hay aviso de éxito.
    var aplicado = false;
    final ok = await _ejecutar(context, () async {
      try {
        await aplicar(null);
        aplicado = true;
      } on ApiException catch (e) {
        if (e.statusCode != 403) rethrow;
        if (!context.mounted) return;
        final autorizo = await pedirAutorizacionSupervisor(context);
        if (autorizo == null) return;
        await aplicar(autorizo);
        aplicado = true;
      }
    });
    if (ok && aplicado && context.mounted) {
      showAppToast(
        context,
        'Descuento "${r.nombre}" aplicado.',
        type: ToastType.success,
      );
    }
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
    // Solo se cierra con la X: se puede seguir agregando productos.
    final agregado = await showBlurDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AgregarProductoDialog(
        pedido: pedido,
        esAdmin: esAdmin,
        onAgregado: onCambio,
      ),
    );
    if (agregado == true) onCambio();
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
    final monto = await showBlurDialog<double>(
      context: context,
      builder: (_) => PropinaDialog(actual: propinaDePedido(pedido.id)),
    );
    if (monto == null) return;
    establecerPropinaPedido(pedido.id, monto);
    // También en las notas del pedido, para que caja la vea en otro equipo.
    try {
      if (UuidHelper.isValid(pedido.id) && PedidoMozoService.instance.activo) {
        await PedidoMozoService.instance.comentarioPedido(
          pedido.id,
          comentariosConPropina(pedido.notas, monto),
        );
      }
    } catch (_) {
      if (context.mounted) {
        showAppToast(
          context,
          'La propina quedó solo en este equipo.',
          type: ToastType.info,
        );
      }
    }
    onCambio();
  }

  // Táper para llevar: grande o mediano, con precio editable.
  // Con el servidor, el táper sale del catálogo y se agrega como una fila más del
  // pedido (así el servidor la cobra y la cuenta en caja). Sin catálogo de tápers
  // se usa el táper local de la app (grande o mediano).
  Future<void> _editarTupper(BuildContext context) async {
    final catalogo = CatalogService.instance.tapers
        .where((t) => t.estado)
        .toList();
    if (_api && catalogo.isNotEmpty) {
      await _agregarTapersDelCatalogo(context, catalogo);
      return;
    }
    await _editarTupperLocal(context);
  }

  Future<void> _agregarTapersDelCatalogo(
    BuildContext context,
    List<Taper> catalogo,
  ) async {
    if (!_puedeModificar(context)) return;
    final elegidos = await showBlurDialog<List<TaperElegido>>(
      context: context,
      builder: (_) => TaperCatalogoDialog(tapers: catalogo),
    );
    if (elegidos == null || elegidos.isEmpty || !context.mounted) return;
    for (final e in elegidos) {
      final ok = await _ejecutar(
        context,
        () => PedidoMozoService.instance.agregarProducto(
          pedido.id,
          lineaDeTaper(e.taper, e.cantidad),
        ),
      );
      if (!ok) return;
    }
    if (context.mounted) {
      showAppToast(
        context,
        'Táper agregado al pedido #${pedido.numeroPedido}.',
        type: ToastType.success,
        titulo: 'Táper',
      );
    }
  }

  Future<void> _editarTupperLocal(BuildContext context) async {
    final lineas = detallesPorPedido[pedido.id] ?? [];
    if (lineas
        .where(esLineaTupper)
        .any((l) => montoPagadoDeLinea(l.id).abs() > 0.001)) {
      showAppToast(
        context,
        'El táper ya tiene pagos registrados.',
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

  // Agrega al pedido una promoción tal como la configuró el admin, o los
  // productos de cumpleaños (como en el registro del pedido).
  Future<void> _agregarPromocion(BuildContext context) async {
    if (!_puedeModificar(context)) return;
    final e = await elegirPromocionOCumpleanos(context);
    if (e == null || !context.mounted) return;
    final lineas = e.promocion != null
        ? [lineaDePromocion(e.promocion!)]
        : e.cumpleanos;
    final nombre =
        e.promocion?.promocion.nombre ?? configCumpleanos.value.nombre;
    for (final linea in lineas) {
      if (_api) {
        final ok = await _ejecutar(
          context,
          () => PedidoMozoService.instance.agregarProducto(pedido.id, linea),
        );
        if (!ok) return;
      } else {
        agregarLineaAPedido(pedido.id, linea);
        registrarConsumoAutomaticoDeLinea(linea);
      }
      if (!context.mounted) return;
    }
    if (!_api) onCambio();
    if (context.mounted) {
      showAppToast(
        context,
        '"$nombre" se agregó al pedido #${pedido.numeroPedido}.',
        type: ToastType.success,
        titulo: 'Promoción',
      );
    }
  }

  bool get _esAdmin =>
      AuthService.instance.currentUser?.administraPedidos ?? false;

  // Edita un producto ya registrado en el pedido (cambio de plato, extras, notas, cantidad)
  Future<void> _editarProducto(BuildContext context, PedidoLine l) async {
    if (!_puedeModificar(context)) return;
    if (l.promocion != null) {
      _cambiarProductosPromocion(context, l);
      return;
    }
    var item = cartasNotifier.value.where((c) => c.id == l.cartaId).firstOrNull;
    if (item == null) {
      final todos = await CatalogService.instance.cargarCarta();
      item = todos.where((c) => c.id == l.cartaId).firstOrNull;
    }
    if (item == null) {
      if (context.mounted) {
        showAppToast(
          context,
          'No se encontró el plato en la carta',
          type: ToastType.error,
        );
      }
      return;
    }

    final resultado = await showBlurDialog<ProductoConfigurado>(
      context: context,
      builder: (_) => ProductoOpcionesDialog(
        item: item!,
        esAdmin: _esAdmin,
        enCarrito: detallesPorPedido[pedido.id] ?? const [],
        tipoEntregaInicial: l.tipoEntrega,
        permitePrecioManual: true,
        lineaInicial: l,
      ),
    );
    if (resultado == null || !context.mounted) return;

    final lineaActualizada = l.copyWith(
      cantidad: resultado.cantidad,
      variante: resultado.variante,
      presentacion: resultado.presentacion,
      modificadores: resultado.modificadores,
      comentario: resultado.comentario,
      precioUnitario: resultado.precioUnitario,
      precioTotalLinea: resultado.totalLinea,
      tipoEntrega: resultado.tipoEntrega,
      precioManual: resultado.precioManual,
      motivoPrecio: resultado.motivoPrecio,
    );

    if (_api && PedidoMozoService.instance.puedeOperar(pedido)) {
      await _ejecutar(
        context,
        () => PedidoMozoService.instance.editarProductoFila(
          pedido.id,
          lineaActualizada,
        ),
        exito: 'Producto actualizado',
      );
    } else {
      reemplazarLineaDePedido(pedido.id, lineaActualizada);
      onCambio();
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

  // Traspaso a otro mozo: se ofrece a uno solo; mientras esté pendiente, este
  // mismo botón permite cancelarlo.
  Future<void> _traspasar(BuildContext context) async {
    final pendiente = traspasoPendienteDe(pedido.id);
    if (pendiente != null) {
      final cancelar = await showBlurDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertaApp(
          title: const Text('Traspaso pendiente'),
          content: Text(
            'El pedido espera que ${pendiente.destinoNombre} lo acepte. '
            '¿Quieres cancelar la solicitud?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Seguir esperando'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cancelar traspaso'),
            ),
          ],
        ),
      );
      if (cancelar != true || !context.mounted) return;
      await _ejecutar(
        context,
        () => TraspasoService.instance.cancelar(pendiente.id),
        exito: 'Traspaso cancelado.',
      );
      return;
    }
    final destino = await showBlurDialog<String>(
      context: context,
      builder: (_) => TraspasarPedidoDialog(pedido: pedido),
    );
    if (destino == null || !context.mounted) return;
    onCambio();
    showAppToast(
      context,
      'Solicitud enviada a $destino. El pedido sigue siendo tuyo hasta que '
      'acepte.',
      type: ToastType.success,
      titulo: 'Traspaso',
    );
  }

  // Administrador: reasigna el pedido a otro mozo sin aceptación.
  Future<void> _reasignar(BuildContext context) async {
    final destino = await showBlurDialog<String>(
      context: context,
      builder: (_) => TraspasarPedidoDialog(pedido: pedido, directo: true),
    );
    if (destino == null || !context.mounted) return;
    onCambio();
    showAppToast(
      context,
      'El pedido #${pedido.numeroPedido} ahora es de $destino.',
      type: ToastType.success,
      titulo: 'Reasignado',
    );
  }

  // Pedido de personal: pide el nuevo precio por unidad de un plato.
  Future<void> _editarPrecioPersonal(BuildContext context, PedidoLine l) async {
    if (!_puedeModificar(context)) return;
    final controlador = TextEditingController(
      text: l.precioUnitario.toStringAsFixed(2),
    );
    final precio = await showBlurDialog<double>(
      context: context,
      builder: (dialogContext) => AlertaApp(
        title: Text('Precio de ${l.nombrePlato}'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Precio al personal por unidad (S/)',
            prefixText: 'S/ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(
                controlador.text.trim().replaceAll(',', '.'),
              );
              if (v != null && v >= 0) Navigator.of(dialogContext).pop(v);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controlador.dispose();
    if (precio == null || !context.mounted) return;
    await _ejecutar(
      context,
      () => PedidoMozoService.instance.precioPersonalFila(pedido.id, l, precio),
      exito: 'Precio actualizado.',
    );
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
    final mesaAnterior = pedido.mesaNumero;
    final mesaNueva = mesas.where((m) => m.id == c.mesaId).firstOrNull?.numero;
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
      final cambioDeMesa = c.tipo == 'mesa' && eraMesa && mesaNueva != null;
      showAppToast(
        context,
        cambioDeMesa
            ? 'Mesa $mesaAnterior liberada · Mesa $mesaNueva ocupada. El '
                  'pedido #${pedido.numeroPedido} sigue con sus platos.'
            : 'El pedido #${pedido.numeroPedido} se actualizó.',
        type: ToastType.success,
        titulo: cambioDeMesa ? 'Cambio de mesa' : null,
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
        opcion,
        aplicaTaper: l.aplicaTaper,
      ),
      exito: switch (opcion) {
        'mesa' => '"${l.nombrePlato}" ahora es para comer en mesa.',
        'delivery' => '"${l.nombrePlato}" ahora es para delivery.',
        _ => '"${l.nombrePlato}" ahora es para llevar.',
      },
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
    final propinaLinea = propinaDePedido(pedido.id);
    final propina = propinaCobradaDePedido(pedido.id) > propinaLinea
        ? propinaCobradaDePedido(pedido.id)
        : propinaLinea;
    final cargosExtra = cargosExtraDe(pedido.id);
    final totalCargos = cargosExtra.fold(0.0, (s, x) => s + x.monto);
    final devoluciones = detalles
        .where(esAjusteDeDevolucion)
        .fold(0.0, (s, l) => s + l.precioTotalLinea);
    final cargo = detalles
        .where((l) => l.cartaId == cartaIdCargoDelivery)
        .fold(0.0, (s, l) => s + l.precioTotalLinea);
    final recargo = recargoCobradoDePedido(pedido.id);
    final totalCuenta = totalDePedido(pedido.id);
    final totalCobrado = totalCobradoDePedido(pedido.id);
    final totalBase =
        (recargo > 0.01 ? totalCobrado : totalCuenta) +
        (propina - propinaLinea);
    final saldo = saldoPendienteDePedido(pedido.id);
    final pagado = totalBase - saldo;
    final total = totalBase;
    final puedePagar = saldoCuentaDePedido(pedido.id) > 0.01;

    // Totales y botones quedan fijos abajo: solo la lista de productos se
    // desplaza.
    final pieTotales = Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
      child: Column(
        children: [
          _filaTotal('Subtotal', subtotal),
          if (cargo > 0) _filaTotal('Cargo por delivery', cargo),
          if (descProductos > 0)
            _filaTotal('Descuento de productos', -descProductos),
          _filaTotal(
            'Descuento',
            -descExtra,
            // El mozo solo usa las promociones que ya existen; el descuento a
            // medida lo ponen caja y administración.
            onEditar: _veCaja ? () => _agregarAjuste(context) : null,
          ),
          if (devoluciones.abs() > 0.001)
            _filaTotal('Ajustes por devolución', devoluciones),
          if (propina > 0)
            _filaTotal(
              'Propina',
              propina,
              onEditar: _esCajero ? null : () => _editarPropina(context),
            ),
          if (tupper > 0)
            _filaTotal(
              'Táper',
              tupper,
              onEditar: _esCajero ? null : () => _editarTupper(context),
            ),
          for (final x in cargosExtra)
            _filaTotal('Rotura/alq. ${x.nombre}', x.monto),
          if (recargo > 0.01) _filaTotal('Recargo por tarjeta', recargo),
          if (pagado > 0.01) _filaTotal('Pagado', pagado),
          // Con qué medio(s) se pagó, cada uno con su monto.
          if (pagado > 0.01)
            if (esPedidoDeEmpleado(pedido) &&
                abonosDePedido(pedido.id).length > 1)
              // Cada abono con su hora y medio: el último solo saldó la cuenta.
              for (final (i, a) in abonosDePedido(pedido.id).indexed)
                _filaTotal(
                  'Abono ${i + 1} · '
                  '${a.fecha.hour.toString().padLeft(2, '0')}:'
                  '${a.fecha.minute.toString().padLeft(2, '0')} · ${a.medio}',
                  a.monto,
                )
            else
              for (final m in pagosPorMedioDe(pedido.id))
                _filaTotal('Pagó con ${m.medio}', m.monto),
          // Efectivo que entregó el cliente y vuelto (solo en este dispositivo).
          if (efectivoRecibidoPorPedido[pedido.id] case final e?) ...[
            _filaTotal('Efectivo recibido', e.recibido),
            _filaTotal('Vuelto', e.vuelto),
          ],
          if (pagado > 0.01 && saldo > 0.01)
            _filaTotal('Saldo pendiente', saldo, color: AppColors.mesaOcupada),
          const SizedBox(height: 4),
          _filaTotal('Total', total, fuerte: true),
        ],
      ),
    );
    // Imprimir y Devolución se desplazan con el resto; solo Servido y Pagar
    // quedan fijos.
    final botonesSecundarios = _esCajero
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 0, 8),
            child: _botonesSecundarios(context, productos.isNotEmpty),
          );
    final pieBotones = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: _botonesFijos(context, puedePagar),
    );
    // Pie fijo: totales, acciones (Imprimir, WhatsApp, Devolución, Promoción,
    // Táper) y Servido/Pagar. En pantallas muy bajas se desplaza aparte para
    // no tapar los productos.
    final pieFijo = ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: pieTotales,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: botonesSecundarios,
            ),
            pieBotones,
          ],
        ),
      ),
    );

    // Celular: la cabecera es una sola fila y el pie fijo se reduce al total en
    // una línea y a los botones Más, Servido y Pagar; las demás acciones van en
    // el menú "Más". Así la lista de productos conserva casi todo el alto.
    final movil = AppBreakpoints.esMobile(context);
    final cantidadProductos = productos.fold<int>(0, (s, l) => s + l.cantidad);
    final pieFijoMovil = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _TotalCompacto(
            etiqueta:
                'Total · $cantidadProductos producto${cantidadProductos == 1 ? '' : 's'}',
            total: total,
            resumenPago: (pagado > 0.01 && saldo > 0.01)
                ? 'Pagado S/ ${pagado.toStringAsFixed(2)} · '
                      'Saldo S/ ${saldo.toStringAsFixed(2)}'
                : null,
            detalle: pieTotales,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: _botonesFijos(
            context,
            puedePagar,
            alto: 44,
            antes: _botonMas(
              context,
              hayProductos: productos.isNotEmpty,
              descuento: descExtra,
            ),
          ),
        ),
      ],
    );

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          movil ? _cabeceraMovil(context) : _cabecera(context),
          Divider(height: 1, color: Colors.grey.shade200),
          Expanded(
            child: IndicadorAbajo(
              builder: (ctl) => ListView(
                controller: ctl,
                padding: const EdgeInsets.fromLTRB(16, 14, 22, 8),
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
                  // Solo el administrador ve las líneas anuladas: deshabilitadas,
                  // con su etiqueta, y sin sumar en ningún total.
                  if (esAdmin)
                    for (final l
                        in lineasAnuladasPorPedido[pedido.id] ??
                            const <PedidoLine>[])
                      _filaAnulada(l),
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
                ],
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          movil ? pieFijoMovil : pieFijo,
        ],
      ),
    );
  }

  Widget _cabecera(BuildContext context) {
    final cliente = pedido.clienteNombre;
    return Container(
      color: Colors.white,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '#${pedido.numeroPedido}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Mozo: ${nombreMeseroDe(pedido)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                // Empleado o familia: una línea como la del cliente, sin etiqueta.
                if (esPedidoDeEmpleado(pedido) || esPedidoDeFamilia(pedido.id))
                  Text(
                    '${esPedidoDeEmpleado(pedido) ? 'Empleado' : 'Familia'}'
                    '${(nombreClienteDe(pedido) ?? '').trim().isEmpty ? '' : ': ${nombreClienteDe(pedido)!.trim()}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                if (cliente != null &&
                    !esPedidoDeEmpleado(pedido) &&
                    !esPedidoDeFamilia(pedido.id))
                  Text(
                    'Cliente: $cliente',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                if (traspasoPendienteDe(pedido.id) case final t?)
                  Text(
                    'Traspaso pendiente a ${t.destinoNombre}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.naranja,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // El selector de estado va arriba y, debajo, los botones (cancelar,
          // traspaso y cambio de mesa) repartidos en el mismo ancho.
          IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BadgeEstadoPedido(
                  pedido.estado,
                  bloque: true,
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
                      exito: 'Estado del pedido actualizado.',
                    );
                  },
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _botonCabecera(
                      icono: LucideIcons.trash2,
                      tooltip: 'Cancelar pedido',
                      color: Colors.white,
                      fondo: AppColors.error,
                      onTap: () => _cancelar(context),
                    ),
                    if (_api && pedido.abierto && esAdmin) ...[
                      const SizedBox(width: 6),
                      _botonCabecera(
                        icono: LucideIcons.users,
                        tooltip: 'Reasignar a otro mozo',
                        onTap: () => _reasignar(context),
                      ),
                    ] else if (_api &&
                        pedido.abierto &&
                        PedidoMozoService.instance.puedeOperar(pedido)) ...[
                      const SizedBox(width: 6),
                      _botonCabecera(
                        icono: LucideIcons.users,
                        tooltip: traspasoPendienteDe(pedido.id) == null
                            ? 'Traspasar a otro mozo'
                            : 'Traspaso pendiente: ver o cancelar',
                        color: traspasoPendienteDe(pedido.id) == null
                            ? null
                            : AppColors.naranja,
                        fondo: traspasoPendienteDe(pedido.id) == null
                            ? null
                            : AppColors.naranja.withValues(alpha: 0.18),
                        onTap: () => _traspasar(context),
                      ),
                    ],
                    if (_api) ...[
                      const SizedBox(width: 6),
                      _botonCabecera(
                        icono: LucideIcons.arrowLeftRight,
                        tooltip: 'Cambiar mesa o entrega',
                        onTap: () => _cambiarEntrega(context),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Cabecera de celular: una sola fila (volver, número y mesa, mozo, estado).
  // Cancelar, mozo y mesa o entrega pasan al menú "Más" del pie.
  Widget _cabeceraMovil(BuildContext context) {
    final cliente = pedido.clienteNombre;
    final estiloLinea = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      color: Colors.grey.shade600,
    );
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '#${pedido.numeroPedido} · ${pedido.ubicacion}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Mozo: ${nombreMeseroDe(pedido)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: estiloLinea,
                ),
                if (esPedidoDeEmpleado(pedido) || esPedidoDeFamilia(pedido.id))
                  Text(
                    '${esPedidoDeEmpleado(pedido) ? 'Empleado' : 'Familia'}'
                    '${(nombreClienteDe(pedido) ?? '').trim().isEmpty ? '' : ': ${nombreClienteDe(pedido)!.trim()}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: estiloLinea,
                  ),
                if (cliente != null &&
                    !esPedidoDeEmpleado(pedido) &&
                    !esPedidoDeFamilia(pedido.id))
                  Text(
                    'Cliente: $cliente',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: estiloLinea,
                  ),
                if (traspasoPendienteDe(pedido.id) case final t?)
                  Text(
                    'Traspaso pendiente a ${t.destinoNombre}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.naranja,
                    ),
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
                exito: 'Estado del pedido actualizado.',
              );
            },
          ),
        ],
      ),
    );
  }

  // Botón "Más" del pie de celular: abre el menú con las demás acciones.
  Widget _botonMas(
    BuildContext context, {
    required bool hayProductos,
    required double descuento,
  }) {
    return Tooltip(
      message: 'Más acciones',
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          side: BorderSide(color: Colors.grey.shade400),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          onTap: () => _abrirMasAcciones(
            context,
            hayProductos: hayProductos,
            descuento: descuento,
          ),
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(LucideIcons.ellipsis, size: 20, color: Colors.black87),
          ),
        ),
      ),
    );
  }

  // Menú "Más acciones": imprimir, WhatsApp, devolución, promoción, táper,
  // descuento, mozo, mesa o entrega y, al final y en rojo, anular el pedido.
  Future<void> _abrirMasAcciones(
    BuildContext context, {
    required bool hayProductos,
    required double descuento,
  }) {
    return showBlurDialog<void>(
      context: context,
      builder: (dialogContext) {
        Widget accion(
          IconData icono,
          String texto,
          VoidCallback onTap, {
          String? detalle,
          bool peligro = false,
        }) {
          final color = peligro ? AppColors.error : Colors.black87;
          return InkWell(
            onTap: () {
              Navigator.of(dialogContext).pop();
              onTap();
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Icon(icono, size: 19, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      texto,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ),
                  if (detalle != null)
                    Text(
                      detalle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        return DialogoApp(
          titulo: 'Más acciones',
          children: [
            if (_veCaja) ...[
              accion(
                LucideIcons.printer,
                'Imprimir cuenta',
                () => _imprimir(context),
              ),
              accion(
                LucideIcons.messageCircle,
                'Enviar la cuenta por WhatsApp',
                () => _enviarWhatsapp(context),
              ),
            ],
            if (hayProductos && pedido.tipoPedido != 'delivery')
              accion(
                LucideIcons.undo2,
                'Devolución',
                () => _devolucion(context),
              ),
            accion(
              LucideIcons.tag,
              'Promoción',
              () => _agregarPromocion(context),
            ),
            if (!_esCajero)
              accion(
                LucideIcons.package,
                'Táper',
                () => _editarTupper(context),
              ),
            if (config.propinaHabilitada)
              accion(
                LucideIcons.coins,
                'Propina',
                () => _editarPropina(context),
                detalle: propinaDePedido(pedido.id) > 0.004
                    ? 'S/ ${propinaDePedido(pedido.id).toStringAsFixed(2)}'
                    : null,
              ),
            if (_veCaja)
              accion(
                LucideIcons.percent,
                'Descuento',
                () => _agregarAjuste(context),
                detalle: descuento > 0.004
                    ? '- S/ ${descuento.toStringAsFixed(2)}'
                    : null,
              ),
            if (_api && pedido.abierto && esAdmin)
              accion(
                LucideIcons.users,
                'Cambiar mozo',
                () => _reasignar(context),
              )
            else if (_api &&
                pedido.abierto &&
                PedidoMozoService.instance.puedeOperar(pedido))
              accion(
                LucideIcons.users,
                traspasoPendienteDe(pedido.id) == null
                    ? 'Traspasar a otro mozo'
                    : 'Traspaso pendiente: ver o cancelar',
                () => _traspasar(context),
              ),
            if (_api)
              accion(
                LucideIcons.arrowLeftRight,
                'Cambiar mesa o entrega',
                () => _cambiarEntrega(context),
              ),
            accion(
              LucideIcons.trash2,
              'Anular pedido',
              () => _cancelar(context),
              peligro: true,
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  // Botón de la cabecera: más alto y de esquinas poco redondas; varios se
  // reparten el ancho de la fila.
  Widget _botonCabecera({
    required IconData icono,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
    Color? fondo,
  }) {
    return SizedBox(
      width: 38,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: fondo ?? Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: SizedBox(
              height: 34,
              child: Icon(
                icono,
                size: 15,
                color: color ?? Colors.grey.shade700,
              ),
            ),
          ),
        ),
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
  // Línea anulada o devuelta (solo la ve el administrador): no se puede tocar y
  // no suma en la cuenta ni en el pago.
  Widget _filaAnulada(PedidoLine l) {
    final etiqueta = l.estado == 'devuelto' ? 'Devuelto' : 'Anulado';
    final nombre = l.esLibre ? (l.nombreLibre ?? l.nombrePlato) : l.nombrePlato;
    return Opacity(
      opacity: 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l.cantidad}x $nombre',
                    softWrap: true,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  Text(
                    'S/ ${l.precioUnitario.toStringAsFixed(2)} × ${l.cantidad} · '
                    'no suma en la cuenta',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.tag),
              ),
              child: Text(
                etiqueta,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaLinea(BuildContext context, PedidoLine l) {
    final esProducto = esLineaDeProducto(l);
    final esCargo = l.cartaId == cartaIdCargoDelivery;
    final desc = _descripcionLinea(l);
    final pagadoLinea = montoPagadoDeLinea(l.id);
    final incidencia = l.estado == 'incidencia'
        ? incidenciaDeLinea(l.id)
        : null;
    final entregado = esProducto && lineasEntregadas.contains(l.id);
    final puedeEditar =
        esProducto &&
        !esCargo &&
        pedido.abierto &&
        l.estado != 'anulado' &&
        l.estado != 'devuelto' &&
        pagadoLinea == 0 &&
        !entregado;
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
                  // El cajero no marca entregas: la casilla queda deshabilitada.
                  onChanged: _esCajero
                      ? null
                      : (_) {
                          if (!_puedeModificar(context)) return;
                          // Actualización optimista instantánea
                          alternarLineaEntregada(l.id);
                          onCambio();

                          if (_api) {
                            _ejecutar(
                              context,
                              () => PedidoMozoService.instance.marcarServido(
                                pedido.id,
                                l,
                                !entregado,
                              ),
                              // Sin aviso de éxito por plato: solo se avisa
                              // al pasar el pedido completo a servido.
                            ).then((ok) {
                              if (!ok) {
                                // Si falló, revertir estado local
                                alternarLineaEntregada(l.id);
                                onCambio();
                              }
                            });
                          }
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
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: puedeEditar
                            ? () => _editarProducto(context, l)
                            : null,
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
                    ),
                    if (puedeEditar)
                      Tooltip(
                        message:
                            'Editar producto (cambio de plato, extras, precio)',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _editarProducto(context, l),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 15,
                              color: AppColors.naranja,
                            ),
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
                                  ? 'Quitar táper'
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
                              ? AppColors.naranja
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
                              color: AppColors.naranja,
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
                      comentarioVisible(l.comentario!),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${l.precioTotalLinea < 0 ? '-' : ''}S/ ${l.precioTotalLinea.abs().toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryGreenDark,
                        ),
                      ),
                      // Pedido de personal: caja y administración corrigen el
                      // precio por unidad de cada plato.
                      if (_api &&
                          _veCaja &&
                          pedido.abierto &&
                          esPedidoDeEmpleado(pedido) &&
                          esLineaDeProducto(l))
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _editarPrecioPersonal(context, l),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.edit_outlined, size: 15),
                          ),
                        ),
                    ],
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
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _stepper(context, l),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_api && !esLineaTaper(l)) ...[
                              _botonEntregaFila(context, l),
                              const SizedBox(width: 6),
                            ],
                            _botonNota(context, l),
                          ],
                        ),
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
    // Mismo diseño que en el registro de pedido: "−" con trazo gris y "+"
    // relleno de verde con el signo blanco, en cuadros de esquinas suaves.
    Widget boton(IconData icono, VoidCallback? onTap) {
      const lado = 26.0;
      final esMas = icono == Icons.add;
      final habilitado = onTap != null;
      final trazo = esMas ? AppColors.primaryGreen : Colors.grey.shade500;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(lado * 0.1),
          onTap: onTap,
          child: Container(
            width: lado,
            height: lado,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(lado * 0.1),
              color: esMas
                  ? (habilitado ? AppColors.primaryGreen : Colors.grey.shade300)
                  : null,
              border: Border.all(
                color: habilitado ? trazo : Colors.grey.shade300,
              ),
            ),
            child: Icon(
              icono,
              size: 16,
              color: esMas
                  ? Colors.white
                  : (habilitado ? trazo : Colors.grey.shade400),
            ),
          ),
        ),
      );
    }

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

  // Tipo del producto: mesa, para llevar o delivery (resguardo para corregir
  // un plato ya confirmado).
  Widget _botonEntregaFila(BuildContext context, PedidoLine l) {
    final tipo = l.tipoEntrega == 'llevar' || l.tipoEntrega == 'delivery'
        ? l.tipoEntrega
        : 'mesa';
    return MenuFlotante<String>(
      tooltip: switch (tipo) {
        'llevar' => 'Para llevar (cambiar tipo)',
        'delivery' => 'Delivery (cambiar tipo)',
        _ => 'En mesa (cambiar tipo)',
      },
      seleccionada: tipo,
      opciones: const [
        OpcionMenu(valor: 'mesa', etiqueta: 'Mesa'),
        OpcionMenu(valor: 'llevar', etiqueta: 'Para llevar'),
        OpcionMenu(valor: 'delivery', etiqueta: 'Delivery'),
      ],
      anchoMinimo: 180,
      onSeleccionar: (v) => _cambiarEntregaFila(context, l, v),
      disparador: (context, abierto) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          switch (tipo) {
            'llevar' => LucideIcons.packageCheck,
            'delivery' => LucideIcons.bike,
            _ => LucideIcons.utensils,
          },
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

  // Imprimir (oscuro) + Devolución, y debajo Servido + Pagar (naranja).
  // Pagar e imprimir son de administración y caja: el mozo no los ve.
  bool get _veCaja => !(AuthService.instance.currentUser?.esMozo ?? false);

  // El cajero hace lo mismo que el administrador en los pedidos: ya no hay
  // acciones recortadas para él.
  bool get _esCajero => false;

  // Imprimir / WhatsApp y Devolución: van dentro del scroll.
  // Botón circular de la fila de acciones: solo el ícono, con su nombre al
  // dejar el cursor encima.
  Widget _circulo({
    required String tooltip,
    required Widget icono,
    required VoidCallback? onTap,
    Color? fondo,
    Color? borde,
  }) {
    final activo = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: activo ? 1 : 0.45,
        child: Material(
          color: fondo ?? Colors.white,
          shape: CircleBorder(
            side: BorderSide(color: borde ?? Colors.transparent),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 40, height: 40, child: Center(child: icono)),
          ),
        ),
      ),
    );
  }

  // Imprimir, WhatsApp, Devolución, Promoción y Táper: una sola fila de
  // botones circulares.
  Widget _botonesSecundarios(BuildContext context, bool hayProductos) {
    final gris = Colors.grey.shade300;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        // El mozo no imprime ni manda la cuenta por WhatsApp.
        if (_veCaja) ...[
          _circulo(
            tooltip: 'Imprimir',
            fondo: AppColors.navbar,
            icono: const Icon(
              LucideIcons.printer,
              size: 18,
              color: Colors.white,
            ),
            onTap: () => _imprimir(context),
          ),
          _circulo(
            tooltip: 'Enviar la cuenta por WhatsApp',
            fondo: AppColors.navbar,
            icono: const IconoWhatsapp(tamano: 19),
            onTap: () => _enviarWhatsapp(context),
          ),
        ],
        _circulo(
          tooltip: 'Devolución',
          borde: gris,
          icono: const Icon(LucideIcons.undo2, size: 18, color: Colors.black87),
          onTap: hayProductos && pedido.tipoPedido != 'delivery'
              ? () => _devolucion(context)
              : null,
        ),
        _circulo(
          tooltip: 'Promoción',
          borde: AppColors.naranja,
          icono: const Icon(
            LucideIcons.tag,
            size: 18,
            color: AppColors.naranja,
          ),
          onTap: () => _agregarPromocion(context),
        ),
        if (!_esCajero)
          // Un cliente puede pedir solo un táper.
          _circulo(
            tooltip: 'Táper',
            borde: gris,
            icono: const Icon(
              LucideIcons.package,
              size: 18,
              color: Colors.black87,
            ),
            onTap: () => _editarTupper(context),
          ),
        // Propina: se anota aquí y aparece sola en Pagar.
        if (config.propinaHabilitada)
          _circulo(
            tooltip: propinaDePedido(pedido.id) > 0
                ? 'Propina S/ ${propinaDePedido(pedido.id).toStringAsFixed(2)}'
                : 'Propina',
            borde: propinaDePedido(pedido.id) > 0
                ? AppColors.primaryGreen
                : gris,
            icono: Icon(
              LucideIcons.coins,
              size: 18,
              color: propinaDePedido(pedido.id) > 0
                  ? AppColors.primaryGreenDark
                  : Colors.black87,
            ),
            onTap: () => _editarPropina(context),
          ),
      ],
    );
  }

  // Servido y Pagar: son los únicos botones fijos abajo.
  // Pedido abierto con productos y total en cero (cuenta cero de familia).
  bool get _esCuentaCero {
    final lineas = detallesPorPedido[pedido.id] ?? const <PedidoLine>[];
    // Solo cuentas que pueden valer cero a propósito (familia, empleado o
    // cumpleaños): un pedido de cliente con total en cero NO se cierra desde
    // aquí.
    return pedido.abierto &&
        motivoCuentaCero(pedido) != null &&
        lineas.any(esLineaDeProducto) &&
        totalDePedido(pedido.id).abs() < 0.005 &&
        abonadoDePedido(pedido.id) < 0.005;
  }

  bool get _esFamilia => esPedidoDeFamilia(pedido.id);

  String _textoCuentaCero(String? m) => switch (m) {
    'empleado' => 'un consumo de empleado',
    'cumpleanos' => 'un cumpleaños',
    _ => 'un consumo de familia',
  };

  String _rotuloCuentaCero(String? m) => switch (m) {
    'empleado' => 'CONSUMO DE EMPLEADO',
    'cumpleanos' => 'CUMPLEAÑOS',
    _ => 'CONSUMO DE FAMILIA',
  };

  // Pagar una cuenta cero: pregunta si se imprime el ticket. Siempre queda
  // registrado en el sistema como consumo de familia por S/ 0.00; imprimir o
  // no solo cambia si sale por la ticketera.
  Future<void> _pagarCuentaCero(BuildContext context) async {
    final imprimir = await showBlurDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertaApp(
        title: Text(_esFamilia ? 'Cerrar cuenta' : 'Cuenta cero'),
        content: Text(
          'Es ${_textoCuentaCero(motivoCuentaCero(pedido))} por S/ 0.00. '
          'Saldrá de Pedidos y quedará registrado en Ventas. '
          '¿Deseas imprimir el ticket?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No imprimir'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Imprimir ticket'),
          ),
        ],
      ),
    );
    if (imprimir == null || !context.mounted) return;
    try {
      final nombre = (pedido.clienteNombre ?? '').trim();
      final c = await FacturacionService.instance.emitir(
        pedidoId: pedido.id,
        tipoDocumento: 'ticket_venta',
        imprimir: imprimir,
        clienteDenominacion: nombre.isEmpty
            ? _rotuloCuentaCero(motivoCuentaCero(pedido))
            : '${_rotuloCuentaCero(motivoCuentaCero(pedido))} - '
                  '${nombre.toUpperCase()}',
      );
      // Cierra la cuenta con un pago en cero (efectivo).
      try {
        final medios = mediosPagoActivos;
        final medio = medios.firstWhere(
          (m) => m.grupo == 'efectivo',
          orElse: () => medios.first,
        );
        await PagoService.instance.registrar(
          pedido: pedido,
          medio: medio,
          montoAbonado: 0,
        );
      } catch (_) {
        // El servidor no acepta cobros en cero: la cuenta se quita de la cola
        // en este dispositivo (el ticket ya quedó registrado).
        await marcarCuentaCeroCerrada(pedido.id);
      }
      if (!context.mounted) return;
      if (imprimir) {
        await showBlurDialog<void>(
          context: context,
          builder: (_) =>
              ComprobanteEmitidoDialog(comprobante: c, pedido: pedido),
        );
      } else {
        showAppToast(
          context,
          'Ticket S/ 0.00 ${c.numeroComprobante} registrado (${_textoCuentaCero(motivoCuentaCero(pedido)).replaceFirst('un ', '')}).',
          type: ToastType.success,
        );
      }
      onCambio();
    } catch (e) {
      if (!context.mounted) return;
      showAppToast(
        context,
        e is ApiException
            ? e.message
            : e.toString().replaceFirst('Exception: ', ''),
        type: ToastType.error,
        titulo: 'Ticket no registrado',
      );
    }
  }

  Widget _botonesFijos(
    BuildContext context,
    bool puedePagar, {
    double alto = 36,
    Widget? antes,
  }) {
    const texto = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Servido y Pagar en la misma fila.
        Row(
          children: [
            if (antes != null) ...[antes, const SizedBox(width: 8)],
            // Siempre visible: queda desactivado cuando el pedido ya no está
            // pendiente (ya se sirvió o se cerró). El cajero no sirve pedidos.
            if (!_esCajero)
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      (pedido.estado == 'pendiente' ||
                          pedido.estado == 'pedido')
                      ? () {
                          if (!_puedeModificar(context)) return;
                          final prevEstado = pedido.estado;
                          actualizarEstadoPedido(pedido.id, 'servido');
                          onCambio();
                          _ejecutar(
                            context,
                            () => PedidoService.instance.cambiarEstadoPedido(
                              pedido.id,
                              'servido',
                            ),
                            exito: 'Pedido #${pedido.numeroPedido} servido.',
                          ).then((ok) {
                            if (!ok) {
                              actualizarEstadoPedido(pedido.id, prevEstado);
                              onCambio();
                            }
                          });
                        }
                      : null,
                  icon: const Icon(LucideIcons.utensilsCrossed, size: 16),
                  label: const Text('Servido', style: texto),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size(0, alto),
                    maximumSize: Size(double.infinity, alto),
                  ),
                ),
              ),
            if (_veCaja) ...[
              if (!_esCajero) const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  // La cuenta de familia (toda en cero) se cierra al terminar de
                  // servir: sale de Pedidos y queda el registro en Ventas.
                  // Empleado y cumpleaños solo llegan aquí si su total quedó en
                  // cero; ahí el botón sigue siendo Pagar. Ambos preguntan si
                  // se imprime el ticket.
                  onPressed: _esCuentaCero
                      ? (_esFamilia && pedido.estado != 'servido'
                            ? null
                            : () => _pagarCuentaCero(context))
                      : (puedePagar ? () => _elegirPago(context) : null),
                  icon: Icon(
                    _esCuentaCero && _esFamilia
                        ? LucideIcons.circleCheck
                        : LucideIcons.banknote,
                    size: 16,
                  ),
                  label: Text(
                    _esCuentaCero && _esFamilia ? 'Cerrar cuenta' : 'Pagar',
                    style: texto,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _naranjaPago,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size(0, alto),
                    maximumSize: Size(double.infinity, alto),
                  ),
                ),
              ),
            ],
          ],
        ),
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

  const _NotaDialog({required this.titulo, this.subtitulo, this.inicial});

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
          decoration: const InputDecoration(
            hintText: 'Ej. sin cebolla, poco picante',
          ),
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

// Botón "Nota" que despliega el campo en el mismo lugar (sin modal), igual que
// en el registro de pedido. "Guardar" envía la nota; la "x" la quita.
class _NotaPedidoEnLinea extends StatefulWidget {
  final String inicial;
  final bool editable;
  final Future<void> Function(String texto) onGuardar;

  const _NotaPedidoEnLinea({
    super.key,
    required this.inicial,
    required this.editable,
    required this.onGuardar,
  });

  @override
  State<_NotaPedidoEnLinea> createState() => _NotaPedidoEnLineaState();
}

class _NotaPedidoEnLineaState extends State<_NotaPedidoEnLinea> {
  late final TextEditingController _texto = TextEditingController(
    text: widget.inicial,
  );
  late bool _abierta = widget.inicial.isNotEmpty;
  bool _guardando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  bool get _cambio => _texto.text.trim() != widget.inicial.trim();

  Future<void> _guardar(String nota) async {
    setState(() => _guardando = true);
    await widget.onGuardar(nota);
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.editable) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Text(
          'Nota: ${widget.inicial}',
          style: const TextStyle(fontSize: 12.5),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _guardando
                ? null
                : () {
                    if (_abierta) {
                      final habia = widget.inicial.isNotEmpty;
                      _texto.clear();
                      setState(() => _abierta = false);
                      if (habia) _guardar('');
                    } else {
                      setState(() => _abierta = true);
                    }
                  },
            icon: Icon(_abierta ? Icons.close : Icons.add, size: 15),
            label: const Text('Nota'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              side: BorderSide(color: Colors.grey.shade600, width: 1.3),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (_abierta) ...[
          const SizedBox(height: 8),
          CampoTexto(
            controller: _texto,
            autofocus: widget.inicial.isEmpty,
            minLines: 3,
            maxLines: null,
            maxLength: 200,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Ej. cliente alérgico, llevar todo junto',
            ),
          ),
          if (_cambio && _texto.text.trim().isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _guardando
                    ? null
                    : () => _guardar(_texto.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
                child: const Text('Guardar'),
              ),
            ),
        ],
      ],
    );
  }
}

// Total del pedido en una línea (celular): al tocarlo se despliega el detalle
// completo (subtotal, descuento, propina, pagos…), que no ocupa lugar mientras
// no se pide.
class _TotalCompacto extends StatefulWidget {
  final String etiqueta;
  final double total;
  // Línea corta cuando hay un pago a medias (pagado y saldo).
  final String? resumenPago;
  final Widget detalle;

  const _TotalCompacto({
    required this.etiqueta,
    required this.total,
    required this.detalle,
    this.resumenPago,
  });

  @override
  State<_TotalCompacto> createState() => _TotalCompactoState();
}

class _TotalCompactoState extends State<_TotalCompacto> {
  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _abierto = !_abierto),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.etiqueta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (widget.resumenPago != null)
                        Text(
                          widget.resumenPago!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mesaOcupada,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  'S/ ${widget.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _abierto ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
        if (_abierto)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.35,
            ),
            child: SingleChildScrollView(child: widget.detalle),
          ),
      ],
    );
  }
}

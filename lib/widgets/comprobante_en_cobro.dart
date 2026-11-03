import '../data/cliente_comprobante_store.dart';
import '../data/cargos_extra_store.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../utils/datos_sede.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../models/comprobante.dart';
import '../models/pedido.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/facturacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/abrir_enlace.dart';
import '../utils/blur_dialog.dart';
import '../utils/uuid_helper.dart';
import '../utils/whatsapp_cuenta.dart';
import 'app_switch.dart';
import 'app_tag.dart';
import 'app_toast.dart';
import 'campo_texto.dart';
import 'dialogo_app.dart';
import 'emitir_comprobante_dialog.dart';
import 'whatsapp_cuenta_dialog.dart';

// Hasta este total (inclusive) el DNI de la boleta es opcional; por encima,
// SUNAT exige los datos del cliente.
const montoBoletaConDocumento = 700.0;

String _mensajeError(Object e) => e is ApiException
    ? e.message
    : e.toString().replaceFirst('Exception: ', '');

// Solo administración y caja eligen el comprobante al cobrar.
bool puedeElegirComprobante(Pedido pedido) {
  final u = AuthService.instance.currentUser;
  return UuidHelper.isValid(pedido.id) &&
      u != null &&
      (u.esAdmin || u.esCajero);
}

// Ítem editable para reportar a SUNAT (permite modificar nombre, cantidad y precio)
class ItemFacturacionEditable {
  final TextEditingController nombre;
  final TextEditingController cantidad;
  final TextEditingController precioUnitario;

  ItemFacturacionEditable({
    required String nombreInicial,
    required int cantidadInicial,
    required double precioUnitarioInicial,
  }) : nombre = TextEditingController(text: nombreInicial),
       cantidad = TextEditingController(text: cantidadInicial.toString()),
       precioUnitario = TextEditingController(
         text: precioUnitarioInicial.toStringAsFixed(2),
       );

  int get cant => int.tryParse(cantidad.text.trim()) ?? 1;
  double get pu => double.tryParse(precioUnitario.text.trim()) ?? 0.0;
  double get subtotal => cant * pu;

  // Boleta y factura no admiten líneas en cero: se marcan en rojo.
  bool get cantidadEnCero => (int.tryParse(cantidad.text.trim()) ?? 0) <= 0;
  bool get precioEnCero => pu <= 0;
  bool get enCero => cantidadEnCero || precioEnCero;

  Map<String, dynamic> toMap() => {
    'nombre': nombre.text.trim(),
    'cantidad': cant,
    'precio_unitario': pu,
    'subtotal': subtotal,
  };

  void dispose() {
    nombre.dispose();
    cantidad.dispose();
    precioUnitario.dispose();
  }
}

// Lo que el cajero eligió en el cobro: ticket de venta (interno, sin
// SUNAT), boleta (con o sin DNI) o factura (con RUC). El comprobante se emite
// después de registrar el cobro, porque el servidor no factura sin un pago.
class ComprobanteEnCobro extends ChangeNotifier {
  // Siempre se emite un comprobante: el ticket de venta es el de por defecto.
  ComprobanteEnCobro(this.total, {String tipoInicial = 'ticket_venta'})
    : tipo = tipoInicial;

  // Total que cubre el comprobante (en el pago compartido, lo de ese pagador).
  double total;

  String tipo;
  bool conDni = false;
  bool imprimir = true;
  // Boleta o factura con una sola línea "Consumo" en vez del detalle de platos.
  bool soloConsumo = false;
  bool get porConsumo => soloConsumo;
  void alternarSoloConsumo(bool v) {
    soloConsumo = v;
    recalcularItemsInflados();
    notifyListeners();
  }

  void alternarPorConsumo(bool v) => alternarSoloConsumo(v);
  bool incluirRecargo = false;
  bool incluirDelivery = false;
  void alternarIncluirRecargo(bool v) {
    incluirRecargo = v;
    recalcularItemsInflados();
    notifyListeners();
  }

  void alternarIncluirDelivery(bool v) {
    incluirDelivery = v;
    recalcularItemsInflados();
    notifyListeners();
  }

  final ruc = TextEditingController();
  final razon = TextEditingController();
  final direccion = TextEditingController();
  final dni = TextEditingController();
  final nombre = TextEditingController();

  // Ítems editables para reportar a SUNAT
  final List<ItemFacturacionEditable> itemsEditables = [];
  List<Map<String, dynamic>> itemsOriginales = [];
  double recargoTarjeta = 0.0;
  double costoDelivery = 0.0;
  final TextEditingController otrosExtrasCtrl = TextEditingController(
    text: '0.00',
  );

  double get otrosExtrasVal =>
      double.tryParse(otrosExtrasCtrl.text.trim()) ?? 0.0;
  double get igvPorcentaje =>
      FacturacionService.instance.cachedConfig?.igvPorcentaje ?? 18.0;
  double get totalIgv => (total * (igvPorcentaje / (100.0 + igvPorcentaje)));
  double get totalOpGravada => total - totalIgv;

  bool _inicializado = false;
  String? _pedidoIdInicializado;
  bool get inicializado => _inicializado;
  String? get pedidoIdInicializado => _pedidoIdInicializado;

  void asegurarInicializado(Pedido pedido, {double? recargoActual}) {
    final recargoObjetivo = (recargoActual != null && recargoActual > 0)
        ? recargoActual
        : recargoCobradoDePedido(pedido.id);

    if (_inicializado &&
        _pedidoIdInicializado == pedido.id &&
        (recargoObjetivo - recargoTarjeta).abs() < 0.001) {
      return;
    }
    _pedidoIdInicializado = pedido.id;
    _inicializado = true;

    final lineas = detallesPorPedido[pedido.id] ?? const [];
    final deliveryLinea = lineas
        .where((l) => l.cartaId == cartaIdCargoDelivery)
        .firstOrNull;
    costoDelivery =
        (deliveryLinea != null && deliveryLinea.precioTotalLinea > 0)
        ? deliveryLinea.precioTotalLinea
        : pedido.costoDelivery;

    recargoTarjeta = recargoObjetivo;

    final productos = lineas.where((l) {
      if (l.cartaId == cartaIdCargoDelivery) return false;
      if (esLineaPropina(l)) return false;
      if (l.cartaId == cartaIdAjuste && l.nombrePlato.startsWith('Descuento: '))
        return false;
      return true;
    }).toList();

    itemsOriginales = productos
        .map(
          (p) => {
            'nombre': p.esLibre
                ? (p.nombreLibre ?? p.nombrePlato)
                : p.nombrePlato,
            'cantidad': p.cantidad,
            'precio_unitario': p.precioUnitario,
            'subtotal': p.precioTotalLinea,
          },
        )
        .toList();

    recalcularItemsInflados(notificar: false);
  }

  void actualizarRecargo(double nuevo) {
    if ((nuevo - recargoTarjeta).abs() > 0.001) {
      recargoTarjeta = nuevo;
      recalcularItemsInflados();
    }
  }

  void recalcularItemsInflados({bool notificar = true}) {
    if (itemsOriginales.isEmpty) return;

    double baseTotal = 0.0;
    for (final it in itemsOriginales) {
      final double sub = (it['subtotal'] is num)
          ? (it['subtotal'] as num).toDouble()
          : 0.0;
      baseTotal += sub;
    }

    final double extraTarjeta = incluirRecargo ? recargoTarjeta : 0.0;
    final double extraDelivery = incluirDelivery ? costoDelivery : 0.0;
    final double extras = otrosExtrasVal;
    final double targetTotal =
        baseTotal + extraTarjeta + extraDelivery + extras;

    for (final it in itemsEditables) {
      it.dispose();
    }
    itemsEditables.clear();

    if (soloConsumo) {
      itemsEditables.add(
        ItemFacturacionEditable(
          nombreInicial: 'Por consumo',
          cantidadInicial: 1,
          precioUnitarioInicial: targetTotal,
        ),
      );
    } else {
      if (targetTotal > 0 &&
          baseTotal > 0 &&
          (extraTarjeta > 0 || extraDelivery > 0 || extras > 0)) {
        final factor = targetTotal / baseTotal;
        double sumaCalculada = 0.0;
        for (final it in itemsOriginales) {
          final String n = it['nombre']?.toString() ?? 'Plato';
          final int c = (it['cantidad'] is num)
              ? (it['cantidad'] as num).toInt()
              : 1;
          final double subOriginal = (it['subtotal'] is num)
              ? (it['subtotal'] as num).toDouble()
              : 0.0;
          final double subNuevo = double.parse(
            (subOriginal * factor).toStringAsFixed(2),
          );
          final double puNuevo = c > 0
              ? double.parse((subNuevo / c).toStringAsFixed(2))
              : subNuevo;
          sumaCalculada += subNuevo;
          itemsEditables.add(
            ItemFacturacionEditable(
              nombreInicial: n,
              cantidadInicial: c,
              precioUnitarioInicial: puNuevo,
            ),
          );
        }
        final double dif = double.parse(
          (targetTotal - sumaCalculada).toStringAsFixed(2),
        );
        if (dif != 0.0 && itemsEditables.isNotEmpty) {
          final last = itemsEditables.last;
          final nuevoSub = last.subtotal + dif;
          final nuevoPU = last.cant > 0 ? (nuevoSub / last.cant) : nuevoSub;
          last.precioUnitario.text = nuevoPU.toStringAsFixed(2);
        }
      } else {
        for (final it in itemsOriginales) {
          final String n = it['nombre']?.toString() ?? 'Plato';
          final int c = (it['cantidad'] is num)
              ? (it['cantidad'] as num).toInt()
              : 1;
          final double pu = (it['precio_unitario'] is num)
              ? (it['precio_unitario'] as num).toDouble()
              : 0.0;
          itemsEditables.add(
            ItemFacturacionEditable(
              nombreInicial: n,
              cantidadInicial: c,
              precioUnitarioInicial: pu,
            ),
          );
        }
      }
    }
    actualizarTotalReportado(notificar: notificar);
  }

  void actualizarTotalReportado({bool notificar = true}) {
    double t = 0.0;
    for (final it in itemsEditables) {
      t += it.subtotal;
    }
    total = t;
    if (notificar) {
      notifyListeners();
    }
  }

  void agregarItemLibre() {
    itemsEditables.add(
      ItemFacturacionEditable(
        nombreInicial: 'Ítem adicional',
        cantidadInicial: 1,
        precioUnitarioInicial: 0.0,
      ),
    );
    actualizarTotalReportado();
  }

  void quitarItem(int index) {
    if (itemsEditables.length > 1) {
      final removed = itemsEditables.removeAt(index);
      removed.dispose();
      actualizarTotalReportado();
    }
  }

  void restablecerOriginales() {
    otrosExtrasCtrl.text = '0.00';
    recalcularItemsInflados();
  }

  bool buscando = false;
  RucInfo? rucInfo;
  DniInfo? dniInfo;
  String? error;

  bool get emite => tipo != 'ninguno';
  // ¿Hay que imprimir después de la respuesta de SUNAT? (boleta o factura)
  bool get imprimirDespues => imprimir && tipo != 'ticket_venta';
  bool get boletaExigeDni => total > montoBoletaConDocumento;
  bool get dniValido => RegExp(r'^\d{8}$').hasMatch(dni.text.trim());
  bool get rucValido => RegExp(r'^\d{11}$').hasMatch(ruc.text.trim());

  // Solo boleta y factura validan el detalle; el ticket de venta es interno.
  bool get validaDetalle => tipo == 'boleta' || tipo == 'factura';
  int get lineasEnCero =>
      validaDetalle ? itemsEditables.where((i) => i.enCero).length : 0;

  // Por qué no se puede emitir (para el tooltip del botón); null si se puede.
  String? get motivoBloqueo {
    final n = lineasEnCero;
    if (n > 0) {
      return n == 1
          ? 'Hay 1 producto con precio o cantidad en cero. Corrígelo o quítalo '
                'del comprobante.'
          : 'Hay $n productos con precio o cantidad en cero. Corrígelos o '
                'quítalos del comprobante.';
    }
    return null;
  }

  // ¿Están los datos que pide el tipo elegido?
  bool get completo {
    if (lineasEnCero > 0) return false;
    switch (tipo) {
      case 'factura':
        return rucValido &&
            razon.text.trim().isNotEmpty &&
            (rucInfo?.puedeFacturarse ?? true);
      case 'boleta':
        if (!conDni) return !boletaExigeDni;
        return dniValido && nombre.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  void elegir(String nuevo) {
    tipo = nuevo;
    error = null;
    notifyListeners();
  }

  void cambio() => notifyListeners();

  void alternarDni(bool v) {
    conDni = v;
    notifyListeners();
  }

  void alternarImprimir(bool v) {
    imprimir = v;
    notifyListeners();
  }

  Future<void> buscarDni() async {
    if (!dniValido || buscando) return;
    buscando = true;
    error = null;
    notifyListeners();
    try {
      final info = await FacturacionService.instance.consultarDni(dni.text);
      dniInfo = info;
      nombre.text = info.nombreCompleto;
    } catch (e) {
      error = _mensajeError(e);
    } finally {
      buscando = false;
      notifyListeners();
    }
  }

  Future<void> buscarRuc() async {
    if (!rucValido || buscando) return;
    buscando = true;
    error = null;
    notifyListeners();
    try {
      final info = await FacturacionService.instance.consultarRuc(ruc.text);
      rucInfo = info;
      razon.text = info.razonSocial;
      direccion.text = info.direccionFiscal;
      if (!info.puedeFacturarse) {
        error =
            'El RUC figura ${info.estado} / ${info.condicion}: SUNAT no '
            'acepta facturas a ese contribuyente.';
      }
    } catch (e) {
      error = _mensajeError(e);
    } finally {
      buscando = false;
      notifyListeners();
    }
  }

  // Emite el comprobante elegido para [pedido].
  // [pagoId] solo se especifica si se desea facturar un pago individual específico (pago compartido).
  // Si no se especifica [pagoId], se emite por la totalidad del pedido (todos los platos y pagos).
  // Con [items] se envían los platos, cantidades y precios personalizados editados por el cajero.
  Future<Comprobante> emitir(
    Pedido pedido, {
    String? pagoId,
    List<Map<String, dynamic>>? items,
    double? otrosExtras,
  }) async {
    final List<Map<String, dynamic>> itemsParaEnviar = [
      ...((items != null && items.isNotEmpty)
          ? items
          : (tipo != 'ticket_venta' && itemsEditables.isNotEmpty
                ? itemsEditables.map((e) => e.toMap()).toList()
                : [])),
    ];

    // Roturas o alquiler cobrados con el pedido: van como ítems del comprobante
    // y, si no se mandan ítems, como extra para que entren en el total.
    // Un comprobante de un solo pago no lleva las roturas de la cuenta.
    final cargos = pagoId == null
        ? cargosExtraDe(pedido.id)
        : const <CargoExtra>[];
    var extrasBase = otrosExtras ?? (otrosExtrasVal > 0 ? otrosExtrasVal : 0.0);
    if (cargos.isNotEmpty) {
      if (itemsParaEnviar.isNotEmpty) {
        for (final x in cargos) {
          itemsParaEnviar.add({
            'nombre': 'Rotura/alq. ${x.nombre}',
            'cantidad': 1,
            'precio_unitario': x.monto,
            'subtotal': x.monto,
          });
        }
      } else {
        // En backend facturacion_repository ya se leen directamente los pedido_cargo_extra de la BD
      }
    }
    final double? extrasParaEnviar = extrasBase > 0 ? extrasBase : null;

    final emitido = await FacturacionService.instance.emitir(
      pedidoId: pedido.id,
      tipoDocumento: tipo,
      pagoId: pagoId,
      imprimir: tipo == 'ticket_venta' && imprimir,
      soloConsumo: soloConsumo && tipo != 'ticket_venta',
      porConsumo: soloConsumo && tipo != 'ticket_venta',
      incluirRecargo: incluirRecargo && tipo != 'ticket_venta',
      incluirDelivery: incluirDelivery && tipo != 'ticket_venta',
      otrosExtras: extrasParaEnviar,
      items: itemsParaEnviar.isNotEmpty ? itemsParaEnviar : null,
      clienteTipoDoc: switch (tipo) {
        'factura' => '6',
        'boleta' => conDni ? '1' : '0',
        _ => null,
      },
      clienteNumDoc: switch (tipo) {
        'factura' => ruc.text.trim(),
        'boleta' => conDni ? dni.text.trim() : '00000000',
        _ => null,
      },
      clienteDenominacion: switch (tipo) {
        'factura' => razon.text.trim(),
        'boleta' => conDni ? nombre.text.trim() : 'CLIENTES VARIOS',
        _ => null,
      },
      clienteDireccion: tipo == 'factura' ? direccion.text.trim() : null,
    );
    // El ticket de la cuenta usa este nombre en lugar de "CLIENTES VARIOS".
    recordarClienteDeComprobante(
      pedido.id,
      nombre: emitido.clienteDenominacion,
      tipoDoc: emitido.clienteTipoDoc,
      documento: emitido.clienteNumDoc,
    );
    return emitido;
  }

  @override
  void dispose() {
    for (final it in itemsEditables) {
      it.dispose();
    }
    otrosExtrasCtrl.dispose();
    for (final c in [ruc, razon, direccion, dni, nombre]) {
      c.dispose();
    }
    super.dispose();
  }
}

// Qué parte de la sección "Comprobante" se dibuja: todo junto, solo el tipo
// (título y botones) o solo el detalle (datos del cliente, ítems y desglose).
// El modal de pagar las separa: el tipo va en el pie fijo y el detalle, que
// puede ser largo, en la parte con scroll.
enum ParteComprobante { todo, tipo, detalle }

// Sección "Comprobante" del diálogo de cobro.
class SelectorComprobante extends StatelessWidget {
  final ComprobanteEnCobro control;
  final Pedido? pedido;
  final double? recargoActual;
  final ParteComprobante parte;

  const SelectorComprobante({
    super.key,
    required this.control,
    this.pedido,
    this.recargoActual,
    this.parte = ParteComprobante.todo,
  });

  Widget _campo(
    TextEditingController c,
    String etiqueta, {
    TextInputType? teclado,
    List<TextInputFormatter>? formato,
    int? largo,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: CampoTexto(
      controller: c,
      keyboardType: teclado,
      inputFormatters: formato,
      maxLength: largo,
      onChanged: (_) => control.cambio(),
      decoration: InputDecoration(labelText: etiqueta, counterText: ''),
    ),
  );

  Widget _formulario() {
    final solo = <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly];
    switch (control.tipo) {
      case 'factura':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // La lupa va alineada con la caja del campo (no con su etiqueta).
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: CampoTexto(
                    controller: control.ruc,
                    keyboardType: TextInputType.number,
                    inputFormatters: solo,
                    maxLength: 11,
                    onChanged: (_) => control.cambio(),
                    decoration: const InputDecoration(
                      labelText: 'RUC (11 dígitos)',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: AppSizes.boton,
                  height: AppSizes.boton,
                  child: IconButton.filled(
                    tooltip: 'Buscar en SUNAT',
                    onPressed: control.rucValido && !control.buscando
                        ? control.buscarRuc
                        : null,
                    icon: control.buscando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.search, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _campo(control.razon, 'Razón social'),
            _campo(control.direccion, 'Dirección fiscal'),
          ],
        );
      case 'boleta':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '¿El cliente quiere su DNI en la boleta?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                AppSwitch(
                  value: control.conDni,
                  onChanged: control.alternarDni,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (control.conDni) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: CampoTexto(
                      controller: control.dni,
                      keyboardType: TextInputType.number,
                      inputFormatters: solo,
                      maxLength: 8,
                      onChanged: (v) {
                        control.cambio();
                        if (v.trim().length == 8 && !control.buscando) {
                          control.buscarDni();
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'DNI (8 dígitos)',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: AppSizes.boton,
                    height: AppSizes.boton,
                    child: IconButton.filled(
                      tooltip: 'Buscar en RENIEC / SUNAT',
                      onPressed: control.dniValido && !control.buscando
                          ? control.buscarDni
                          : null,
                      icon: control.buscando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(LucideIcons.search, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _campo(control.nombre, 'Nombre del cliente'),
            ] else
              Text(
                control.boletaExigeDni
                    ? 'Por el monto (más de S/ ${montoBoletaConDocumento.toStringAsFixed(0)}) '
                          'SUNAT exige el DNI del cliente.'
                    : 'Sin DNI sale a nombre de CLIENTES VARIOS.',
                style: TextStyle(
                  fontSize: 12,
                  color: control.boletaExigeDni
                      ? AppColors.error
                      : Colors.grey.shade600,
                ),
              ),
          ],
        );
      case 'ticket_venta':
        return Text(
          'Constancia interna de consumo: no se envía a SUNAT ni pide datos '
          'del cliente.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // Ancho de la columna P. Unit.: cabe un monto de cuatro cifras con decimales.
  static const double _anchoPrecioUnitario = 96;

  // El aviso ocupa 0 de alto: solo se ve el borde rojo del campo.
  static const _sinTextoError = TextStyle(fontSize: 0, height: 0);

  Widget _construirSeccionItems(BuildContext context) {
    final avisar = control.validaDetalle;
    final enCero = control.lineasEnCero;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.receiptText,
                size: 16,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Detalle a reportar a SUNAT',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              if (!control.soloConsumo) ...[
                OutlinedButton.icon(
                  onPressed: control.agregarItemLibre,
                  icon: const Icon(LucideIcons.plus, size: 14),
                  label: const Text(
                    'Agregar plato',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: BorderSide(color: Colors.grey.shade300),
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Restablecer platos originales',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: control.restablecerOriginales,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Icon(
                        LucideIcons.rotateCcw,
                        size: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (!control.soloConsumo) ...[
            const SizedBox(height: 6),
            CampoTexto(
              controller: control.otrosExtrasCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Otros extras a absorber (ej. mantel, rotura vasos)',
                prefixText: 'S/ ',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              // Al cambiarlo, los extras se reparten solos en el precio de los
              // platos.
              onChanged: (_) => control.recalcularItemsInflados(),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      'Cant.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Descripción / Plato',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  SizedBox(
                    width: _anchoPrecioUnitario,
                    child: Text(
                      'P. Unit.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(width: 6),
                  SizedBox(
                    width: 65,
                    child: Text(
                      'Subtotal',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(width: 28),
                ],
              ),
            ),
            if (enCero > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.triangleAlert,
                      size: 14,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        enCero == 1
                            ? '1 producto con precio o cantidad en cero. '
                                  'Ingresa otro valor o quítalo.'
                            : '$enCero productos con precio o cantidad en '
                                  'cero. Ingresa otro valor o quítalos.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: control.itemsEditables.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 4, thickness: 0.5),
                itemBuilder: (context, idx) {
                  final it = control.itemsEditables[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: CampoTexto(
                            controller: it.cantidad,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              isDense: true,
                              errorText: avisar && it.cantidadEnCero
                                  ? ' '
                                  : null,
                              errorStyle: _sinTextoError,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 6,
                              ),
                            ),
                            onChanged: (_) =>
                                control.actualizarTotalReportado(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: CampoTexto(
                            controller: it.nombre,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                            ),
                            onChanged: (_) => control.cambio(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: _anchoPrecioUnitario,
                          child: CampoTexto(
                            controller: it.precioUnitario,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              isDense: true,
                              errorText: avisar && it.precioEnCero ? ' ' : null,
                              errorStyle: _sinTextoError,
                              // El "S/" va como prefijo pequeño para dejar
                              // sitio al monto (antes lo cortaba).
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Text(
                                  'S/',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 0,
                                minHeight: 0,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 6,
                              ),
                            ),
                            onChanged: (_) =>
                                control.actualizarTotalReportado(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 65,
                          child: Text(
                            'S/ ${it.subtotal.toStringAsFixed(2)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 28,
                          child: IconButton(
                            icon: const Icon(
                              LucideIcons.trash2,
                              size: 14,
                              color: AppColors.error,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            onPressed: control.itemsEditables.length > 1
                                ? () => control.quitarItem(idx)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '1 x Por consumo',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    'S/ ${control.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirDesgloseFiscal() {
    final igvPorc = control.igvPorcentaje;
    final igvLabel = (igvPorc % 1 == 0) ? '${igvPorc.toInt()}%' : '$igvPorc%';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Op. gravada', style: TextStyle(fontSize: 12)),
              Text(
                'S/ ${control.totalOpGravada.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'I.G.V. ($igvLabel Sede)',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'S/ ${control.totalIgv.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total a reportar a SUNAT',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
              Text(
                'S/ ${control.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Nota: SUNAT no acepta conceptos como recargos o delivery en comida; los extras se absorben distribuyéndose en el precio de los platos.',
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (pedido != null && (!control.inicializado || control.pedidoIdInicializado != pedido!.id)) {
      control.asegurarInicializado(
        pedido!,
        recargoActual: recargoActual,
      );
    }
    return ListenableBuilder(
      listenable: control,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (parte != ParteComprobante.detalle) ...[
            const Text(
              'Comprobante',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 8,
              children: [
                for (final t in [
                  ('ticket_venta', 'Ticket de venta'),
                  ('boleta', 'Boleta'),
                  ('factura', 'Factura'),
                ])
                  AppTag(
                    etiqueta: t.$2,
                    activo: control.tipo == t.$1,
                    onTap: () => control.elegir(t.$1),
                  ),
              ],
            ),
          ],
          if (control.emite && parte != ParteComprobante.tipo) ...[
            if (parte == ParteComprobante.todo) const SizedBox(height: 14),
            _formulario(),
            if (control.tipo != 'ticket_venta') ...[
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emitir por consumo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Agrupa todo el pedido en un solo concepto "Por consumo"',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  AppSwitch(
                    value: control.soloConsumo,
                    onChanged: control.alternarSoloConsumo,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (control.recargoTarjeta > 0.001) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Incluir recargo del medio de pago (+S/ ${control.recargoTarjeta.toStringAsFixed(2)})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            'Absorbe la comisión financiera prorrateándola en los platos',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    AppSwitch(
                      value: control.incluirRecargo,
                      onChanged: control.alternarIncluirRecargo,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              if (control.costoDelivery > 0.001) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Incluir costo de delivery (+S/ ${control.costoDelivery.toStringAsFixed(2)})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            'Añade el flete de envío prorrateándolo en los platos',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    AppSwitch(
                      value: control.incluirDelivery,
                      onChanged: control.alternarIncluirDelivery,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              // Sección de Ítems Editables
              _construirSeccionItems(context),
              const SizedBox(height: 12),
              // Desglose fiscal (IGV de Sede y Op. Gravada)
              _construirDesgloseFiscal(),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Imprimir en la ticketera de caja',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                AppSwitch(
                  value: control.imprimir,
                  onChanged: control.alternarImprimir,
                ),
              ],
            ),
          ],
          if (control.error != null && parte != ParteComprobante.tipo) ...[
            const SizedBox(height: 8),
            Text(
              control.error!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}

// Emite lo elegido una vez registrado el cobro. Si el servidor lo rechaza el
// cobro ya quedó guardado: se avisa y se deja reintentar.
Future<void> emitirComprobanteTrasCobro(
  BuildContext context,
  Pedido pedido,
  ComprobanteEnCobro eleccion, {
  String? pagoId,
}) async {
  if (!eleccion.emite) return;
  while (context.mounted) {
    try {
      final c = await eleccion.emitir(pedido, pagoId: pagoId);
      if (!context.mounted) return;
      await showBlurDialog<void>(
        context: context,
        builder: (_) => ComprobanteEmitidoDialog(
          comprobante: c,
          pedido: pedido,
          imprimirAlConfirmar: eleccion.imprimirDespues,
        ),
      );
      return;
    } catch (e) {
      if (!context.mounted) return;
      final accion = await showBlurDialog<String>(
        context: context,
        builder: (dialogContext) => AlertaApp(
          title: const Text('Comprobante no emitido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'El cobro quedó registrado, pero no se pudo emitir el comprobante:\n'
                '${_mensajeError(e)}',
              ),
              const SizedBox(height: 12),
              const Text(
                'Puedes reintentar el envío o abrir el formulario para revisar y editar los datos manualmente.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('cerrar'),
              child: const Text('Cerrar'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop('manual'),
              child: const Text('Editar / Manual'),
            ),
            // El cajero no reintenta desde aquí: avisa al administrador.
            if (!(AuthService.instance.currentUser?.esCajero ?? false))
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop('reintentar'),
                child: const Text('Reintentar'),
              ),
          ],
        ),
      );
      if (accion == 'manual') {
        if (!context.mounted) return;
        final res = await showBlurDialog<EmisionHecha>(
          context: context,
          builder: (_) => EmitirComprobanteDialog(pedido: pedido),
        );
        if (res != null && context.mounted) {
          await showBlurDialog<void>(
            context: context,
            builder: (_) => ComprobanteEmitidoDialog(
              comprobante: res.comprobante,
              pedido: pedido,
              imprimirAlConfirmar: res.imprimirDespues,
            ),
          );
        }
        return;
      }
      if (accion != 'reintentar') return;
    }
  }
}

// Llamadas al servidor del resultado de la emisión. Se pueden reemplazar en las
// pruebas para simular la respuesta de SUNAT sin red.
@visibleForTesting
Future<Comprobante> Function(String id) consultarEstadoComprobante = (id) =>
    FacturacionService.instance.consultarEstado(id);
@visibleForTesting
Future<void> Function(String id) imprimirComprobante = (id) =>
    FacturacionService.instance.reimprimir(id);
@visibleForTesting
Duration esperaEntreConsultas = const Duration(seconds: 2);

// Resultado de la emisión: número, estado y accesos al PDF, la impresora y
// WhatsApp. SUNAT tarda unos segundos en responder: si el comprobante quedó
// pendiente se consulta su estado cada pocos segundos y, cuando llega la
// respuesta, se imprime (si se pidió) con los datos ya confirmados.
class ComprobanteEmitidoDialog extends StatefulWidget {
  final Comprobante comprobante;
  final Pedido pedido;
  // Imprimir apenas SUNAT confirme (boleta y factura).
  final bool imprimirAlConfirmar;

  const ComprobanteEmitidoDialog({
    super.key,
    required this.comprobante,
    required this.pedido,
    this.imprimirAlConfirmar = false,
  });

  @override
  State<ComprobanteEmitidoDialog> createState() =>
      _ComprobanteEmitidoDialogState();
}

class _ComprobanteEmitidoDialogState extends State<ComprobanteEmitidoDialog> {
  static const _maxIntentos = 10;

  late Comprobante _c = widget.comprobante;
  Timer? _timer;
  bool _esperando = false;
  bool _impreso = false;
  int _intentos = 0;

  @override
  void initState() {
    super.initState();
    if (_c.pendiente) {
      _esperar();
    } else {
      _imprimirSiCorresponde();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _esperar() {
    _timer?.cancel();
    _intentos = 0;
    setState(() => _esperando = true);
    _timer = Timer.periodic(esperaEntreConsultas, (_) async {
      _intentos++;
      try {
        final nuevo = await consultarEstadoComprobante(_c.id);
        if (!mounted) return;
        setState(() => _c = nuevo);
      } catch (_) {
        // Un fallo puntual de red no corta la espera.
      }
      if (!mounted) return;
      if (!_c.pendiente) {
        _timer?.cancel();
        setState(() => _esperando = false);
        _imprimirSiCorresponde();
      } else if (_intentos >= _maxIntentos) {
        _timer?.cancel();
        setState(() => _esperando = false);
      }
    });
  }

  // Imprime una sola vez, y solo si SUNAT no lo rechazó.
  Future<void> _imprimirSiCorresponde() async {
    if (!widget.imprimirAlConfirmar || _impreso) return;
    if (_c.rechazado || _c.anulado || _c.pendiente) return;
    _impreso = true;
    await _reimprimir(_c);
  }

  Future<void> _reimprimir(Comprobante c) async {
    try {
      await imprimirComprobante(c.id);
      if (mounted) {
        showAppToast(
          context,
          'Comprobante enviado a la impresora de caja.',
          type: ToastType.success,
        );
      }
    } catch (e) {
      _impreso = false;
      if (mounted) {
        showAppToast(context, _mensajeError(e), type: ToastType.error);
      }
    }
  }

  Future<void> _whatsapp(Comprobante c) async {
    final url = c.pdfTicketUrl ?? c.pdfA4Url;
    if (url == null) return;
    final numero = await showBlurDialog<String>(
      context: context,
      builder: (_) =>
          WhatsappCuentaDialog(celularInicial: widget.pedido.clienteCelular),
    );
    if (numero == null || !mounted) return;
    final texto =
        'Hola, te enviamos tu ${c.tipoEtiqueta.toLowerCase()} '
        '${c.numeroComprobante} de ${nombreDelNegocio().isEmpty ? 'nuestro restaurante' : nombreDelNegocio()}. '
        'Total: S/ ${c.total.toStringAsFixed(2)}. Descárgala aquí: $url';
    final abierto = await abrirWhatsapp(numero, texto);
    if (!abierto && mounted) {
      showAppToast(
        context,
        'No se pudo abrir WhatsApp.',
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ok = c.estadoSunat == 'ACEPTADO' || c.esInterno;
    final color = ok
        ? AppColors.primaryGreen
        : (c.rechazado ? AppColors.error : AppColors.naranja);
    return DialogoApp(
      titulo: 'Comprobante emitido',
      ancho: 460,
      acciones: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Listo'),
        ),
      ],
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    c.numeroComprobante,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${c.tipoEtiqueta} · ${c.estadoEtiqueta} · '
                    'S/ ${c.total.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: color),
                  ),
                  if (_esperando)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Esperando la respuesta de SUNAT…',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (c.pendiente)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        children: [
                          Text(
                            widget.imprimirAlConfirmar
                                ? 'SUNAT aún no responde. El comprobante quedó '
                                      'guardado y se imprimirá cuando llegue la '
                                      'respuesta.'
                                : 'SUNAT aún no confirma. Revisa su estado en '
                                      'Caja.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                          TextButton(
                            onPressed: _esperar,
                            child: const Text('Consultar de nuevo'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (c.pdfTicketUrl != null)
                  OutlinedButton.icon(
                    onPressed: () => abrirEnlace(c.pdfTicketUrl!),
                    icon: const Icon(LucideIcons.fileText, size: 16),
                    label: const Text('PDF ticket'),
                  ),
                if (c.pdfA4Url != null)
                  OutlinedButton.icon(
                    onPressed: () => abrirEnlace(c.pdfA4Url!),
                    icon: const Icon(LucideIcons.fileText, size: 16),
                    label: const Text('PDF A4'),
                  ),
                OutlinedButton.icon(
                  onPressed: c.pendiente ? null : () => _reimprimir(c),
                  icon: const Icon(LucideIcons.printer, size: 16),
                  label: const Text('Reimprimir'),
                ),
                if (c.pdfTicketUrl != null || c.pdfA4Url != null)
                  FilledButton.icon(
                    onPressed: () => _whatsapp(c),
                    icon: const Icon(LucideIcons.messageCircle, size: 16),
                    label: const Text('Enviar por WhatsApp'),
                    style: estiloBotonWhatsapp,
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

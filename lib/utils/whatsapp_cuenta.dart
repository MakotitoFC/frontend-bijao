import 'package:url_launcher/url_launcher.dart';

import '../data/configuracion_store.dart';
import '../data/pedidos_store.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import 'ticket_texto.dart';

// Envío de la cuenta al cliente por WhatsApp: se abre un chat con el número del
// cliente y el mensaje ya escrito (`wa.me`); el mozo o cajero solo da "Enviar".

// Deja el número listo para `wa.me` (solo dígitos, con código de país). Un
// celular peruano de 9 dígitos recibe el 51. Devuelve null si no parece válido.
String? numeroWhatsapp(String? crudo) {
  final digitos = (crudo ?? '').replaceAll(RegExp(r'\D'), '');
  if (digitos.isEmpty) return null;
  if (digitos.length == 9 && digitos.startsWith('9')) return '51$digitos';
  if (digitos.length < 10 || digitos.length > 15) return null;
  return digitos;
}

Uri urlWhatsapp(String numero, String mensaje) =>
    Uri.https('wa.me', '/$numero', {'text': mensaje});

// Abre WhatsApp (app o web) con el mensaje. Devuelve false si no se pudo abrir.
Future<bool> abrirWhatsapp(String numero, String mensaje) async {
  try {
    return await launchUrl(
      urlWhatsapp(numero, mensaje),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

const _separadorWhatsapp = '--------------------------------';

String _dos(int n) => n.toString().padLeft(2, '0');

// "20/10/2026, 08:37 a. m."
String _fechaHoraWhatsapp(DateTime d) {
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${_dos(d.day)}/${_dos(d.month)}/${d.year}, ${_dos(h12)}:${_dos(d.minute)} '
      '${d.hour < 12 ? 'a. m.' : 'p. m.'}';
}

// Texto del pedido para WhatsApp (lo que se manda al delivery). WhatsApp no usa
// letra de ancho fijo, así que no se arma en columnas como el ticket: un bloque
// por producto y los importes debajo. [recargo] es lo que se cobra de más por
// el método de pago (tarjeta) y se suma al total que paga el cliente.
String textoCuentaWhatsapp({
  required Pedido pedido,
  required List<PedidoLine> lineas,
  String metodoPago = '',
  double pagado = 0,
  double recargo = 0,
}) {
  double suma(Iterable<PedidoLine> ls) =>
      ls.fold(0.0, (s, l) => s + l.precioTotalLinea);
  final productos = [
    for (final l in lineas)
      if (esLineaDeProducto(l)) l,
  ];
  final subtotal = productos.fold(
    0.0,
    (s, l) => s + l.precioTotalLinea + l.descuentoAplicado,
  );
  final descProductos = productos.fold(0.0, (s, l) => s + l.descuentoAplicado);
  final descExtra = -suma(
    lineas.where(
      (l) =>
          l.cartaId == cartaIdAjuste && l.nombrePlato.startsWith('Descuento: '),
    ),
  );
  final cargo = suma(lineas.where((l) => l.cartaId == cartaIdCargoDelivery));
  final propina = suma(lineas.where(esLineaPropina));
  final tupper = suma(lineas.where(esLineaTupper));
  final devoluciones = suma(lineas.where(esAjusteDeDevolucion));
  final total = suma(lineas);
  final conRecargo = recargo > 0.001;
  final totalCobrado = total + (conRecargo ? recargo : 0);
  final saldo = total - pagado;

  String dato(String? v) => (v ?? '').trim();
  final nombre = dato(pedido.clienteNombre);
  final celular = dato(pedido.clienteCelular);
  final direccion = dato(pedido.direccionDelivery);
  final referencia = dato(pedido.referenciaDelivery);
  final esDelivery = pedido.tipoPedido == 'delivery';

  final s = StringBuffer()
    ..writeln('🚀 *PEDIDO: #${pedido.numeroPedido}* 🚀')
    ..writeln(_separadorWhatsapp)
    ..writeln('🏪 *${negocio.nombre}*')
    ..writeln('📅 ${_fechaHoraWhatsapp(pedido.fechaPedido)}');
  if (!esDelivery) s.writeln('🪑 *Atención:* ${pedido.ubicacion}');

  final cliente = [
    if (nombre.isNotEmpty) '*Nombre:* $nombre',
    if (celular.isNotEmpty) '📞 *Celular:* $celular',
    if (direccion.isNotEmpty) '📍 *Dirección:* $direccion',
    if (referencia.isNotEmpty) '🧭 *Referencia:* $referencia',
  ];
  if (cliente.isNotEmpty) {
    s
      ..writeln()
      ..writeln('👤 *CLIENTE*');
    cliente.forEach(s.writeln);
  }

  s
    ..writeln()
    ..writeln('🛒 *DETALLE*')
    ..writeln(_separadorWhatsapp);
  for (var i = 0; i < productos.length; i++) {
    final l = productos[i];
    if (i > 0) s.writeln();
    final nombreProducto = l.esLibre
        ? (l.nombreLibre ?? l.nombrePlato)
        : l.nombrePlato;
    s.writeln('🔸 *${l.cantidad}x $nombreProducto*');
    for (final d in detalleDeLinea(l)) {
      s.writeln('   └ $d');
    }
    s.writeln('   💵 ${soles(l.precioTotalLinea + l.descuentoAplicado)}');
  }
  s
    ..writeln(_separadorWhatsapp)
    ..writeln('💵 *IMPORTE*');
  void monto(String etiqueta, double v, {bool menos = false}) =>
      s.writeln('$etiqueta: ${menos ? '-' : ''}${soles(v.abs())}');
  monto('Subtotal', subtotal);
  if (descProductos > 0.001) monto('🎁 Descuento', descProductos, menos: true);
  if (descExtra.abs() > 0.001) {
    monto('🎁 Descuento extra', descExtra, menos: true);
  }
  if (devoluciones.abs() > 0.001) {
    monto('↩️ Ajustes por devolución', devoluciones);
  }
  if (cargo > 0.001) monto('🛵 Cargo por delivery', cargo);
  if (propina > 0.001) monto('🙏 Propina', propina);
  if (tupper > 0.001) monto('🥡 Táper', tupper);
  if (conRecargo) {
    monto('Total de la cuenta', total);
    monto(
      metodoPago.isEmpty
          ? '💳 Recargo por método de pago'
          : '💳 Recargo por pago con ${metodoPago.toLowerCase()}',
      recargo,
    );
  }
  s
    ..writeln()
    ..writeln(
      '🔥 *${conRecargo ? 'TOTAL A PAGAR' : 'TOTAL'}: ${soles(totalCobrado)}* 🔥',
    )
    ..writeln(_separadorWhatsapp);
  if (pagado > 0.001) {
    if (metodoPago.isNotEmpty) {
      s.writeln('💳 Pago: ${metodoPago.toUpperCase()}');
    }
    if (saldo > 0.01) {
      s
        ..writeln('Pagado: ${soles(pagado)}')
        ..writeln('⚠️ *Saldo pendiente: ${soles(saldo)}*');
    }
  } else {
    s.writeln('💳 Pago: PENDIENTE DE PAGO');
  }
  s
    ..writeln()
    ..write('🙌 ¡Gracias por tu compra!');
  return s.toString();
}

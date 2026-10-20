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

Uri urlWhatsapp(String numero, String mensaje) => Uri.https('wa.me', '/$numero', {
  'text': mensaje,
});

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

// Texto de la cuenta para WhatsApp. WhatsApp no usa letra de ancho fijo, así que
// no se arma en columnas como el ticket: una línea por producto y los totales
// debajo. [recargo] es lo que se cobra de más por el método de pago (tarjeta) y
// se suma al total que paga el cliente.
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
  final cliente = (pedido.clienteNombre ?? '').trim();

  final s = StringBuffer()
    ..writeln('*${negocio.nombre}*')
    ..writeln('Cuenta del pedido #${pedido.numeroPedido}')
    ..writeln('Atención: ${pedido.ubicacion}')
    ..writeln('Fecha: ${fechaHoraTicket(pedido.fechaPedido)}');
  if (cliente.isNotEmpty) s.writeln('Cliente: $cliente');
  s.writeln();
  for (final l in productos) {
    final nombre = l.esLibre ? (l.nombreLibre ?? l.nombrePlato) : l.nombrePlato;
    s.writeln(
      '${l.cantidad} x $nombre — ${soles(l.precioTotalLinea + l.descuentoAplicado)}',
    );
    for (final d in detalleDeLinea(l)) {
      s.writeln('   $d');
    }
  }
  s.writeln();
  void monto(String etiqueta, double v, {bool menos = false}) =>
      s.writeln('$etiqueta: ${menos ? '-' : ''}${soles(v.abs())}');
  monto('Subtotal', subtotal);
  if (descProductos > 0.001) monto('Descuento', descProductos, menos: true);
  if (descExtra.abs() > 0.001) monto('Descuento extra', descExtra, menos: true);
  if (devoluciones.abs() > 0.001) monto('Ajustes por devolución', devoluciones);
  if (cargo > 0.001) monto('Cargo por delivery', cargo);
  if (propina > 0.001) monto('Propina', propina);
  if (tupper > 0.001) monto('Táper', tupper);
  if (conRecargo) {
    monto('Total de la cuenta', total);
    monto(
      metodoPago.isEmpty
          ? 'Recargo por método de pago'
          : 'Recargo por pago con ${metodoPago.toLowerCase()}',
      recargo,
    );
  }
  s.writeln('*${conRecargo ? 'TOTAL A PAGAR' : 'TOTAL'}: ${soles(totalCobrado)}*');
  if (pagado > 0.001 && saldo > 0.01) {
    s
      ..writeln('Pagado: ${soles(pagado)}')
      ..writeln('*Saldo pendiente: ${soles(saldo)}*');
  }
  s
    ..writeln()
    ..write('¡Gracias por su visita!');
  return s.toString();
}

// Mensaje corto que acompaña a la imagen de la boleta, que se adjunta aparte.
String mensajeBoletaWhatsapp({
  required Pedido pedido,
  required List<PedidoLine> lineas,
  double recargo = 0,
}) {
  final total =
      lineas.fold(0.0, (s, l) => s + l.precioTotalLinea) +
      (recargo > 0.001 ? recargo : 0);
  return 'Hola, te enviamos la boleta del pedido #${pedido.numeroPedido} de '
      '${negocio.nombre}. Total: ${soles(total)}. ¡Gracias por su visita!';
}

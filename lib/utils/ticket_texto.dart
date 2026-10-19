import '../data/pedidos_store.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import 'monto_letras.dart';
import 'nota_pedido.dart';

// Texto de los tickets, pensado para una ticketera térmica de 80 mm: 48
// columnas, solo negro sobre blanco (nada de colores ni imágenes). Es el mismo
// formato que imprime el servidor; aquí se arma para mostrarlo en pantalla.

const anchoTicket = 48;
// Con letra doble (el doble de ancho) caben la mitad de columnas.
const anchoTicketDoble = anchoTicket ~/ 2;

enum AlineacionTicket { izquierda, centro, derecha }

class LineaTicket {
  final String texto;
  final AlineacionTicket alineacion;
  final bool negrita;
  // Doble ancho y doble alto, como los títulos de la ticketera.
  final bool doble;
  // Si no es null, esta línea es un código QR con estos datos (sin texto).
  final String? qr;

  const LineaTicket(
    this.texto, {
    this.alineacion = AlineacionTicket.izquierda,
    this.negrita = false,
    this.doble = false,
    this.qr,
  });

  const LineaTicket.codigoQr(String datos)
    : texto = '',
      alineacion = AlineacionTicket.centro,
      negrita = false,
      doble = false,
      qr = datos;

  const LineaTicket.centro(
    this.texto, {
    this.negrita = false,
    this.doble = false,
  }) : alineacion = AlineacionTicket.centro,
       qr = null;

  const LineaTicket.derecha(
    this.texto, {
    this.negrita = false,
    this.doble = false,
  }) : alineacion = AlineacionTicket.derecha,
       qr = null;

  static const LineaTicket vacia = LineaTicket('');

  static LineaTicket separador([String c = '-']) =>
      LineaTicket(c * anchoTicket);
}

// "izq ........ der" en [ancho] columnas; si no cabe, se recorta la izquierda.
String padLinea(String izq, String der, [int ancho = anchoTicket]) {
  final maxIzq = ancho - der.length - 1;
  final i = izq.length > maxIzq && maxIzq > 0 ? izq.substring(0, maxIzq) : izq;
  final espacios = ancho - i.length - der.length;
  return '$i${' ' * (espacios < 1 ? 1 : espacios)}$der';
}

// Parte [texto] en renglones de a lo más [ancho] columnas, sin cortar palabras
// (salvo las que no caben solas). Los renglones que continúan llevan [sangria]
// (y ya cuentan dentro del ancho).
List<String> envolver(String texto, int ancho, {String sangria = ''}) {
  final lineas = <String>[];
  var actual = '';
  int cupo() {
    final c = lineas.isEmpty ? ancho : ancho - sangria.length;
    return c < 1 ? 1 : c;
  }

  void cerrar() {
    if (actual.isNotEmpty) {
      lineas.add(actual);
      actual = '';
    }
  }

  for (final parrafo in texto.split('\n')) {
    for (var palabra in parrafo.split(RegExp(r'\s+'))) {
      if (palabra.isEmpty) continue;
      while (palabra.length > cupo()) {
        if (actual.isNotEmpty) {
          cerrar();
        } else {
          final c = cupo();
          lineas.add(palabra.substring(0, c));
          palabra = palabra.substring(c);
        }
      }
      if (actual.isEmpty) {
        actual = palabra;
      } else if (actual.length + 1 + palabra.length <= cupo()) {
        actual = '$actual $palabra';
      } else {
        cerrar();
        actual = palabra;
      }
    }
    cerrar();
  }
  return [
    for (var i = 0; i < lineas.length; i++)
      i == 0 ? lineas[i] : '$sangria${lineas[i]}',
  ];
}

String _dosDigitos(int n) => n.toString().padLeft(2, '0');

String fechaHoraTicket(DateTime d) =>
    '${_dosDigitos(d.day)}/${_dosDigitos(d.month)}/${d.year} '
    '${_dosDigitos(d.hour)}:${_dosDigitos(d.minute)}:${_dosDigitos(d.second)}';

String soles(double v) => 'S/ ${v.toStringAsFixed(2)}';

// Detalle de un producto debajo de su nombre: tamaño, presentación, componentes
// del combo, extras y nota.
List<String> _detalleDeLinea(PedidoLine l) => [
  if (l.variante != null) 'Variante: ${l.variante!.nombre}',
  if (l.presentacion != null)
    'Presentacion: ${l.presentacion!.unidad.unidadPresentacion} '
        '${l.presentacion!.volumenMl}ml',
  for (final e in l.componentes)
    '+ ${e.cantidad > 1 ? '${e.cantidad} x ' : ''}${e.nombre}'
        '${e.esCambio ? ' (cambio)' : ''}',
  for (final m in l.modificadores)
    '${m.tipo == 'quitar' ? '- Sin' : '+'} ${m.nombre}',
];

String _lugarComanda(Pedido p) {
  switch (p.tipoPedido) {
    case 'delivery':
      return 'TIPO: >> DELIVERY <<';
    case 'llevar':
      return 'TIPO: >> PARA LLEVAR <<';
    default:
      final n = p.todasLasMesas.where((n) => n != 0);
      return n.isEmpty
          ? 'MESA: SALON'
          : 'MESA: ${n.map((x) => x.toString().padLeft(2, '0')).join(' + ')}  (SALON)';
  }
}

// Comanda de cocina: sin precios ni totales. Con [reimpresion] lleva el rótulo
// de reimpresión.
List<LineaTicket> ticketComanda({
  required Pedido pedido,
  required List<PedidoLine> lineas,
  required String mozo,
  bool reimpresion = false,
}) {
  final productos = [
    for (final l in lineas)
      if (esLineaDeProducto(l) && !esLineaPropina(l) && !esLineaTupper(l))
        if (!esLineaTaper(l)) l,
  ];
  final nota = notaGeneralDe(pedido.notas);
  final salida = <LineaTicket>[
    LineaTicket.centro(
      reimpresion ? '*** REIMPRESION ***' : '*** COMANDA COCINA ***',
      negrita: true,
    ),
    LineaTicket.centro('ORDEN #${pedido.numeroPedido}', doble: true),
    LineaTicket.separador('-'),
    LineaTicket(_lugarComanda(pedido), negrita: true, doble: true),
    LineaTicket('Mozo: $mozo'),
    LineaTicket('Fecha: ${fechaHoraTicket(pedido.fechaPedido)}'),
    if (nota != null)
      for (final r in envolver('NOTA PEDIDO: $nota', anchoTicket))
        LineaTicket(r, negrita: true),
    LineaTicket.separador('='),
    LineaTicket(padLinea('CANT  DESCRIPCION', 'MODALIDAD'), negrita: true),
    LineaTicket.separador('-'),
  ];
  for (final l in productos) {
    final nombre = l.esLibre ? (l.nombreLibre ?? l.nombrePlato) : l.nombrePlato;
    for (final r in envolver(
      '[${l.cantidad}x] $nombre',
      anchoTicketDoble,
      sangria: '     ',
    )) {
      salida.add(LineaTicket(r, negrita: true, doble: true));
    }
    // Igual que el servidor: cada producto para llevar lo lleva marcado.
    if (l.tipoEntrega == 'llevar') {
      salida.add(
        const LineaTicket('      > [PARA LLEVAR / TAPER] <', negrita: true),
      );
    }
    for (final d in _detalleDeLinea(l)) {
      for (final r in envolver(d, anchoTicket - 6, sangria: '  ')) {
        salida.add(LineaTicket('      $r'));
      }
    }
    if ((l.comentario ?? '').trim().isNotEmpty) {
      for (final r in envolver(
        '* NOTA: ${l.comentario!.trim()}',
        anchoTicket - 6,
        sangria: '  ',
      )) {
        salida.add(LineaTicket('      $r', negrita: true));
      }
    }
    salida.add(LineaTicket.vacia);
  }
  salida
    ..add(LineaTicket.separador('='))
    ..add(const LineaTicket.centro('--- Fin de Comanda ---'));
  return salida;
}

// Datos de la sede que van arriba de la boleta.
typedef DatosSede = ({String direccion, String telefono, String ruc});

// Parte alta de la boleta: ubicación, teléfono y el título con su número. El
// logo lo pone quien dibuja el ticket.
List<LineaTicket> _cabeceraBoleta(DatosSede sede, String numero) => [
  for (final r in envolver(sede.direccion, anchoTicket)) LineaTicket.centro(r),
  if (sede.telefono.isNotEmpty) LineaTicket.centro('Tel. ${sede.telefono}'),
  LineaTicket.separador('-'),
  const LineaTicket.centro('BOLETA DE VENTA ELECTRONICA', negrita: true),
  LineaTicket.centro(numero, negrita: true, doble: true),
  LineaTicket.separador('-'),
];

// Parte baja: "SON", QR, con qué se pagó y el pie de la representación impresa.
List<LineaTicket> _pieBoleta({
  required double total,
  required String datosQr,
  required List<String> pagoCon,
}) => [
  LineaTicket.separador('-'),
  for (final r in envolver('SON: ${montoEnLetras(total)}', anchoTicket))
    LineaTicket(r, negrita: true),
  LineaTicket.vacia,
  LineaTicket.codigoQr(datosQr),
  LineaTicket.vacia,
  for (final l in pagoCon) LineaTicket(l),
  LineaTicket.separador('-'),
  const LineaTicket.centro('REPRESENTACION IMPRESA DE LA'),
  const LineaTicket.centro('BOLETA DE VENTA ELECTRONICA'),
];

// Texto del QR. Por ahora es solo visual: más adelante el QR se enlazará con la
// SUNAT (facturación electrónica) y aquí irán sus datos. Mientras tanto lleva un
// texto neutro, que no imita el formato de la SUNAT para que no se confunda con
// uno válido.
String _datosQr(DatosSede sede, String numero, double total, DateTime fecha) =>
    'BOLETA-$numero';

// Boleta de venta electrónica del pedido: logo (lo pone la pantalla), ubicación
// y teléfono de la sede, título con el número, datos de la venta, productos,
// resumen del pago, "SON", QR y con qué se pagó. [pagado] es lo ya cobrado de
// la cuenta y [recargo] lo que se cobró de más por el método de pago (p. ej. la
// tarjeta): se suma al total que paga el cliente.
List<LineaTicket> ticketBoleta({
  required Pedido pedido,
  required List<PedidoLine> lineas,
  required String mozo,
  required DatosSede sede,
  String metodoPago = '',
  double pagado = 0,
  double recargo = 0,
}) {
  final productos = [
    for (final l in lineas)
      if (esLineaDeProducto(l)) l,
  ];
  double suma(Iterable<PedidoLine> ls) =>
      ls.fold(0.0, (s, l) => s + l.precioTotalLinea);
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
  final saldo = total - pagado;
  final conRecargo = recargo > 0.001;
  // Lo que paga el cliente: la cuenta más el recargo.
  final totalCobrado = total + (conRecargo ? recargo : 0);
  final numero = pedido.numeroPedido;
  final cliente = (pedido.clienteNombre ?? '').trim();

  final salida = <LineaTicket>[
    ..._cabeceraBoleta(sede, numero),
    LineaTicket('Fecha de emision: ${fechaHoraTicket(pedido.fechaPedido)}'),
    LineaTicket(
      'Forma de pago: ${metodoPago.isEmpty ? 'Pendiente de pago' : metodoPago}',
    ),
    LineaTicket('Cliente: ${cliente.isEmpty ? 'CLIENTES VARIOS' : cliente}'),
    LineaTicket('Atendido por: $mozo'),
    LineaTicket('Atencion: ${pedido.ubicacion}'),
    LineaTicket.separador('='),
    LineaTicket(padLinea('CANT DESCRIPCION', 'TOTAL'), negrita: true),
    LineaTicket.separador('-'),
  ];
  for (final l in productos) {
    final nombre = l.esLibre ? (l.nombreLibre ?? l.nombrePlato) : l.nombrePlato;
    final importe = soles(l.precioTotalLinea + l.descuentoAplicado);
    final cab = '${l.cantidad.toString().padLeft(2)}x ';
    final espacio = anchoTicket - cab.length - importe.length - 1;
    final partes = envolver(nombre, espacio, sangria: '    ');
    salida.add(LineaTicket(padLinea('$cab${partes.first}', importe)));
    for (final r in partes.skip(1)) {
      salida.add(LineaTicket(r));
    }
    for (final d in _detalleDeLinea(l)) {
      for (final r in envolver(d, anchoTicket - 4, sangria: '  ')) {
        salida.add(LineaTicket('    $r'));
      }
    }
  }
  salida.add(LineaTicket.separador('='));
  LineaTicket montoLinea(String etiqueta, double v, {bool menos = false}) =>
      LineaTicket(padLinea(etiqueta, '${menos ? '-' : ''}${soles(v.abs())}'));
  salida.add(montoLinea('SUBTOTAL', subtotal));
  if (descProductos > 0.001) {
    salida.add(montoLinea('DESCUENTO', descProductos, menos: true));
  }
  if (descExtra.abs() > 0.001) {
    salida.add(montoLinea('DESCUENTO EXTRA', descExtra, menos: true));
  }
  if (devoluciones.abs() > 0.001) {
    salida.add(montoLinea('AJUSTES POR DEVOLUCION', devoluciones));
  }
  if (cargo > 0.001) salida.add(montoLinea('CARGO POR DELIVERY', cargo));
  if (propina > 0.001) salida.add(montoLinea('PROPINA', propina));
  if (tupper > 0.001) salida.add(montoLinea('TAPER', tupper));
  salida.add(LineaTicket.separador('-'));
  if (conRecargo) {
    salida.add(montoLinea('TOTAL CUENTA', total));
    salida.add(
      montoLinea(
        metodoPago.isEmpty
            ? 'RECARGO POR METODO DE PAGO'
            : 'RECARGO POR PAGO CON ${metodoPago.toUpperCase()}',
        recargo,
      ),
    );
  }
  salida.add(
    LineaTicket.derecha(
      '${conRecargo ? 'TOTAL A PAGAR' : 'TOTAL'}: ${soles(totalCobrado)}',
      negrita: true,
      doble: true,
    ),
  );
  if (pagado > 0.001 && saldo > 0.01) {
    salida.add(LineaTicket(padLinea('PAGADO', soles(pagado))));
    salida.add(
      LineaTicket(padLinea('SALDO PENDIENTE', soles(saldo)), negrita: true),
    );
  }
  salida.addAll(
    _pieBoleta(
      total: totalCobrado,
      datosQr: _datosQr(sede, numero, totalCobrado, pedido.fechaPedido),
      pagoCon: [
        if (pagado > 0.001)
          'PAGO CON: ${metodoPago.isEmpty ? 'EFECTIVO' : metodoPago.toUpperCase()}'
              ' ${soles(pagado + (conRecargo ? recargo : 0))}'
        else
          'PAGO CON: --',
      ],
    ),
  );
  return salida;
}

// Boleta de un pagador (pago compartido): su parte y con qué pagó.
List<LineaTicket> ticketPagador({
  required Pedido pedido,
  required String pagador,
  required List<({String descripcion, double monto})> items,
  required double total,
  required List<({String medio, double monto})> pagos,
  required DatosSede sede,
  // Recargo por el método de pago (p. ej. tarjeta), que se suma a su total.
  double recargo = 0,
}) {
  final conRecargo = recargo > 0.001;
  final totalCobrado = total + (conRecargo ? recargo : 0);
  final numero = pedido.numeroPedido;
  final salida = <LineaTicket>[
    ..._cabeceraBoleta(sede, numero),
    LineaTicket('Fecha de emision: ${fechaHoraTicket(pedido.fechaPedido)}'),
    LineaTicket(
      'Forma de pago: ${pagos.isEmpty ? 'Pendiente de pago' : pagos.map((p) => p.medio).toSet().join(', ')}',
    ),
    LineaTicket('Cliente: $pagador'),
    LineaTicket('Atencion: ${pedido.ubicacion}'),
    LineaTicket.separador('='),
    LineaTicket(padLinea('DESCRIPCION', 'TOTAL'), negrita: true),
    LineaTicket.separador('-'),
  ];
  for (final it in items) {
    final importe = soles(it.monto);
    final partes = envolver(it.descripcion, anchoTicket - importe.length - 1);
    salida.add(LineaTicket(padLinea(partes.first, importe)));
    for (final r in partes.skip(1)) {
      salida.add(LineaTicket(r));
    }
  }
  salida.add(LineaTicket.separador('='));
  if (conRecargo) {
    salida
      ..add(LineaTicket(padLinea('TOTAL CUENTA', soles(total))))
      ..add(
        LineaTicket(padLinea('RECARGO POR METODO DE PAGO', soles(recargo))),
      );
  }
  salida.add(
    LineaTicket.derecha(
      '${conRecargo ? 'TOTAL A PAGAR' : 'TOTAL'}: ${soles(totalCobrado)}',
      negrita: true,
      doble: true,
    ),
  );
  salida.addAll(
    _pieBoleta(
      total: totalCobrado,
      datosQr: _datosQr(sede, numero, totalCobrado, pedido.fechaPedido),
      pagoCon: [
        for (final p in pagos)
          'PAGO CON: ${p.medio.toUpperCase()} ${soles(p.monto)}',
        if (pagos.isEmpty) 'PAGO CON: --',
      ],
    ),
  );
  return salida;
}

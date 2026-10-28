import '../data/cliente_comprobante_store.dart';
import '../data/mesas_store.dart';
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
List<String> detalleDeLinea(PedidoLine l) => [
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
      final numMesa = n.isNotEmpty ? n.first : 0;
      final mesaObj = mesas.where((m) => m.numero == numMesa).firstOrNull;
      final zonaStr = (mesaObj != null && mesaObj.zona.trim().isNotEmpty)
          ? mesaObj.zona.trim().toUpperCase()
          : 'SALÓN';
      return n.isEmpty
          ? 'MESA: $zonaStr'
          : 'MESA: ${n.map((x) => x.toString().padLeft(2, '0')).join(' + ')}  ($zonaStr)';
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
    for (final d in detalleDeLinea(l)) {
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
  const LineaTicket.centro('CUENTA DE CONSUMO', negrita: true),
  const LineaTicket.centro('No es comprobante de pago'),
  LineaTicket.centro(numero, negrita: true, doble: true),
  LineaTicket.separador('-'),
];

// Parte baja: "SON", con qué se pagó y la aclaración de que no es un
// comprobante. La boleta o factura electrónica válida la emite el sistema de
// facturación; esta cuenta es solo el detalle de lo consumido.
List<LineaTicket> _pieBoleta({
  required double total,
  required List<String> pagoCon,
}) => [
  LineaTicket.separador('-'),
  for (final r in envolver('SON: ${montoEnLetras(total)}', anchoTicket))
    LineaTicket(r, negrita: true),
  LineaTicket.vacia,
  for (final l in pagoCon) LineaTicket(l),
  LineaTicket.separador('-'),
  const LineaTicket.centro('DOCUMENTO SIN VALIDEZ TRIBUTARIA'),
  const LineaTicket.centro('Pida su boleta o factura en caja'),
];

// Cuenta de consumo del pedido: logo (lo pone la pantalla), ubicación
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
  // Lo cobrado por cada medio (con su nombre, por ejemplo cada Yape): si viene,
  // el ticket lista todos los medios con su monto.
  List<({String medio, double monto})> pagos = const [],
  double pagado = 0,
  double recargo = 0,
  // Efectivo que entregó el cliente y vuelto que se le dio (0 si pagó justo).
  double recibido = 0,
  double vuelto = 0,
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
  final cargoLinea = suma(
    lineas.where((l) => l.cartaId == cartaIdCargoDelivery),
  );
  final cargo = cargoLinea > 0.001 ? cargoLinea : pedido.costoDelivery;
  final deliverySuma = cargoLinea <= 0.001 ? cargo : 0.0;
  final propina = suma(lineas.where(esLineaPropina));
  final tupper = suma(lineas.where(esLineaTupper));
  final devoluciones = suma(lineas.where(esAjusteDeDevolucion));
  final total = suma(lineas) + deliverySuma;
  final saldo = total - pagado;
  final conRecargo = recargo > 0.001;
  // Lo que paga el cliente: la cuenta más el recargo.
  final totalCobrado = total + (conRecargo ? recargo : 0);
  final numero = pedido.numeroPedido;
  // El nombre del pedido o, si no tiene, el del cliente al que se emitió la
  // boleta o la factura.
  final cliente = (pedido.clienteNombre ?? '').trim().isNotEmpty
      ? pedido.clienteNombre!.trim()
      : (etiquetaClienteDeComprobante(pedido.id) ?? '');

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
    for (final d in detalleDeLinea(l)) {
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
  if (vuelto > 0.001 && recibido > 0.001) {
    salida
      ..add(LineaTicket(padLinea('EFECTIVO RECIBIDO', soles(recibido))))
      ..add(LineaTicket(padLinea('VUELTO', soles(vuelto)), negrita: true));
  }
  salida.addAll(
    _pieBoleta(
      total: totalCobrado,
      pagoCon: [
        if (pagado > 0.001 && pagos.isNotEmpty)
          for (final p in pagos)
            'PAGO CON: ${p.medio.toUpperCase()} ${soles(p.monto)}'
        else if (pagado > 0.001)
          'PAGO CON: ${metodoPago.isEmpty ? 'EFECTIVO' : metodoPago.toUpperCase()}'
              ' ${soles(pagado + (conRecargo ? recargo : 0))}'
        else
          'PAGO CON: --',
      ],
    ),
  );
  return salida;
}

// Vista previa del ticket de venta, la boleta o la factura de un pedido
// ([tipo]: 'ticket_venta', 'boleta' o 'factura'): el detalle de la cuenta con el
// título del documento, los datos del cliente y, en boleta y factura, el
// desglose del IGV. La serie, el número y el código QR los asigna el sistema al
// emitir, por eso aquí van como marcas.
List<LineaTicket> ticketComprobante({
  required String tipo,
  required Pedido pedido,
  required List<PedidoLine> lineas,
  required String mozo,
  required DatosSede sede,
  String metodoPago = '',
  List<({String medio, double monto})> pagos = const [],
  double pagado = 0,
  double recargo = 0,
  double recibido = 0,
  double vuelto = 0,
  // Datos del cliente (DNI o RUC y su nombre); si faltan, van como marcas.
  String? documentoCliente,
  String? denominacionCliente,
  String? direccionCliente,
}) {
  final base = ticketBoleta(
    pedido: pedido,
    lineas: lineas,
    mozo: mozo,
    sede: sede,
    metodoPago: metodoPago,
    pagos: pagos,
    pagado: pagado,
    recargo: recargo,
    recibido: recibido,
    vuelto: vuelto,
  );
  final esFactura = tipo == 'factura';
  final esBoleta = tipo == 'boleta';
  final titulo = esFactura
      ? 'FACTURA ELECTRONICA'
      : (esBoleta ? 'BOLETA DE VENTA ELECTRONICA' : 'TICKET DE VENTA');
  final serie = esFactura
      ? 'F###-########'
      : (esBoleta ? 'B###-########' : 'T###-########');
  final total =
      lineas.fold(0.0, (s, l) => s + l.precioTotalLinea) +
      (recargo > 0.001 ? recargo : 0);
  final gravada = total / 1.18;
  final igv = total - gravada;
  String doc(String? v, String vacio) =>
      (v == null || v.trim().isEmpty) ? vacio : v.trim();

  final salida = <LineaTicket>[];
  for (final l in base) {
    final x = l.texto;
    if (x == 'CUENTA DE CONSUMO') {
      salida.add(LineaTicket.centro(titulo, negrita: true));
    } else if (x == 'No es comprobante de pago') {
      salida.add(
        LineaTicket.centro(
          esFactura || esBoleta
              ? 'VISTA PREVIA'
              : 'Documento interno, sin validez tributaria',
        ),
      );
    } else if (x == pedido.numeroPedido && l.doble) {
      // El número de orden se cambia por la serie y el número del documento.
      salida.add(LineaTicket.centro(serie, negrita: true, doble: true));
    } else if (x.startsWith('Cliente: ')) {
      if (esFactura) {
        salida
          ..add(
            LineaTicket('RUC: ${doc(documentoCliente, '(se pide al emitir)')}'),
          )
          ..add(
            LineaTicket(
              'Razon social: ${doc(denominacionCliente, '(se pide al emitir)')}',
            ),
          );
        if (direccionCliente != null && direccionCliente.trim().isNotEmpty) {
          salida.add(LineaTicket('Direccion: ${direccionCliente.trim()}'));
        }
      } else if (esBoleta) {
        salida
          ..add(
            LineaTicket(
              'Cliente: ${doc(denominacionCliente, 'CLIENTES VARIOS')}',
            ),
          )
          ..add(LineaTicket('DNI: ${doc(documentoCliente, '00000000')}'));
      } else {
        salida.add(l);
      }
    } else if (x == 'DOCUMENTO SIN VALIDEZ TRIBUTARIA') {
      salida.add(
        LineaTicket.centro(
          esFactura || esBoleta
              ? 'Representacion impresa de la ${esFactura ? 'factura' : 'boleta'} electronica'
              : 'DOCUMENTO INTERNO SIN VALIDEZ TRIBUTARIA',
        ),
      );
    } else if (x == 'Pida su boleta o factura en caja') {
      salida.add(
        LineaTicket.centro(
          esFactura || esBoleta
              ? 'Consulte su comprobante en la SUNAT'
              : 'Pida su boleta o factura en caja',
        ),
      );
    } else if ((esFactura || esBoleta) && x.startsWith('TOTAL') && l.doble) {
      // Antes del total: base imponible e IGV.
      salida
        ..add(LineaTicket(padLinea('OP. GRAVADA', soles(gravada))))
        ..add(LineaTicket(padLinea('IGV (18%)', soles(igv))))
        ..add(l);
    } else {
      salida.add(l);
    }
  }
  // Boleta y factura llevan el código QR de SUNAT, que se genera al emitir.
  if (esFactura || esBoleta) {
    final i = salida.lastIndexWhere(
      (l) => l.texto.startsWith('Representacion'),
    );
    if (i > 0) {
      salida.insert(i, const LineaTicket.centro('[ CODIGO QR AL EMITIR ]'));
    }
  }
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
  // Efectivo que entregó y vuelto que se le dio (0 si pagó justo).
  double recibido = 0,
  double vuelto = 0,
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
  if (vuelto > 0.001 && recibido > 0.001) {
    salida
      ..add(LineaTicket(padLinea('EFECTIVO RECIBIDO', soles(recibido))))
      ..add(LineaTicket(padLinea('VUELTO', soles(vuelto)), negrita: true));
  }
  salida.addAll(
    _pieBoleta(
      total: totalCobrado,
      pagoCon: [
        for (final p in pagos)
          'PAGO CON: ${p.medio.toUpperCase()} ${soles(p.monto)}',
        if (pagos.isEmpty) 'PAGO CON: --',
      ],
    ),
  );
  return salida;
}

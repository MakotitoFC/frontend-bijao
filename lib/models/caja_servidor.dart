import '../data/movimientos_caja_store.dart';
import '../utils/json_num.dart';

// Apertura de caja de un turno (`apertura_caja`): el efectivo con el que se
// empieza.
class AperturaCaja {
  final String id;
  final double montoInicial;
  final DateTime fechaApertura;
  final String? usuarioNombre;
  final String? notas;

  const AperturaCaja({
    required this.id,
    required this.montoInicial,
    required this.fechaApertura,
    this.usuarioNombre,
    this.notas,
  });

  factory AperturaCaja.fromJson(Map<String, dynamic> json) => AperturaCaja(
    id: json['id']?.toString() ?? '',
    montoInicial: jsonDouble(json['monto_inicial']) ?? 0,
    fechaApertura:
        DateTime.tryParse(json['fecha_apertura']?.toString() ?? '')
            ?.toLocal() ??
        DateTime.now(),
    usuarioNombre: json['usuario_nombre']?.toString(),
    notas: json['notas']?.toString(),
  );
}

// Totales de la caja actual como los calcula el servidor
// (`GET /caja/totales-actual`): ventas, ingresos y salidas por medio de pago y
// el efectivo que debería haber.
class TotalesCajaServidor {
  final DateTime fechaInicio;
  final double montoInicial;
  // Ventas cobradas (cuenta más recargo) de todos los medios.
  final double ventas;
  final double delivery;
  final double ingresosEfectivo;
  final double salidasEfectivo;
  // Incluye el monto inicial de la apertura.
  final double efectivoEsperado;
  // Lo que debería haber en tarjeta y en digital (Yape y Plin), ya con los
  // ingresos y salidas de cada medio.
  final double tarjeta;
  final double digital;
  final double totalRecargos;
  final int numPedidos;
  final String? aperturaId;
  final List<FilaResumenMedio> porMedio;

  const TotalesCajaServidor({
    required this.fechaInicio,
    required this.montoInicial,
    required this.ventas,
    required this.delivery,
    required this.ingresosEfectivo,
    required this.salidasEfectivo,
    required this.efectivoEsperado,
    required this.tarjeta,
    required this.digital,
    required this.totalRecargos,
    required this.numPedidos,
    required this.aperturaId,
    required this.porMedio,
  });

  double get ingresos => porMedio.fold(0.0, (s, f) => s + f.ingresos);
  double get salidas => porMedio.fold(0.0, (s, f) => s + f.egresos);

  factory TotalesCajaServidor.fromJson(Map<String, dynamic> json) {
    double n(String k) => jsonDouble(json[k]) ?? 0;
    return TotalesCajaServidor(
      fechaInicio:
          DateTime.tryParse(json['fecha_inicio']?.toString() ?? '')
              ?.toLocal() ??
          DateTime.now(),
      montoInicial: n('monto_inicial'),
      ventas: n('general'),
      delivery: n('delivery'),
      ingresosEfectivo: n('ingresos_efectivo'),
      salidasEfectivo: n('salidas_efectivo'),
      efectivoEsperado: n('efectivo_esperado_en_caja'),
      tarjeta: json['tarjeta_esperada'] != null
          ? n('tarjeta_esperada')
          : n('tarjeta'),
      digital: json['digital_esperado'] != null
          ? n('digital_esperado')
          : n('yape') + n('plin'),
      totalRecargos: n('total_recargos'),
      numPedidos: (json['num_pedidos'] as num?)?.toInt() ?? 0,
      aperturaId: json['apertura_id']?.toString(),
      porMedio: [
        for (final m in (json['por_medio_pago'] as List? ?? const []))
          if (m is Map<String, dynamic>)
            FilaResumenMedio(
              m['medio_pago_nombre']?.toString() ?? '',
              grupoServidor: m['grupo']?.toString(),
              ventas: jsonDouble(m['ventas']) ?? 0,
              ingresos: jsonDouble(m['ingresos']) ?? 0,
              egresos: jsonDouble(m['salidas']) ?? 0,
            ),
      ],
    );
  }
}

// Estado de la caja del turno (`GET /caja/estado-actual`).
class EstadoCaja {
  final bool abierta;
  final AperturaCaja? apertura;
  final TotalesCajaServidor? totales;

  const EstadoCaja({required this.abierta, this.apertura, this.totales});

  factory EstadoCaja.fromJson(Map<String, dynamic> json) => EstadoCaja(
    abierta: json['estado']?.toString() == 'abierta',
    apertura: json['apertura'] is Map<String, dynamic>
        ? AperturaCaja.fromJson(json['apertura'] as Map<String, dynamic>)
        : null,
    totales: json['totales'] is Map<String, dynamic>
        ? TotalesCajaServidor.fromJson(json['totales'] as Map<String, dynamic>)
        : null,
  );
}

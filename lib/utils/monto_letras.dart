// Monto en letras como en las boletas del Perú: "SON: CIENTO VEINTE CON 50/100
// SOLES".

const _unidades = [
  'CERO',
  'UNO',
  'DOS',
  'TRES',
  'CUATRO',
  'CINCO',
  'SEIS',
  'SIETE',
  'OCHO',
  'NUEVE',
  'DIEZ',
  'ONCE',
  'DOCE',
  'TRECE',
  'CATORCE',
  'QUINCE',
  'DIECISEIS',
  'DIECISIETE',
  'DIECIOCHO',
  'DIECINUEVE',
  'VEINTE',
  'VEINTIUNO',
  'VEINTIDOS',
  'VEINTITRES',
  'VEINTICUATRO',
  'VEINTICINCO',
  'VEINTISEIS',
  'VEINTISIETE',
  'VEINTIOCHO',
  'VEINTINUEVE',
];

const _decenas = [
  '',
  '',
  '',
  'TREINTA',
  'CUARENTA',
  'CINCUENTA',
  'SESENTA',
  'SETENTA',
  'OCHENTA',
  'NOVENTA',
];

const _centenas = [
  '',
  'CIENTO',
  'DOSCIENTOS',
  'TRESCIENTOS',
  'CUATROCIENTOS',
  'QUINIENTOS',
  'SEISCIENTOS',
  'SETECIENTOS',
  'OCHOCIENTOS',
  'NOVECIENTOS',
];

// 0 a 999.
String _hastaMil(int n) {
  if (n == 100) return 'CIEN';
  final c = n ~/ 100;
  final r = n % 100;
  final partes = <String>[];
  if (c > 0) partes.add(_centenas[c]);
  if (r > 0) {
    if (r < 30) {
      partes.add(_unidades[r]);
    } else {
      final d = r ~/ 10;
      final u = r % 10;
      partes.add(u == 0 ? _decenas[d] : '${_decenas[d]} Y ${_unidades[u]}');
    }
  }
  return partes.join(' ');
}

// Entero en letras (hasta 999 999 999).
String enteroEnLetras(int n) {
  if (n == 0) return 'CERO';
  final millones = n ~/ 1000000;
  final miles = (n % 1000000) ~/ 1000;
  final resto = n % 1000;
  final partes = <String>[];
  if (millones > 0) {
    partes.add(
      millones == 1
          ? 'UN MILLON'
          : '${_aprefijo(enteroEnLetras(millones))} MILLONES',
    );
  }
  if (miles > 0) {
    partes.add(miles == 1 ? 'MIL' : '${_aprefijo(_hastaMil(miles))} MIL');
  }
  if (resto > 0) partes.add(_hastaMil(resto));
  return partes.join(' ');
}

// "UNO" -> "UN" delante de MIL ("VEINTIUN MIL").
String _aprefijo(String t) =>
    t.endsWith('UNO') ? '${t.substring(0, t.length - 3)}UN' : t;

// "CINCUENTA Y SEIS CON 00/100 SOLES".
String montoEnLetras(double monto) {
  final centimosTotales = (monto.abs() * 100).round();
  final soles = centimosTotales ~/ 100;
  final centimos = centimosTotales % 100;
  final enLetras = soles == 0 ? 'CERO' : enteroEnLetras(soles);
  return '$enLetras CON ${centimos.toString().padLeft(2, '0')}/100 SOLES';
}

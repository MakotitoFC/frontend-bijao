import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'reporte_inventario.dart';

// El reporte de inventario de un día como PDF (A4): cifras del día, resumen por
// producto y detalle de los movimientos. Usa las letras estándar del PDF, que
// cubren el español (tildes, ñ, ¿, ¡); cualquier otro símbolo se cambia por "?".

const _dias = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];
const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

// "jueves 12 de noviembre de 2026".
String fechaLarga(DateTime d) =>
    '${_dias[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]} de ${d.year}';

String _dos(int n) => n.toString().padLeft(2, '0');

String _numero(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

// Solo letras que el PDF estándar sabe dibujar (hasta Latin-1).
String _limpio(String texto) {
  final b = StringBuffer();
  for (final c in texto.runes) {
    if (c == 0x0A || c == 0x0D || c == 0x09) {
      b.write(' ');
    } else if (c < 0x20) {
      continue;
    } else if (c <= 0xFF) {
      b.writeCharCode(c);
    } else {
      b.write('?');
    }
  }
  return b.toString();
}

const _verde = PdfColor.fromInt(0xFF0EAB7B);
const _gris = PdfColor.fromInt(0xFF6B7280);
const _grisClaro = PdfColor.fromInt(0xFFE5E7EB);
const _fondo = PdfColor.fromInt(0xFFF3F4F6);

// [unidadDe] da el nombre de la unidad de un producto. [generado] es la hora
// que se imprime como "Generado el…" (por defecto, ahora).
Future<Uint8List> reporteInventarioPdf(
  ReporteInventarioDia r, {
  required String Function(String unidadId) unidadDe,
  String negocio = 'El Bijao Restaurant',
  DateTime? generado,
}) async {
  final ahora = generado ?? DateTime.now();
  final doc = pw.Document(
    title: 'Reporte de inventario ${fechaIso(r.dia)}',
    author: negocio,
  );

  pw.Widget cifra(String titulo, String valor) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _fondo,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _limpio(titulo),
            style: const pw.TextStyle(fontSize: 9, color: _gris),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            _limpio(valor),
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    ),
  );

  pw.Widget titulo(String texto) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
    child: pw.Text(
      _limpio(texto),
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: _verde,
      ),
    ),
  );

  pw.Widget tabla(
    pw.Context ctx, {
    required List<String> encabezados,
    required List<List<String>> filas,
    required Map<int, pw.TableColumnWidth> anchos,
    required Map<int, pw.Alignment> alineacion,
  }) => pw.TableHelper.fromTextArray(
    context: ctx,
    headers: [for (final h in encabezados) _limpio(h)],
    data: [
      for (final f in filas) [for (final c in f) _limpio(c)],
    ],
    columnWidths: anchos,
    cellAlignments: alineacion,
    headerAlignments: alineacion,
    headerStyle: pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    ),
    headerDecoration: const pw.BoxDecoration(color: _verde),
    cellStyle: const pw.TextStyle(fontSize: 9),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _grisClaro, width: 0.5),
      bottom: pw.BorderSide(color: _grisClaro, width: 0.5),
    ),
    oddRowDecoration: const pw.BoxDecoration(color: _fondo),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              _limpio(
                'Generado el ${_dos(ahora.day)}/${_dos(ahora.month)}/'
                '${ahora.year} ${_dos(ahora.hour)}:${_dos(ahora.minute)}',
              ),
              style: const pw.TextStyle(fontSize: 8, color: _gris),
            ),
            pw.Text(
              'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _gris),
            ),
          ],
        ),
      ),
      build: (ctx) => [
        pw.Text(
          _limpio(negocio),
          style: const pw.TextStyle(fontSize: 10, color: _gris),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Reporte de inventario',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          _limpio(fechaLarga(r.dia)),
          style: const pw.TextStyle(fontSize: 11, color: _gris),
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          children: [
            cifra('Movimientos', '${r.movimientos.length}'),
            pw.SizedBox(width: 8),
            cifra('Entradas', '${r.cantidadEntradas}'),
            pw.SizedBox(width: 8),
            cifra('Salidas', '${r.cantidadSalidas}'),
            pw.SizedBox(width: 8),
            cifra(
              'Costo de entradas',
              'S/ ${r.costoEntradas.toStringAsFixed(2)}',
            ),
          ],
        ),
        if (r.vacio) ...[
          pw.SizedBox(height: 24),
          pw.Text(
            'No hubo movimientos de inventario este día.',
            style: const pw.TextStyle(fontSize: 11, color: _gris),
          ),
        ] else ...[
          titulo('Resumen por producto'),
          tabla(
            ctx,
            encabezados: const [
              'Producto',
              'Unidad',
              'Inicio',
              'Entró',
              'Salió',
              'Final',
            ],
            filas: [
              for (final p in r.productos)
                [
                  p.nombre,
                  p.unidadId.isEmpty ? '' : unidadDe(p.unidadId),
                  _numero(p.inicio),
                  _numero(p.entradas),
                  _numero(p.salidas),
                  _numero(p.fin),
                ],
            ],
            anchos: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(1),
              5: pw.FlexColumnWidth(1),
            },
            alineacion: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
          ),
          titulo('Movimientos del día'),
          tabla(
            ctx,
            encabezados: const [
              'Hora',
              'Tipo',
              'Producto',
              'Cantidad',
              'Costo (S/)',
              'Usuario / notas',
            ],
            filas: [
              for (final m in r.movimientos)
                [
                  horaCorta(m.fecha),
                  m.tipoMovimiento.tipoMovimiento,
                  m.productoNombre ?? '',
                  '${m.tipoMovimiento.esEntrada ? '+' : '-'}'
                      '${_numero(m.cantidad)}',
                  m.costoTotal > 0 ? m.costoTotal.toStringAsFixed(2) : '',
                  [
                    if ((m.usuarioNombre ?? '').isNotEmpty) m.usuarioNombre!,
                    if ((m.notas ?? '').isNotEmpty) m.notas!,
                  ].join(' - '),
                ],
            ],
            anchos: const {
              0: pw.FlexColumnWidth(0.9),
              1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(2.2),
              3: pw.FlexColumnWidth(1.1),
              4: pw.FlexColumnWidth(1.1),
              5: pw.FlexColumnWidth(3),
            },
            alineacion: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerLeft,
            },
          ),
          if (r.porTipo.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              _limpio(
                'Por tipo: '
                '${r.porTipo.entries.map((e) => '${e.key} (${e.value})').join(', ')}',
              ),
              style: const pw.TextStyle(fontSize: 9, color: _gris),
            ),
          ],
        ],
      ],
    ),
  );

  return doc.save();
}

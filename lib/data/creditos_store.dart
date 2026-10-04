import '../models/documento_credito.dart';
import '../models/pedido.dart';

// Notas de crédito y vales de consumo emitidos (en memoria).
// TODO: reemplazar por `nota_credito` / `vale_consumo` reales al conectar el
// backend.
final List<NotaCredito> notasCredito = [];
final List<ValeConsumo> valesConsumo = [];

// Días de vigencia de un vale de consumo.
const vigenciaValeDias = 30;

int _correlativoNc = 0;
int _correlativoVale = 0;

NotaCredito emitirNotaCredito({
  required Pedido pedido,
  required String concepto,
  required double monto,
  required double saldoAFavor,
}) {
  _correlativoNc += 1;
  final nota = NotaCredito(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    numero: 'NC-${_correlativoNc.toString().padLeft(4, '0')}',
    pedidoId: pedido.id,
    pedidoNumero: pedido.numeroPedido,
    concepto: concepto,
    monto: monto,
    saldoAFavor: saldoAFavor,
    clienteNombre: pedido.clienteNombre,
    fecha: DateTime.now(),
  );
  notasCredito.insert(0, nota);
  return nota;
}

ValeConsumo emitirVale({
  required Pedido pedido,
  required String concepto,
  required double monto,
}) {
  _correlativoVale += 1;
  final ahora = DateTime.now();
  final vale = ValeConsumo(
    id: ahora.microsecondsSinceEpoch.toString(),
    codigo: 'VC-${_correlativoVale.toString().padLeft(4, '0')}',
    pedidoId: pedido.id,
    pedidoNumero: pedido.numeroPedido,
    concepto: concepto,
    monto: monto,
    clienteNombre: pedido.clienteNombre,
    emision: ahora,
    vigencia: ahora.add(const Duration(days: vigenciaValeDias)),
  );
  valesConsumo.insert(0, vale);
  return vale;
}

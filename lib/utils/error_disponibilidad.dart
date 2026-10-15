// Motivo por el que el backend rechazó un pedido por falta de stock.
//
// El backend solo envía un texto (HTTP 400); aquí se lee para poder ayudar al
// mozo a corregir esa fila. Si el backend cambia las frases, `tryParse` devuelve
// null y se muestra el aviso de siempre. Frases actuales:
//  - el plato 'X' se encuentra agotado
//  - stock insuficiente de 'X': disponibles N, requeridos M
//  - el plato requiere apertura diaria y no ha sido abierto hoy
enum MotivoStock { agotado, insuficiente, sinApertura }

class ErrorDisponibilidad {
  final MotivoStock motivo;
  final String? plato;
  final int? disponibles;
  final int? requeridos;

  const ErrorDisponibilidad(
    this.motivo, {
    this.plato,
    this.disponibles,
    this.requeridos,
  });

  static final _agotado = RegExp(r"el plato '(.+?)' se encuentra agotado");
  static final _insuficiente = RegExp(
    r"stock insuficiente de '(.+?)': disponibles (-?\d+), requeridos (\d+)",
  );
  static final _sinApertura = RegExp(
    r'el plato requiere apertura diaria y no ha sido abierto hoy',
  );

  static ErrorDisponibilidad? tryParse(String mensaje) {
    final ins = _insuficiente.firstMatch(mensaje);
    if (ins != null) {
      return ErrorDisponibilidad(
        MotivoStock.insuficiente,
        plato: ins.group(1),
        disponibles: int.tryParse(ins.group(2)!),
        requeridos: int.tryParse(ins.group(3)!),
      );
    }
    final ago = _agotado.firstMatch(mensaje);
    if (ago != null) {
      return ErrorDisponibilidad(MotivoStock.agotado, plato: ago.group(1));
    }
    if (_sinApertura.hasMatch(mensaje)) {
      return const ErrorDisponibilidad(MotivoStock.sinApertura);
    }
    return null;
  }
}

import '../data/disponibilidad_store.dart';
import '../models/carta_item.dart';
import '../models/mesa.dart';
import '../models/pedido.dart';
import '../models/taper.dart';

// Cifras de la vista Inicio, calculadas con lo que la app ya tiene en memoria
// (pedidos abiertos, mesas, stock del día y tápers).
class ResumenInicio {
  final int activos;
  final int pendientes;
  final int servidos;
  final int enMesa;
  final int paraLlevar;
  final int delivery;
  // Total de los pedidos abiertos: lo que falta cobrar.
  final double porCobrar;

  final int mesasOcupadas;
  final int mesasLibres;
  final int mesasTotal;
  // Mesas con pedidos abiertos de quien mira (para el mozo).
  final int mesasConPedido;

  // Espera de los pedidos pendientes (desde que se tomaron).
  final Duration? esperaPromedio;
  final Pedido? masAntiguo;
  // Los pendientes que más llevan esperando, del más antiguo al más reciente.
  final List<Pedido> masEsperando;
  // Pendientes que llevan [umbralLento] o más sin servirse.
  final int pendientesLentos;

  final List<String> platosAgotados;
  // Platos que la sede exige abrir hoy y aún no se abrieron.
  final int platosSinAbrir;
  final List<String> tapersBajos;

  const ResumenInicio({
    required this.activos,
    required this.pendientes,
    required this.servidos,
    required this.enMesa,
    required this.paraLlevar,
    required this.delivery,
    required this.porCobrar,
    required this.mesasOcupadas,
    required this.mesasLibres,
    required this.mesasTotal,
    required this.mesasConPedido,
    required this.esperaPromedio,
    required this.masAntiguo,
    required this.masEsperando,
    required this.pendientesLentos,
    required this.platosAgotados,
    required this.platosSinAbrir,
    required this.tapersBajos,
  });
}

// [soloUsuarioId]: con un id, solo cuentan los pedidos de ese usuario (el mozo
// ve lo suyo; el administrador, todo).
ResumenInicio calcularResumenInicio({
  required List<Pedido> pedidos,
  required double Function(String pedidoId) totalDe,
  required List<Mesa> mesas,
  required List<CartaItem> cartas,
  required List<Taper> tapers,
  required DateTime ahora,
  String? soloUsuarioId,
  int maxEsperando = 6,
  Duration umbralLento = const Duration(minutes: 20),
}) {
  final abiertos = [
    for (final p in pedidos)
      if (p.abierto && (soloUsuarioId == null || p.usuarioId == soloUsuarioId))
        p,
  ];
  final pendientes = abiertos
      .where((p) => p.estado == 'pendiente' || p.estado == 'pedido')
      .toList();
  final esperando = [...pendientes]
    ..sort((a, b) => a.fechaPedido.compareTo(b.fechaPedido));

  Duration? promedio;
  if (pendientes.isNotEmpty) {
    final total = pendientes.fold<int>(
      0,
      (s, p) => s + ahora.difference(p.fechaPedido).inSeconds.clamp(0, 1 << 30),
    );
    promedio = Duration(seconds: total ~/ pendientes.length);
  }

  final mesasDeMisPedidos = <int>{
    for (final p in abiertos)
      if (p.tipoPedido == 'mesa') ...p.todasLasMesas.where((n) => n > 0),
  };

  final agotados = <String>[];
  var sinAbrir = 0;
  for (final c in cartas) {
    // Los inhabilitados o eliminados no se venden: no son una alerta.
    if (c.inhabilitado || c.eliminado) continue;
    final estado = estadoDisponibilidadDe(c.id);
    if (c.agotado || estado.tipo == TipoDisponibilidad.agotado) {
      agotados.add(c.nombrePlato);
    } else if (estado.tipo == TipoDisponibilidad.sinApertura) {
      sinAbrir++;
    }
  }
  agotados.sort();

  return ResumenInicio(
    activos: abiertos.length,
    pendientes: pendientes.length,
    servidos: abiertos.length - pendientes.length,
    enMesa: abiertos.where((p) => p.tipoPedido == 'mesa').length,
    paraLlevar: abiertos.where((p) => p.tipoPedido == 'llevar').length,
    delivery: abiertos.where((p) => p.tipoPedido == 'delivery').length,
    porCobrar: abiertos.fold(0.0, (s, p) => s + totalDe(p.id)),
    mesasOcupadas: mesas.where((m) => m.estaOcupada).length,
    mesasLibres: mesas.where((m) => m.estaLibre).length,
    mesasTotal: mesas.length,
    mesasConPedido: mesasDeMisPedidos.length,
    esperaPromedio: promedio,
    masAntiguo: esperando.isEmpty ? null : esperando.first,
    masEsperando: esperando.take(maxEsperando).toList(),
    pendientesLentos: esperando
        .where((p) => ahora.difference(p.fechaPedido) >= umbralLento)
        .length,
    platosAgotados: agotados,
    platosSinAbrir: sinAbrir,
    tapersBajos: [
      for (final t in tapers)
        if (t.estado && t.stockBajo) t.nombre,
    ],
  );
}

// "12 min", "1 h 05 min" o "menos de 1 min".
String textoDeDuracion(Duration d) {
  final min = d.inMinutes;
  if (min < 1) return 'menos de 1 min';
  if (min < 60) return '$min min';
  final h = min ~/ 60;
  final m = (min % 60).toString().padLeft(2, '0');
  return '$h h $m min';
}

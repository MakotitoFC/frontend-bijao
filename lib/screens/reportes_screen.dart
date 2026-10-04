import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/configuracion_store.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../data/usuarios_store.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';

// Reportes calculados en vivo desde `pedidos`/`pagos`.
class ReportesScreen extends StatelessWidget {
  const ReportesScreen({super.key});

  List<Pedido> get _pedidosValidos => pedidos
      .where((p) => p.estado != 'cancelado' && p.estado != 'anulado')
      .toList();

  double _ventasDe(Iterable<Pedido> lista) =>
      lista.fold(0.0, (s, p) => s + totalDePedido(p.id));

  // Compara los últimos 7 días contra los 7 anteriores ("--%" si no hay datos).
  ({double actual, double anterior}) _periodos(
    double Function(List<Pedido>) calcular,
  ) {
    final ahora = DateTime.now();
    final corte1 = ahora.subtract(const Duration(days: 7));
    final corte2 = ahora.subtract(const Duration(days: 14));
    final actuales = _pedidosValidos
        .where((p) => p.fechaPedido.isAfter(corte1))
        .toList();
    final anteriores = _pedidosValidos
        .where(
          (p) =>
              p.fechaPedido.isAfter(corte2) && p.fechaPedido.isBefore(corte1),
        )
        .toList();
    return (actual: calcular(actuales), anterior: calcular(anteriores));
  }

  double? _cambioPct(double actual, double anterior) {
    if (anterior == 0) return null;
    return (actual - anterior) / anterior * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, c) {
          final angosto = c.maxWidth < 900;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _filaKpis(angosto),
                const SizedBox(height: 16),
                _tarjeta(child: _analisisPedidos(angosto)),
                const SizedBox(height: 16),
                _filaAdaptable(
                  angosto,
                  izquierda: _tarjeta(
                    titulo: 'Progreso de pedidos',
                    child: _progresoPedidos(),
                  ),
                  derecha: _tarjeta(
                    titulo: 'Rendimiento de meseros',
                    child: _rendimientoMeseros(),
                  ),
                  flexIzquierda: 3,
                  flexDerecha: 2,
                ),
                const SizedBox(height: 16),
                _filaAdaptable(
                  angosto,
                  izquierda: _tarjeta(
                    titulo: 'Horas con más ventas',
                    child: _horasConMasVentas(),
                  ),
                  derecha: Column(
                    children: [
                      _tarjeta(
                        titulo: 'Días con más ventas',
                        child: _diasConMasVentas(),
                      ),
                      const SizedBox(height: 16),
                      _tarjeta(
                        titulo: 'Métodos de pago',
                        child: _metodosPago(),
                      ),
                    ],
                  ),
                  flexIzquierda: 1,
                  flexDerecha: 1,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filaAdaptable(
    bool angosto, {
    required Widget izquierda,
    required Widget derecha,
    required int flexIzquierda,
    required int flexDerecha,
  }) {
    if (angosto) {
      return Column(children: [izquierda, const SizedBox(height: 16), derecha]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: flexIzquierda, child: izquierda),
        const SizedBox(width: 16),
        Expanded(flex: flexDerecha, child: derecha),
      ],
    );
  }

  Widget _tarjeta({String? titulo, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titulo != null) ...[
            Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }

  // --- KPIs ---

  Widget _filaKpis(bool angosto) {
    final cantidad = _periodos((l) => l.length.toDouble());
    final ventas = _periodos(_ventasDe);
    final ticket = _periodos((l) => l.isEmpty ? 0 : _ventasDe(l) / l.length);
    final tarjetas = [
      _kpi(
        'Cantidad de pedidos',
        '${_pedidosValidos.length}',
        _cambioPct(cantidad.actual, cantidad.anterior),
      ),
      _kpi(
        'Ventas totales',
        'S/. ${_ventasDe(_pedidosValidos).toStringAsFixed(2)}',
        _cambioPct(ventas.actual, ventas.anterior),
      ),
      _kpi(
        'Ticket promedio',
        'S/. ${(_pedidosValidos.isEmpty ? 0 : _ventasDe(_pedidosValidos) / _pedidosValidos.length).toStringAsFixed(2)}',
        _cambioPct(ticket.actual, ticket.anterior),
      ),
    ];
    if (angosto) {
      return Column(
        children: [
          for (var i = 0; i < tarjetas.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            tarjetas[i],
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < tarjetas.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: tarjetas[i]),
        ],
      ],
    );
  }

  Widget _kpi(String titulo, String valor, double? cambioPct) {
    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                titulo,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              _chipCambio(cambioPct),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipCambio(double? pct) {
    if (pct == null) {
      return Text(
        '--%',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final positivo = pct >= 0;
    final color = positivo ? AppColors.success : AppColors.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          positivo ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          size: 18,
          color: color,
        ),
        Text(
          '${pct.abs().toStringAsFixed(2)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // --- Análisis de pedidos: dona + tabla por tipo de servicio ---

  List<({String label, Color color, bool Function(Pedido) filtro})>
  get _servicios => [
    (
      label: 'En mesa',
      color: const Color(0xFF8E24AA),
      filtro: (p) => p.tipoPedido == 'mesa',
    ),
    (
      label: 'A domicilio',
      color: AppColors.warning,
      filtro: (p) => p.tipoPedido == 'delivery',
    ),
  ];

  Widget _analisisPedidos(bool angosto) {
    final total = _pedidosValidos.length;
    final dona = SizedBox(
      height: 220,
      child: total == 0
          ? Center(
              child: Text(
                'Sin pedidos todavía',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 54,
                    sections: [
                      for (final s in _servicios)
                        if (_pedidosValidos.where(s.filtro).isNotEmpty)
                          PieChartSectionData(
                            value: _pedidosValidos
                                .where(s.filtro)
                                .length
                                .toDouble(),
                            color: s.color,
                            radius: 46,
                            title:
                                '${(_pedidosValidos.where(s.filtro).length / total * 100).toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                    ],
                  ),
                ),
                Text(
                  'Cantidad de\npedidos',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
    );
    final tabla = _tablaServicios(total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Análisis de pedidos',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 14),
        angosto
            ? Column(children: [dona, const SizedBox(height: 16), tabla])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 220, child: dona),
                  const SizedBox(width: 24),
                  Expanded(child: tabla),
                ],
              ),
      ],
    );
  }

  Widget _tablaServicios(int total) {
    const estiloCabecera = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Color(0xFF6B7280),
    );
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1.3),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1.6),
      },
      children: [
        const TableRow(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('TIPO DE SERVICIO', style: estiloCabecera),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('PEDIDOS', style: estiloCabecera),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('VENTAS', style: estiloCabecera),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('TICKET PROM.', style: estiloCabecera),
            ),
          ],
        ),
        for (final s in _servicios) _filaServicio(s),
      ],
    );
  }

  TableRow _filaServicio(
    ({String label, Color color, bool Function(Pedido) filtro}) s,
  ) {
    final lista = _pedidosValidos.where(s.filtro).toList();
    final ventas = _ventasDe(lista);
    final ticket = lista.isEmpty ? 0.0 : ventas / lista.length;
    final periodoCantidad = _periodos(
      (l) => l.where(s.filtro).length.toDouble(),
    );
    final periodoVentas = _periodos((l) => _ventasDe(l.where(s.filtro)));
    final periodoTicket = _periodos((l) {
      final f = l.where(s.filtro).toList();
      return f.isEmpty ? 0 : _ventasDe(f) / f.length;
    });
    Widget celda(Widget w) =>
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: w);
    Widget valorConCambio(String texto, double? cambio) => Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          texto,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        _chipCambio(cambio),
      ],
    );
    return TableRow(
      children: [
        celda(
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: s.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  s.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        celda(
          valorConCambio(
            '${lista.length}',
            _cambioPct(periodoCantidad.actual, periodoCantidad.anterior),
          ),
        ),
        celda(
          valorConCambio(
            '\$ ${ventas.toStringAsFixed(2)}',
            _cambioPct(periodoVentas.actual, periodoVentas.anterior),
          ),
        ),
        celda(
          valorConCambio(
            '\$ ${ticket.toStringAsFixed(2)}',
            _cambioPct(periodoTicket.actual, periodoTicket.anterior),
          ),
        ),
      ],
    );
  }

  // --- Progreso de pedidos: línea últimos 7 días vs 7 anteriores ---

  List<DateTime> get _ultimos7Dias {
    final hoy = DateTime.now();
    final soloFecha = DateTime(hoy.year, hoy.month, hoy.day);
    return [for (var i = 6; i >= 0; i--) soloFecha.subtract(Duration(days: i))];
  }

  int _pedidosEnDia(DateTime dia) => _pedidosValidos
      .where(
        (p) =>
            p.fechaPedido.year == dia.year &&
            p.fechaPedido.month == dia.month &&
            p.fechaPedido.day == dia.day,
      )
      .length;

  Widget _progresoPedidos() {
    final dias = _ultimos7Dias;
    final actual = dias.map(_pedidosEnDia).toList();
    final anterior = dias
        .map((d) => _pedidosEnDia(d.subtract(const Duration(days: 7))))
        .toList();
    final maxY = ([...actual, ...anterior].fold(0, (a, b) => a > b ? a : b) + 2)
        .toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: (maxY / 4).clamp(1, double.infinity),
                    getTitlesWidget: (v, meta) => Text(
                      v.toInt().toString(),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= dias.length) {
                        return const SizedBox.shrink();
                      }
                      final d = dias[i];
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${d.day} ${_mesAbrev(d.month)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < actual.length; i++)
                      FlSpot(i.toDouble(), actual[i].toDouble()),
                  ],
                  color: AppColors.primaryGreenDark,
                  barWidth: 2.5,
                  isCurved: false,
                  dotData: const FlDotData(show: true),
                ),
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < anterior.length; i++)
                      FlSpot(i.toDouble(), anterior[i].toDouble()),
                  ],
                  color: AppColors.primaryGreen.withValues(alpha: 0.35),
                  barWidth: 2.5,
                  isCurved: false,
                  dotData: const FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _leyendaLinea('Últimos 7 días', AppColors.primaryGreenDark),
            const SizedBox(width: 16),
            _leyendaLinea(
              '7 días anteriores',
              AppColors.primaryGreen.withValues(alpha: 0.35),
            ),
          ],
        ),
      ],
    );
  }

  String _mesAbrev(int mes) => const [
    '',
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ][mes];

  Widget _leyendaLinea(String texto, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // --- Rendimiento de meseros (pedidos.usuario_id) ---

  String _nombreUsuario(String? id) {
    for (final u in usuarios) {
      if (u.id == id) return u.nombre;
    }
    return 'Sin asignar';
  }

  Widget _rendimientoMeseros() {
    final porMesero = <String, List<Pedido>>{};
    for (final p in _pedidosValidos) {
      final id = p.usuarioId ?? '—';
      porMesero.putIfAbsent(id, () => []).add(p);
    }
    if (porMesero.isEmpty) {
      return Center(
        heightFactor: 3,
        child: Text(
          'Sin pedidos todavía',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }
    final filas = porMesero.entries.map((e) {
      final ventas = _ventasDe(e.value);
      return (
        nombre: _nombreUsuario(e.key),
        pedidos: e.value.length,
        ventas: ventas,
      );
    }).toList()..sort((a, b) => b.ventas.compareTo(a.ventas));
    final maxVentas = filas.fold(0.0, (m, f) => f.ventas > m ? f.ventas : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in filas) ...[
          _filaMesero(f.nombre, f.pedidos, f.ventas, maxVentas),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _filaMesero(
    String nombre,
    int pedidos,
    double ventas,
    double maxVentas,
  ) {
    final proporcion = maxVentas == 0
        ? 0.0
        : (ventas / maxVentas).clamp(0.05, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                nombre,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$pedidos pedido(s) · S/ ${ventas.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: proporcion,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(AppColors.primaryGreen),
          ),
        ),
      ],
    );
  }

  // --- Horas con más ventas: bloques de 2 horas ---

  List<int> get _pedidosPorBloqueHora {
    final bloques = List.filled(12, 0);
    for (final p in _pedidosValidos) {
      bloques[p.fechaPedido.hour ~/ 2]++;
    }
    return bloques;
  }

  Widget _horasConMasVentas() {
    final bloques = _pedidosPorBloqueHora;
    final maxValor = bloques.fold(0, (a, b) => a > b ? a : b);
    final mejorIndice = maxValor == 0 ? -1 : bloques.indexOf(maxValor);
    String etiqueta(int i) =>
        '${(i * 2).toString().padLeft(2, '0')}:00 - ${(i * 2 + 2).toString().padLeft(2, '0')}:00';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mejorIndice >= 0) ...[
          Text(
            'Mejor horario',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${etiqueta(mejorIndice)}  ',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: '$maxValor pedidos',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        for (var i = 0; i < bloques.length; i++) ...[
          _filaBarraHorizontal(etiqueta(i), bloques[i], maxValor),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _filaBarraHorizontal(String etiqueta, int valor, int maxValor) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            etiqueta,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              FractionallySizedBox(
                widthFactor: maxValor == 0
                    ? 0
                    : (valor / maxValor).clamp(0.02, 1.0),
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.info,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 20,
          child: Text(
            '$valor',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // --- Días con más ventas: barras Lun..Dom ---

  List<int> get _pedidosPorDiaSemana {
    final dias = List.filled(7, 0);
    for (final p in _pedidosValidos) {
      dias[p.fechaPedido.weekday - 1]++;
    }
    return dias;
  }

  Widget _diasConMasVentas() {
    const etiquetas = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final dias = _pedidosPorDiaSemana;
    final maxValor = dias.fold(0, (a, b) => a > b ? a : b);
    final mejorIndice = maxValor == 0 ? -1 : dias.indexOf(maxValor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mejorIndice >= 0) ...[
          Text(
            'Mejor día',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${etiquetas[mejorIndice]}  ',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: '$maxValor pedidos',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        SizedBox(
          height: 140,
          child: BarChart(
            BarChartData(
              maxY: (maxValor + 2).toDouble(),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= etiquetas.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          etiquetas[i],
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < dias.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: dias[i].toDouble(),
                        color: AppColors.info,
                        width: 22,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Métodos de pago (pagos.medio_pago) ---

  Widget _metodosPago() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in mediosPagoActivos) ...[
          _filaMetodoPago(
            m.medioPago,
            pagos.where((p) => p.medioPago.id == m.id).length,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _filaMetodoPago(String nombre, int cantidad) {
    return Row(
      children: [
        Expanded(child: Text(nombre, style: const TextStyle(fontSize: 13))),
        Container(width: 2, height: 16, color: AppColors.info),
        const SizedBox(width: 10),
        SizedBox(
          width: 20,
          child: Text(
            '$cantidad',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

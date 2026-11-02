import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';
import '../widgets/selector_rango_fechas.dart';
import '../widgets/detalle_pedido_panel.dart' show nombreMeseroDe;

// Reportes calculados en vivo desde `pedidos`/`pagos`.
class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  // Fechas del reporte (null = todas las fechas).
  DateTimeRange? _rango;

  List<Pedido> get _todos =>
      pedidos.where((p) => p.estado != 'anulado').toList();

  // Los pedidos dentro del rango elegido: lo que suman las tarjetas y gráficos.
  List<Pedido> get _pedidosValidos {
    final r = _rango;
    if (r == null) return _todos;
    final ini = DateUtils.dateOnly(r.start);
    final fin = DateUtils.dateOnly(r.end);
    return [
      for (final p in _todos)
        if (!DateUtils.dateOnly(p.fechaPedido).isBefore(ini) &&
            !DateUtils.dateOnly(p.fechaPedido).isAfter(fin))
          p,
    ];
  }

  // Último día que se mira: el fin del rango o, sin rango, hoy.
  DateTime get _hasta {
    final r = _rango;
    final hoy = DateTime.now();
    final fin = r == null ? hoy : r.end;
    return DateTime(fin.year, fin.month, fin.day, 23, 59, 59);
  }

  double _ventasDe(Iterable<Pedido> lista) =>
      lista.fold(0.0, (s, p) => s + totalDePedido(p.id));

  // Compara los últimos 7 días contra los 7 anteriores ("--%" si no hay datos).
  ({double actual, double anterior}) _periodos(
    double Function(List<Pedido>) calcular,
  ) {
    final ahora = _hasta;
    final corte1 = ahora.subtract(const Duration(days: 7));
    final corte2 = ahora.subtract(const Duration(days: 14));
    final actuales = _todos
        .where(
          (p) => p.fechaPedido.isAfter(corte1) && !p.fechaPedido.isAfter(ahora),
        )
        .toList();
    final anteriores = _todos
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
            padding: EdgeInsets.all(angosto ? 14 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Reportes',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Información detallada de tus ventas y pedidos',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    // Filtro de fechas de los reportes (selector de la app).
                    SelectorRangoFechas(
                      valor: _rango,
                      permiteTodas: true,
                      textoVacio: 'Todas las fechas',
                      textoTodas: 'Todas las fechas',
                      onChanged: (r) => setState(() => _rango = r),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _contenido(angosto),
              ],
            ),
          );
        },
      ),
    );
  }

  // Todo en filas a todo el ancho: las tarjetas de una misma fila miden lo
  // mismo, así no quedan espacios sin cubrir.
  Widget _contenido(bool angosto) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _filaAdaptable(
          angosto,
          izquierda: _tarjetaPedidos(),
          derecha: _tarjetaVentas(),
          flexIzquierda: 1,
          flexDerecha: 1,
        ),
        const SizedBox(height: 16),
        _tarjeta(
          titulo: 'Ventas por mes · $_anioDelReporte',
          child: _ventasPorMes(),
        ),
        const SizedBox(height: 16),
        _filaAdaptable(
          angosto,
          izquierda: _tarjeta(child: _analisisPedidos(true)),
          derecha: _tarjeta(
            titulo: 'Últimos pedidos',
            child: _ultimosPedidos(),
          ),
          flexIzquierda: 1,
          flexDerecha: 1,
        ),
        const SizedBox(height: 16),
        _filaAdaptable(
          angosto,
          izquierda: _tarjeta(
            titulo: 'Progreso de pedidos',
            child: _progresoPedidos(),
          ),
          derecha: _tarjeta(
            titulo: 'Rendimiento de mozos',
            child: _rendimientoMozos(),
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
          derecha: _tarjeta(
            titulo: 'Días con más ventas',
            child: _diasConMasVentas(),
          ),
          flexIzquierda: 1,
          flexDerecha: 1,
        ),
      ],
    );
  }

  // Colores de la app: verde para lo principal y su versión suave.
  Color get _lila => AppColors.primaryGreen.withValues(alpha: 0.28);
  Color get _lilaFuerte => AppColors.primaryGreen;

  // Año que muestra el gráfico mensual: el del fin del rango o el actual.
  int get _anioDelReporte => (_rango?.end ?? DateTime.now()).year;

  // Ventas de cada mes del año del reporte (con los pedidos que hay cargados).
  List<double> get _ventasMensuales {
    final anio = _anioDelReporte;
    final meses = List<double>.filled(12, 0);
    for (final p in _pedidosValidos) {
      if (p.fechaPedido.year == anio) {
        meses[p.fechaPedido.month - 1] += totalDePedido(p.id);
      }
    }
    return meses;
  }

  static const _mesesCortos = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', //
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  Widget _ventasPorMes() {
    final meses = _ventasMensuales;
    final maximo = meses.fold(0.0, (m, v) => v > m ? v : m);
    final mesActual = _anioDelReporte == DateTime.now().year
        ? DateTime.now().month - 1
        : -1;
    if (maximo <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Text(
            'No hay ventas en este período',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }
    return SizedBox(
      height: 230,
      child: BarChart(
        BarChartData(
          maxY: maximo * 1.15,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _mesesCortos[v.toInt()],
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: v.toInt() == mesActual
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.navbar,
              getTooltipItem: (grupo, _, rod, _) => BarTooltipItem(
                '${_mesesCortos[grupo.x]}\nS/ ${rod.toY.toStringAsFixed(2)}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < 12; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: meses[i],
                    width: 24,
                    color: i == mesActual ? _lilaFuerte : _lila,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Últimos pedidos: número, mozo, estado y total.
  Widget _ultimosPedidos() {
    final recientes = [..._pedidosValidos]
      ..sort((a, b) => b.fechaPedido.compareTo(a.fechaPedido));
    if (recientes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Sin pedidos todavía',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final p in recientes.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: _lila.withValues(alpha: 0.6),
                  child: Text(
                    nombreMeseroDe(p).isEmpty
                        ? '?'
                        : nombreMeseroDe(p)[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreenDark,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombreMeseroDe(p),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        p.estado == 'pagado' ? 'Pagado' : 'Abierto',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: p.estado == 'pagado'
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '#${p.numeroPedido}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(width: 12),
                Text(
                  'S/ ${totalDePedido(p.id).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // --- Tarjetas de la derecha ---

  Widget _cambio(double? pct, {Color? base}) {
    if (pct == null) {
      return Text(
        '--%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: base ?? Colors.grey.shade500,
        ),
      );
    }
    final sube = pct >= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          sube ? Icons.trending_up : Icons.trending_down,
          size: 15,
          color: sube ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
        ),
        const SizedBox(width: 3),
        Text(
          '${pct.abs().toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: sube ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
          ),
        ),
      ],
    );
  }

  // Pedidos: total y reparto entre mesa y delivery.
  Widget _tarjetaPedidos() {
    final total = _pedidosValidos.length;
    final cantidad = _periodos((l) => l.length.toDouble());
    final mesa = _pedidosValidos.where((p) => p.tipoPedido == 'mesa').length;
    final delivery = _pedidosValidos
        .where((p) => p.tipoPedido == 'delivery')
        .length;
    final llevar = total - mesa - delivery;
    int pct(int n) => total == 0 ? 0 : (n / total * 100).round();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.navbar,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total de pedidos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$total',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _cambio(_cambioPct(cantidad.actual, cantidad.anterior)),
              ),
            ],
          ),
          Text(
            'Cambio de los últimos 7 días frente a los 7 anteriores',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 16),
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    if (mesa > 0)
                      Expanded(
                        flex: mesa,
                        child: _tramo('${pct(mesa)}%', Colors.white),
                      ),
                    if (delivery > 0)
                      Expanded(
                        flex: delivery,
                        child: _tramo('${pct(delivery)}%', _lilaFuerte),
                      ),
                    if (llevar > 0)
                      Expanded(
                        flex: llevar,
                        child: _tramo('${pct(llevar)}%', _lila),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            children: [
              _leyendaOscura('Mesa', Colors.white),
              _leyendaOscura('Delivery', _lilaFuerte),
              _leyendaOscura('Para llevar', _lila),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tramo(String texto, Color color) => Container(
    color: color,
    alignment: Alignment.bottomRight,
    padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
    child: Text(
      texto,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color == Colors.white || color == _lila
            ? AppColors.navbar
            : Colors.white,
      ),
    ),
  );

  Widget _leyendaOscura(String texto, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(texto, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
    ],
  );

  // Ventas: total y barras de los últimos 7 días.
  Widget _tarjetaVentas() {
    final ventas = _periodos(_ventasDe);
    final dias = _ultimos7Dias;
    final porDia = [
      for (final d in dias)
        _ventasDe(
          _todos.where(
            (p) =>
                p.fechaPedido.year == d.year &&
                p.fechaPedido.month == d.month &&
                p.fechaPedido.day == d.day,
          ),
        ),
    ];
    final maximo = porDia.fold(0.0, (m, v) => v > m ? v : m);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryGreenDark, AppColors.primaryGreen],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ventas totales',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'S/ ${_ventasDe(_pedidosValidos).toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: _cambio(_cambioPct(ventas.actual, ventas.anterior)),
              ),
            ],
          ),
          Text(
            'Últimos 7 días: S/ ${ventas.actual.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < dias.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Tooltip(
                            message: 'S/ ${porDia[i].toStringAsFixed(2)}',
                            child: Container(
                              height: maximo == 0
                                  ? 6
                                  : (porDia[i] / maximo * 70).clamp(6, 70),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: i == dias.length - 1 ? 1 : 0.8,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${dias[i].day}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: flexIzquierda, child: izquierda),
          const SizedBox(width: 16),
          Expanded(flex: flexDerecha, child: derecha),
        ],
      ),
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

  // --- Análisis de pedidos: dona; el detalle sale al pasar el cursor ---

  List<({String label, Color color, bool Function(Pedido) filtro})>
  get _servicios => [
    (
      label: 'En mesa',
      color: _lilaFuerte,
      filtro: (p) => p.tipoPedido == 'mesa',
    ),
    (
      label: 'Delivery',
      color: AppColors.navbar,
      filtro: (p) => p.tipoPedido == 'delivery',
    ),
    (
      label: 'Para llevar',
      color: AppColors.naranja,
      filtro: (p) => p.tipoPedido == 'llevar',
    ),
  ];

  Widget _analisisPedidos(bool angosto) {
    final total = _pedidosValidos.length;
    final datos = [
      for (final s in _servicios)
        (
          label: s.label,
          color: s.color,
          pedidos: _pedidosValidos.where(s.filtro).length,
          ventas: _ventasDe(_pedidosValidos.where(s.filtro)),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Análisis de pedidos',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 14),
        if (total == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'Sin pedidos todavía',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          )
        else
          _DonaPedidos(datos: datos, total: total),
      ],
    );
  }

  // --- Progreso de pedidos: línea últimos 7 días vs 7 anteriores ---

  List<DateTime> get _ultimos7Dias {
    final hoy = _hasta;
    final soloFecha = DateTime(hoy.year, hoy.month, hoy.day);
    return [for (var i = 6; i >= 0; i--) soloFecha.subtract(Duration(days: i))];
  }

  int _pedidosEnDia(DateTime dia) => _todos
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
    const nombres = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    LineChartBarData linea(List<int> v, Color color, {bool punteada = false}) =>
        LineChartBarData(
          spots: [
            for (var i = 0; i < v.length; i++)
              FlSpot(i.toDouble(), v[i].toDouble()),
          ],
          isCurved: true,
          color: color,
          barWidth: 3,
          dashArray: punteada ? [6, 5] : null,
          dotData: FlDotData(
            show: !punteada,
            checkToShowDot: (s, _) => s.x == v.length - 1,
          ),
          belowBarData: BarAreaData(
            show: !punteada,
            color: color.withValues(alpha: 0.12),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: Colors.grey.shade200, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                leftTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= dias.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          nombres[dias[i].weekday - 1],
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
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.navbar,
                  getTooltipItems: (puntos) => [
                    for (final s in puntos)
                      LineTooltipItem(
                        s.barIndex == 0
                            ? '${nombres[dias[s.spotIndex].weekday - 1]} '
                                  '${dias[s.spotIndex].day}\n'
                                  '${s.y.toInt()} pedidos'
                            : 'Semana anterior\n${s.y.toInt()} pedidos',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                linea(actual, _lilaFuerte),
                linea(anterior, AppColors.naranja, punteada: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 6,
          children: [
            _leyendaClara('Últimos 7 días', _lilaFuerte),
            _leyendaClara('7 días anteriores', AppColors.naranja),
          ],
        ),
      ],
    );
  }

  Widget _leyendaClara(String texto, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(texto, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
    ],
  );

  // --- Rendimiento de mozos (pedidos.usuario_id) ---

  // Nombre del mozo: el que trae el pedido y, si falta, el de la lista de
  // usuarios cargada. Solo sin ninguno dice "Sin asignar".
  String _nombreMozo(String? id, List<Pedido> pedidos) {
    for (final p in pedidos) {
      final n = p.mozoNombre;
      if (n != null && n.trim().isNotEmpty) return n;
    }
    return 'Sin asignar';
  }

  Widget _rendimientoMozos() {
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
        nombre: _nombreMozo(e.key, e.value),
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

  // Barras lila con el detalle en un tooltip; la mejor se resalta.
  Widget _graficoBarras({
    required List<int> valores,
    required List<String> etiquetas,
    required String Function(int i) titulo,
    required double alto,
    required double ancho,
  }) {
    final maxValor = valores.fold(0, (a, b) => a > b ? a : b);
    final mejor = maxValor == 0 ? -1 : valores.indexOf(maxValor);
    if (maxValor == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            'Sin pedidos todavía',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }
    return SizedBox(
      height: alto,
      child: BarChart(
        BarChartData(
          maxY: maxValor * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    etiquetas[v.toInt()],
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade600,
                      fontWeight: v.toInt() == mejor
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.navbar,
              getTooltipItem: (grupo, _, rod, _) => BarTooltipItem(
                '${titulo(grupo.x)}\n${rod.toY.toInt()} pedidos',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < valores.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: valores[i].toDouble(),
                    width: ancho,
                    color: i == mejor ? _lilaFuerte : _lila,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _horasConMasVentas() {
    final bloques = _pedidosPorBloqueHora;
    final maxValor = bloques.fold(0, (a, b) => a > b ? a : b);
    final mejor = maxValor == 0 ? -1 : bloques.indexOf(maxValor);
    String rango(int i) =>
        '${(i * 2).toString().padLeft(2, '0')}:00 - ${(i * 2 + 2).toString().padLeft(2, '0')}:00';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mejor >= 0) ...[
          Text(
            'Mejor horario',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${rango(mejor)}  ',
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
        _graficoBarras(
          valores: bloques,
          etiquetas: [
            for (var i = 0; i < bloques.length; i++)
              (i * 2).toString().padLeft(2, '0'),
          ],
          titulo: rango,
          alto: 180,
          ancho: 14,
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
    const completos = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final dias = _pedidosPorDiaSemana;
    final maxValor = dias.fold(0, (a, b) => a > b ? a : b);
    final mejor = maxValor == 0 ? -1 : dias.indexOf(maxValor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mejor >= 0) ...[
          Text(
            'Mejor día',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${completos[mejor]}  ',
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
        _graficoBarras(
          valores: dias,
          etiquetas: etiquetas,
          titulo: (i) => completos[i],
          alto: 180,
          ancho: 26,
        ),
      ],
    );
  }
}

// Dona de pedidos por tipo: al pasar el cursor por un tramo, el centro muestra
// su detalle (tipo, pedidos, porcentaje y ventas).
class _DonaPedidos extends StatefulWidget {
  final List<({String label, Color color, int pedidos, double ventas})> datos;
  final int total;

  const _DonaPedidos({required this.datos, required this.total});

  @override
  State<_DonaPedidos> createState() => _DonaPedidosState();
}

class _DonaPedidosState extends State<_DonaPedidos> {
  int _tocado = -1;

  @override
  Widget build(BuildContext context) {
    final visibles = [
      for (final d in widget.datos)
        if (d.pedidos > 0) d,
    ];
    final sel = _tocado >= 0 && _tocado < visibles.length
        ? visibles[_tocado]
        : null;
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 62,
                  pieTouchData: PieTouchData(
                    touchCallback: (evento, respuesta) {
                      final i =
                          respuesta?.touchedSection?.touchedSectionIndex ?? -1;
                      if (i != _tocado) setState(() => _tocado = i);
                    },
                  ),
                  sections: [
                    for (var i = 0; i < visibles.length; i++)
                      PieChartSectionData(
                        value: visibles[i].pedidos.toDouble(),
                        color: visibles[i].color,
                        radius: i == _tocado ? 30 : 24,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 52),
                child: sel == null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${widget.total}',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'pedidos',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            sel.label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${(sel.pedidos / widget.total * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${sel.pedidos} pedidos',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'S/ ${sel.ventas.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 6,
          children: [
            for (final d in widget.datos)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: d.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    d.label,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

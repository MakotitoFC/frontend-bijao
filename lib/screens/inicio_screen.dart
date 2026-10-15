import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/cartas_store.dart';
import '../data/disponibilidad_store.dart';
import '../data/mesas_por_liberar_store.dart';
import '../data/mesas_store.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../models/app_role.dart';
import '../models/mesa.dart';
import '../models/pedido.dart';
import '../models/sede.dart';
import '../models/usuario.dart';
import '../services/catalog_service.dart';
import '../services/disponibilidad_service.dart';
import '../services/eventos_service.dart';
import '../services/pedido_service.dart';
import '../theme/app_theme.dart';
import '../utils/resumen_inicio.dart';
import '../widgets/cronometro_pedido.dart';
import '../widgets/detalle_pedido_panel.dart' show nombreMeseroDe;

const _dias = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
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

String _fechaLarga(DateTime d) =>
    '${_dias[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]}';

// Vista de inicio: un resumen del día con las cifras que importan a cada rol,
// los pedidos que más esperan, las alertas y atajos.
class InicioScreen extends StatefulWidget {
  final Usuario usuario;
  final Sede sede;
  // Pide ir a otra vista del menú (por clave, p. ej. 'pedidos').
  final ValueChanged<String> onIrA;

  const InicioScreen({
    super.key,
    required this.usuario,
    required this.sede,
    required this.onIrA,
  });

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  Timer? _timer;
  bool _cargando = false;

  AppRole get _rol => widget.usuario.rol;
  bool get _esMozo => _rol == AppRole.mesero;
  bool get _esCocina => _rol == AppRole.trabajador;
  bool get _veMesas => _rol == AppRole.administrador || _rol == AppRole.cajero;

  @override
  void initState() {
    super.initState();
    EventosService.instance.revision.addListener(_redibujar);
    EventosService.instance.conectado.addListener(_redibujar);
    _cargar();
    // Respaldo cuando no hay conexión en vivo; también mantiene al día las
    // esperas (minutos) sin tocar nada.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!EventosService.instance.conectado.value) {
        _cargar();
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    EventosService.instance.revision.removeListener(_redibujar);
    EventosService.instance.conectado.removeListener(_redibujar);
    _timer?.cancel();
    super.dispose();
  }

  void _redibujar() {
    if (mounted) setState(() {});
  }

  Future<void> _cargar() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    Future<void> seguro(Future<void> Function() f) async {
      try {
        await f();
      } catch (_) {}
    }

    await Future.wait([
      seguro(() => PedidoService.instance.cargarPedidos()),
      if (!_esCocina) seguro(() => CatalogService.instance.cargarMesas()),
      if (!_esCocina) seguro(() => DisponibilidadService.instance.cargarHoy()),
      if (_veMesas) seguro(() => CatalogService.instance.cargarTapers()),
      if (_esMozo) seguro(cargarMesasPorLiberar),
    ]);
    if (mounted) setState(() => _cargando = false);
  }

  ResumenInicio _resumen() => calcularResumenInicio(
    pedidos: pedidos,
    totalDe: totalDePedido,
    mesas: mesas,
    cartas: cartasNotifier.value,
    tapers: CatalogService.instance.tapers,
    ahora: DateTime.now(),
    soloUsuarioId: _esMozo ? widget.usuario.id : null,
  );

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final r = _resumen();
    final porLiberar = _esMozo ? mesasPorLiberar() : const <Mesa>[];
    final ancho = MediaQuery.sizeOf(context).width;
    final esMobile = ancho < 700;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(esMobile ? 16 : 32),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cabecera(),
                const SizedBox(height: 24),
                _kpis(r, porLiberar),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, c) {
                    final espera = _tarjetaEspera(r);
                    final alertas = _tarjetaAlertas(r, porLiberar);
                    if (c.maxWidth < 900) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [espera, const SizedBox(height: 16), alertas],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: espera),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: alertas),
                      ],
                    );
                  },
                ),
                if (_veMesas && mesas.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _tarjetaMesas(),
                ],
                const SizedBox(height: 24),
                _atajos(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ cabecera

  Widget _cabecera() {
    final vivo = EventosService.instance.conectado.value;
    final estrecho = MediaQuery.sizeOf(context).width < 400;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, ${widget.usuario.nombre}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_fechaLarga(DateTime.now())} · ${widget.sede.direccion}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: vivo
              ? 'Los datos se actualizan al instante.'
              : 'Sin conexión en vivo: se actualiza cada 30 segundos.',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: vivo ? AppColors.primaryGreen : Colors.grey.shade400,
                  ),
                ),
                if (!estrecho) ...[
                  const SizedBox(width: 6),
                  Text(
                    vivo ? 'En vivo' : 'Sin conexión en vivo',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Actualizar',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _cargando ? null : _cargar,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _cargando
                  ? const Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      LucideIcons.refreshCw,
                      size: 15,
                      color: Colors.grey.shade700,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- KPIs

  String _soles(double v) => 'S/ ${v.toStringAsFixed(2)}';

  String _resumenNombres(List<String> nombres) {
    if (nombres.isEmpty) return 'Ninguno';
    if (nombres.length <= 2) return nombres.join(', ');
    return '${nombres.take(2).join(', ')} y ${nombres.length - 2} más';
  }

  List<_Kpi> _listaKpis(ResumenInicio r, List<Mesa> porLiberar) {
    final espera = r.esperaPromedio;
    final antiguo = r.masAntiguo == null
        ? null
        : DateTime.now().difference(r.masAntiguo!.fechaPedido);
    final activosCard = _Kpi(
      icono: LucideIcons.clipboardList,
      color: AppColors.primaryGreen,
      titulo: _esMozo ? 'Mis pedidos activos' : 'Pedidos activos',
      valor: '${r.activos}',
      detalle: '${r.pendientes} pendientes · ${r.servidos} servidos',
      onTap: () => widget.onIrA(_esCocina ? 'cocina' : 'pedidos'),
    );
    final cobrarCard = _Kpi(
      icono: LucideIcons.banknote,
      color: AppColors.platoDelDia,
      titulo: 'Por cobrar',
      valor: _soles(r.porCobrar),
      detalle:
          'En ${r.activos} pedido${r.activos == 1 ? '' : 's'} abierto${r.activos == 1 ? '' : 's'}',
      onTap: () => widget.onIrA('pedidos'),
    );
    final esperaCard = _Kpi(
      icono: LucideIcons.timer,
      color: AppColors.accentGold,
      titulo: 'Espera promedio',
      valor: espera == null ? '—' : textoDeDuracion(espera),
      detalle: antiguo == null
          ? 'Sin pedidos pendientes'
          : 'El más antiguo: ${textoDeDuracion(antiguo)}',
    );
    final agotadosCard = _Kpi(
      icono: LucideIcons.utensilsCrossed,
      color: AppColors.error,
      titulo: 'Platos agotados hoy',
      valor: '${r.platosAgotados.length}',
      detalle: _resumenNombres(r.platosAgotados),
    );

    if (_esCocina) {
      return [
        _Kpi(
          icono: LucideIcons.chefHat,
          color: AppColors.primaryGreen,
          titulo: 'Pendientes',
          valor: '${r.pendientes}',
          detalle: 'Por servir',
          onTap: () => widget.onIrA('cocina'),
        ),
        _Kpi(
          icono: LucideIcons.utensils,
          color: const Color(0xFF0284C7),
          titulo: 'Servidos',
          valor: '${r.servidos}',
          detalle: 'Esperando el cobro',
        ),
        esperaCard,
        _Kpi(
          icono: LucideIcons.hourglass,
          color: AppColors.error,
          titulo: 'Lentos (20 min o más)',
          valor: '${r.pendientesLentos}',
          detalle: r.pendientesLentos == 0 ? 'Ninguno' : 'Pendientes de servir',
        ),
      ];
    }
    if (_esMozo) {
      return [
        activosCard,
        cobrarCard,
        _Kpi(
          icono: LucideIcons.layoutGrid,
          color: AppColors.mesaOcupada,
          titulo: 'Mis mesas',
          valor: '${r.mesasConPedido}',
          detalle: 'Con tus pedidos abiertos',
        ),
        _Kpi(
          icono: LucideIcons.armchair,
          color: AppColors.primaryGreenDark,
          titulo: 'Mesas por liberar',
          valor: '${porLiberar.length}',
          detalle: porLiberar.isEmpty
              ? 'Ninguna'
              : porLiberar.map((m) => 'Mesa ${m.numero}').join(', '),
          onTap: porLiberar.isEmpty ? null : () => widget.onIrA('pedidos'),
        ),
        esperaCard,
        agotadosCard,
      ];
    }
    return [
      activosCard,
      cobrarCard,
      _Kpi(
        icono: LucideIcons.layoutGrid,
        color: AppColors.mesaOcupada,
        titulo: 'Mesas ocupadas',
        valor: '${r.mesasOcupadas} de ${r.mesasTotal}',
        detalle: '${r.mesasLibres} libres',
        onTap: () => widget.onIrA('mesas'),
      ),
      esperaCard,
      _Kpi(
        icono: LucideIcons.bike,
        color: const Color(0xFF8B5CF6),
        titulo: 'Para llevar y delivery',
        valor: '${r.paraLlevar + r.delivery}',
        detalle: '${r.paraLlevar} para llevar · ${r.delivery} delivery',
      ),
      agotadosCard,
      _Kpi(
        icono: LucideIcons.package,
        color: const Color(0xFFD97706),
        titulo: 'Tápers con stock bajo',
        valor: '${r.tapersBajos.length}',
        detalle: _resumenNombres(r.tapersBajos),
        onTap: () => widget.onIrA('inventario'),
      ),
      _Kpi(
        icono: LucideIcons.utensils,
        color: const Color(0xFF0284C7),
        titulo: 'Servidos sin cobrar',
        valor: '${r.servidos}',
        detalle: 'Esperan el pago',
      ),
    ];
  }

  Widget _kpis(ResumenInicio r, List<Mesa> porLiberar) {
    final lista = _listaKpis(r, porLiberar);
    return LayoutBuilder(
      builder: (context, c) {
        const aire = 16.0;
        final columnas = c.maxWidth >= 1000 ? 4 : (c.maxWidth >= 560 ? 2 : 1);
        final ancho = (c.maxWidth - aire * (columnas - 1)) / columnas;
        return Wrap(
          spacing: aire,
          runSpacing: aire,
          children: [
            for (final k in lista)
              SizedBox(width: ancho, child: _TarjetaKpi(k)),
          ],
        );
      },
    );
  }

  // ------------------------------------------------- pedidos que esperan

  Widget _tarjeta({
    required String titulo,
    String? subtitulo,
    required Widget hijo,
    Widget? accion,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?accion,
            ],
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitulo,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 14),
          hijo,
        ],
      ),
    );
  }

  Widget _tarjetaEspera(ResumenInicio r) {
    return _tarjeta(
      titulo: 'Esperando más tiempo',
      subtitulo: 'Pedidos pendientes, del más antiguo al más reciente.',
      accion: TextButton(
        onPressed: () => widget.onIrA(_esCocina ? 'cocina' : 'pedidos'),
        child: const Text('Ver todos'),
      ),
      hijo: r.masEsperando.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No hay pedidos pendientes.',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < r.masEsperando.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
                  _filaPedido(r.masEsperando[i]),
                ],
              ],
            ),
    );
  }

  Widget _filaPedido(Pedido p) {
    final productos = (detallesPorPedido[p.id] ?? [])
        .where(esLineaDeProducto)
        .fold<int>(0, (s, l) => s + l.cantidad);
    final estrecho = MediaQuery.sizeOf(context).width < 400;
    return InkWell(
      onTap: () => widget.onIrA(_esCocina ? 'cocina' : 'pedidos'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.navbar,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '#${p.numeroPedido}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: estrecho ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.ubicacion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${nombreMeseroDe(p)} · $productos producto${productos == 1 ? '' : 's'}'
                    '${estrecho && !_esCocina ? ' · ${_soles(totalDePedido(p.id))}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CronometroPedido(pedido: p),
            if (!_esCocina && !estrecho) ...[
              const SizedBox(width: 12),
              Text(
                _soles(totalDePedido(p.id)),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------- alertas

  Widget _tarjetaAlertas(ResumenInicio r, List<Mesa> porLiberar) {
    final alertas = <_Alerta>[
      if (r.pendientesLentos > 0)
        _Alerta(
          LucideIcons.hourglass,
          AppColors.error,
          '${r.pendientesLentos} pedido${r.pendientesLentos == 1 ? ' lleva' : 's llevan'} 20 min o más sin servirse.',
          () => widget.onIrA(_esCocina ? 'cocina' : 'pedidos'),
        ),
      if (!_esCocina && r.platosAgotados.isNotEmpty)
        _Alerta(
          LucideIcons.utensilsCrossed,
          AppColors.error,
          'Agotados hoy: ${_resumenNombres(r.platosAgotados)}.',
          null,
        ),
      if (!_esCocina &&
          r.platosSinAbrir > 0 &&
          (configStockNotifier.value?.requiereAperturaDiaria ?? false))
        _Alerta(
          LucideIcons.calendarClock,
          AppColors.accentGold,
          '${r.platosSinAbrir} plato${r.platosSinAbrir == 1 ? '' : 's'} sin abrir hoy: no se pueden vender.',
          () => widget.onIrA('productos'),
        ),
      if (_veMesas && r.tapersBajos.isNotEmpty)
        _Alerta(
          LucideIcons.package,
          const Color(0xFFD97706),
          'Tápers con stock bajo: ${_resumenNombres(r.tapersBajos)}.',
          () => widget.onIrA('inventario'),
        ),
      if (porLiberar.isNotEmpty)
        _Alerta(
          LucideIcons.armchair,
          AppColors.primaryGreenDark,
          'Mesas por liberar: ${porLiberar.map((m) => m.numero).join(', ')}.',
          () => widget.onIrA('pedidos'),
        ),
    ];
    return _tarjeta(
      titulo: 'Alertas',
      subtitulo: 'Lo que conviene atender ahora.',
      hijo: alertas.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.circleCheck,
                    size: 18,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Todo en orden.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < alertas.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
                  _filaAlerta(alertas[i]),
                ],
              ],
            ),
    );
  }

  Widget _filaAlerta(_Alerta a) {
    return InkWell(
      onTap: a.alTocar,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: a.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(a.icono, size: 15, color: a.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(a.texto, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- mesas

  Widget _tarjetaMesas() {
    final ordenadas = [...mesas]..sort((a, b) => a.numero.compareTo(b.numero));
    return _tarjeta(
      titulo: 'Estado de las mesas',
      subtitulo: 'Azul: ocupada. Gris: libre.',
      accion: TextButton(
        onPressed: () => widget.onIrA('mesas'),
        child: const Text('Ver plano'),
      ),
      hijo: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final m in ordenadas)
            Container(
              width: 46,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: m.estaOcupada ? AppColors.mesaOcupada : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: m.estaOcupada
                      ? AppColors.mesaOcupada
                      : Colors.grey.shade300,
                ),
              ),
              child: Text(
                '${m.numero}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: m.estaOcupada ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ atajos

  Widget _atajos() {
    final botones = <(String, IconData, String, bool)>[
      if (!_esCocina) ('Nuevo pedido', LucideIcons.plus, 'pedidos', true),
      if (_esCocina) ('Ir a Cocina', LucideIcons.chefHat, 'cocina', true),
      if (_rol == AppRole.administrador || _esMozo)
        ('Carta', LucideIcons.utensilsCrossed, 'productos', false),
      if (_rol == AppRole.administrador)
        ('Cocina', LucideIcons.chefHat, 'cocina', false),
      if (_rol == AppRole.administrador)
        ('Inventario', LucideIcons.boxes, 'inventario', false),
      if (_rol == AppRole.cajero) ('Caja', LucideIcons.wallet, 'caja', false),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final (texto, icono, clave, principal) in botones)
          principal
              ? FilledButton.icon(
                  onPressed: () => widget.onIrA(clave),
                  icon: Icon(icono, size: 16),
                  label: Text(texto),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: () => widget.onIrA(clave),
                  icon: Icon(icono, size: 16),
                  label: Text(texto),
                ),
      ],
    );
  }
}

class _Kpi {
  final IconData icono;
  final Color color;
  final String titulo;
  final String valor;
  final String detalle;
  final VoidCallback? onTap;

  const _Kpi({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.valor,
    required this.detalle,
    this.onTap,
  });
}

class _Alerta {
  final IconData icono;
  final Color color;
  final String texto;
  final VoidCallback? alTocar;

  const _Alerta(this.icono, this.color, this.texto, this.alTocar);
}

class _TarjetaKpi extends StatelessWidget {
  final _Kpi k;

  const _TarjetaKpi(this.k);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: k.onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: k.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(k.icono, size: 20, color: k.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      k.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        k.valor,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      k.detalle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

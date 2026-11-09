import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../models/config_impresora.dart';
import '../services/api_client.dart';
import '../services/impresion_service.dart';
import '../theme/app_theme.dart';
import '../utils/abrir_enlace.dart';
import 'app_select.dart';
import 'app_toast.dart';
import 'campo_texto.dart';
import 'config_widgets.dart';
import 'logo_tickets_editor.dart';
import 'plantillas_impresion_editor.dart';
import 'inventario/inventario_comun.dart' show EtiquetaFila, confirmarAccion;
import 'barra_desplazamiento.dart';

// Configuración > Impresoras (solo administrador): estado de la impresora de
// cocina y de caja, sus IP, qué datos lleva la comanda, el logo de caja y la
// cola de impresión.
class ImpresorasConfig extends StatefulWidget {
  const ImpresorasConfig({super.key});

  @override
  State<ImpresorasConfig> createState() => _ImpresorasConfigState();
}

class _ImpresorasConfigState extends State<ImpresorasConfig> {
  final _servicio = ImpresionService.instance;
  final _cocinaIp = TextEditingController();
  final _cajaIp = TextEditingController();

  ConfigImpresora? _cfg;
  EstadoImpresoras? _estado;
  ColaImpresion? _cola;
  bool _cargando = true;
  bool _guardando = false;
  String? _errorCarga;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
    // El estado hace ping a las impresoras: se refresca solo cada tanto.
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) _cargarEstadoYCola();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cocinaIp.dispose();
    _cajaIp.dispose();
    super.dispose();
  }

  String _mensaje(Object e) => e is ApiException
      ? e.message
      : e.toString().replaceFirst('Exception: ', '');

  Future<void> _cargarTodo() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final cfg = await _servicio.obtenerConfig();
      if (!mounted) return;
      _cfg = cfg;
      _cocinaIp.text = cfg.cocinaIp;
      _cajaIp.text = cfg.cajaIp;
    } catch (e) {
      _errorCarga = _mensaje(e);
    }
    await _cargarEstadoYCola();
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _cargarEstadoYCola() async {
    try {
      final r = await Future.wait([
        _servicio.obtenerEstado(),
        _servicio.obtenerCola(),
      ]);
      if (!mounted) return;
      setState(() {
        _estado = r[0] as EstadoImpresoras;
        _cola = r[1] as ColaImpresion;
      });
    } catch (_) {
      // Se conserva lo último que se vio.
    }
  }

  // Guarda solo lo que cambió y vuelve a leer la configuración.
  Future<void> _guardar(Map<String, dynamic> cambios, {String? aviso}) async {
    setState(() => _guardando = true);
    try {
      await _servicio.actualizarConfig(cambios);
      final cfg = await _servicio.obtenerConfig();
      if (!mounted) return;
      setState(() => _cfg = cfg);
      if (aviso != null) showAppToast(context, aviso, type: ToastType.success);
      _cargarEstadoYCola();
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'No se pudo guardar: ${_mensaje(e)}',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // Acepta "192.168.0.40" y le agrega el puerto de las ticketeras (9100).
  String? _normalizarIp(String texto) {
    final t = texto.trim();
    if (!RegExp(r'^[\w.\-]+(:\d{1,5})?$').hasMatch(t)) return null;
    return t.contains(':') ? t : '$t:9100';
  }

  Future<void> _guardarIp({required bool cocina}) async {
    final ip = _normalizarIp((cocina ? _cocinaIp : _cajaIp).text);
    if (ip == null) {
      showAppToast(
        context,
        'Escribe la IP con el formato 192.168.0.40:9100.',
        type: ToastType.error,
      );
      return;
    }
    (cocina ? _cocinaIp : _cajaIp).text = ip;
    await _guardar({
      cocina ? 'cocina_ip' : 'caja_ip': ip,
    }, aviso: 'IP de ${cocina ? 'cocina' : 'caja'} guardada.');
  }

  Future<void> _probar(String destino) async {
    try {
      await _servicio.imprimirPrueba(destino);
      if (!mounted) return;
      showAppToast(
        context,
        'Ticket de prueba enviado a la impresora de $destino.',
        type: ToastType.success,
      );
      _cargarEstadoYCola();
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'No se pudo imprimir la prueba: ${_mensaje(e)}',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _abrirCajon() async {
    try {
      await _servicio.abrirCajon();
      if (mounted) {
        showAppToast(context, 'Cajón abierto.', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'No se pudo abrir el cajón: ${_mensaje(e)}',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _pausar(bool pausar) async {
    setState(() => _guardando = true);
    try {
      await _servicio.pausarCola(pausar);
      final cfg = await _servicio.obtenerConfig();
      if (!mounted) return;
      setState(() => _cfg = cfg);
      showAppToast(
        context,
        pausar
            ? 'Cola pausada: los pedidos se guardan pero no se imprimen.'
            : 'Cola reanudada.',
        type: ToastType.info,
      );
      _cargarEstadoYCola();
    } catch (e) {
      if (mounted) {
        showAppToast(context, _mensaje(e), type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cancelarPendientes() async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Cancelar trabajos pendientes',
      mensaje:
          'Se descartan las comandas que están esperando impresora (por '
          'ejemplo, tras un corte de luz) y no se imprimirán. Los pedidos no '
          'se tocan.',
      etiqueta: 'Cancelar pendientes',
    );
    if (!ok) return;
    try {
      final n = await _servicio.cancelarPendientes();
      if (!mounted) return;
      showAppToast(
        context,
        n == 0
            ? 'No había trabajos pendientes.'
            : '$n trabajo(s) pendiente(s) cancelado(s).',
        type: ToastType.info,
      );
      _cargarEstadoYCola();
    } catch (e) {
      if (mounted) showAppToast(context, _mensaje(e), type: ToastType.error);
    }
  }

  Future<void> _reintentar(TrabajoImpresion t) async {
    try {
      await _servicio.reintentarTrabajo(t.id);
      if (!mounted) return;
      showAppToast(
        context,
        'Se volverá a intentar imprimir ${t.codigoOrden}.',
        type: ToastType.info,
      );
      _cargarEstadoYCola();
    } catch (e) {
      if (mounted) showAppToast(context, _mensaje(e), type: ToastType.error);
    }
  }

  // ------------------------------------------------------------------ UI

  Widget _chip(bool habilitada, bool conectada, {required bool cargando}) {
    if (!habilitada) return const EtiquetaFila('Desactivada');
    if (cargando) return const EtiquetaFila('Comprobando…');
    return conectada
        ? const EtiquetaFila('Conectada', color: AppColors.primaryGreen)
        : const EtiquetaFila('Sin conexión', color: AppColors.error);
  }

  Widget _filaImpresora({
    required String nombre,
    required String ip,
    required bool habilitada,
    required bool conectada,
    required String destino,
    VoidCallback? extra,
    String? etiquetaExtra,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _chip(habilitada, conectada, cargando: _estado == null),
                  ],
                ),
                if (ip.isNotEmpty)
                  Text(
                    ip,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          if (extra != null)
            TextButton(onPressed: extra, child: Text(etiquetaExtra ?? '')),
          OutlinedButton.icon(
            onPressed: habilitada ? () => _probar(destino) : null,
            icon: const Icon(LucideIcons.printer, size: 15),
            label: const Text('Probar'),
          ),
        ],
      ),
    );
  }

  Widget _filaIp({
    required String etiqueta,
    required TextEditingController controlador,
    required String guardada,
    required bool cocina,
  }) {
    final cambio = controlador.text.trim() != guardada;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: CampoTexto(
              controller: controlador,
              keyboardType: TextInputType.text,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: etiqueta,
                hintText: cocina
                    ? '192.168.0.40:9100'
                    : 'POS-80 (USB) o 192.168.0.52:9100',
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: (_guardando || !cambio)
                ? null
                : () => _guardarIp(cocina: cocina),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _switch(String titulo, String descripcion, bool valor, String campo) =>
      FilaSwitch(
        titulo: titulo,
        descripcion: descripcion,
        valor: valor,
        onChanged: _guardando ? null : (v) => _guardar({campo: v}),
      );

  Widget _filaTrabajo(TrabajoImpresion t) {
    final color = switch (t.estado) {
      'completado' => AppColors.primaryGreen,
      'error' => AppColors.error,
      'pendiente' || 'imprimiendo' => AppColors.warning,
      _ => Colors.grey,
    };
    final hora = t.creado == null
        ? ''
        : '${t.creado!.hour.toString().padLeft(2, '0')}:${t.creado!.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      t.codigoOrden.isEmpty ? '—' : t.codigoOrden,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    EtiquetaFila(t.etiquetaEstado, color: color),
                  ],
                ),
                Text(
                  [
                    t.etiquetaTipo,
                    if (hora.isNotEmpty) hora,
                    if (t.intentos > 0) '${t.intentos} intento(s)',
                    if ((t.error ?? '').isNotEmpty) t.error!,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => abrirEnlace(_servicio.urlPdfJob(t.id)),
            icon: const Icon(LucideIcons.fileText, size: 14),
            label: const Text('Ver PDF'),
          ),
          if (t.sePuedeReintentar)
            TextButton(
              onPressed: () => _reintentar(t),
              child: const Text('Reintentar'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    final pad = AppBreakpoints.esMobile(context) ? 16.0 : 32.0;
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: cfg == null
              ? _sinConfig()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _seccionEstado(cfg),
                    const SizedBox(height: 32),
                    _seccionPruebasPDF(),
                    const SizedBox(height: 32),
                    _seccionCocina(cfg),
                    const SizedBox(height: 32),
                    _seccionCaja(cfg),
                    const SizedBox(height: 32),
                    const PlantillasImpresionEditor(),
                    const SizedBox(height: 32),
                    _seccionCola(cfg),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _sinConfig() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        Text(
          _cargando
              ? 'Cargando…'
              : 'No se pudo leer la configuración de impresoras'
                    '${_errorCarga == null ? '' : ': $_errorCarga'}',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        if (!_cargando) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _cargarTodo,
            child: const Text('Reintentar'),
          ),
        ],
      ],
    ),
  );

  Widget _seccionEstado(ConfigImpresora cfg) {
    final e = _estado;
    return SeccionConfig(
      titulo: 'Estado de las impresoras',
      descripcion:
          'Las comandas salen solas a cocina al tomar el pedido y al agregarle '
          'productos. Aquí ves si cada impresora responde en la red.',
      filas: [
        _filaImpresora(
          nombre: 'Cocina',
          ip: e?.cocinaIp ?? cfg.cocinaIp,
          habilitada: cfg.cocinaHabilitada,
          conectada: e?.cocinaConectada ?? false,
          destino: 'cocina',
        ),
        _filaImpresora(
          nombre: 'Caja',
          ip: e?.cajaIp ?? cfg.cajaIp,
          habilitada: cfg.cajaHabilitada,
          conectada: e?.cajaConectada ?? false,
          destino: 'caja',
          extra: cfg.cajaHabilitada ? _abrirCajon : null,
          etiquetaExtra: 'Abrir cajón',
        ),
      ],
    );
  }

  Widget _seccionPruebasPDF() {
    final tipos = [
      ('comanda', 'Comanda de Cocina', LucideIcons.utensils),
      ('precuenta', 'Precuenta de Consumo', LucideIcons.receipt),
      ('ticket', 'Ticket de Venta (Interno)', LucideIcons.ticket),
      ('boleta', 'Boleta Electrónica (QR SUNAT)', LucideIcons.qrCode),
      ('factura', 'Factura Electrónica (QR SUNAT)', LucideIcons.building2),
    ];

    return SeccionConfig(
      titulo: 'Modo Pruebas: Ver Impresiones en PDF',
      descripcion:
          'Genera y visualiza en PDF el flujo exacto de bytes ESC/POS que se envía al cabezal térmico de 80mm, aplicando todas las configuraciones y plantillas actuales.',
      filas: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (tipo, nombre, icono) in tipos)
                OutlinedButton.icon(
                  onPressed: () => abrirEnlace(_servicio.urlPdfMuestra(tipo)),
                  icon: Icon(icono, size: 16),
                  label: Text(nombre),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: () => abrirEnlace(_servicio.urlPdfUltimo()),
                icon: const Icon(LucideIcons.fileText, size: 16),
                label: const Text('Último Ticket Impreso'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seccionCocina(ConfigImpresora cfg) {
    return SeccionConfig(
      titulo: 'Comanda de cocina',
      descripcion:
          'La comanda no lleva precios ni totales. Elige qué más se imprime.',
      filas: [
        _switch(
          'Impresora de cocina activa',
          'Apagada: las comandas no se mandan a imprimir.',
          cfg.cocinaHabilitada,
          'cocina_habilitada',
        ),
        _filaIp(
          etiqueta: 'IP y puerto de la impresora de cocina',
          controlador: _cocinaIp,
          guardada: cfg.cocinaIp,
          cocina: true,
        ),
        _switch(
          'Mostrar el mozo',
          'Nombre de quien tomó el pedido.',
          cfg.cocinaMostrarMozo,
          'cocina_mostrar_mozo',
        ),
        _switch(
          'Mostrar fecha y hora',
          'Cuándo se tomó el pedido.',
          cfg.cocinaMostrarFecha,
          'cocina_mostrar_fecha',
        ),
        _switch(
          'Mostrar las notas',
          'La nota del pedido y la de cada producto.',
          cfg.cocinaMostrarNotas,
          'cocina_mostrar_notas',
        ),
        _switch(
          'Marcar los productos para llevar',
          'Indica "PARA LLEVAR / TAPER" en cada producto que va en táper.',
          cfg.cocinaMostrarTaper,
          'cocina_mostrar_taper',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Tamaño de letra',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(
                width: 170,
                child: AppSelect<String>(
                  compacto: true,
                  value: cfg.cocinaTamanoLetra,
                  items: const [
                    AppSelectItem(value: 'doble', label: 'Grande (doble)'),
                    AppSelectItem(value: 'normal', label: 'Normal'),
                  ],
                  onChanged: (v) {
                    if (v != null && !_guardando) {
                      _guardar({'cocina_tamano_letra': v});
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seccionCaja(ConfigImpresora cfg) {
    return SeccionConfig(
      titulo: 'Tickets de caja',
      filas: [
        _switch(
          'Impresora de caja activa',
          'Apagada: no se imprimen tickets de caja.',
          cfg.cajaHabilitada,
          'caja_habilitada',
        ),
        _filaIp(
          etiqueta: 'Nombre de impresora (USB / Driver Windows) o IP',
          controlador: _cajaIp,
          guardada: cfg.cajaIp,
          cocina: false,
        ),
        _switch(
          'Imprimir el logo',
          'Arriba de cada ticket de caja.',
          cfg.cajaImprimirLogo,
          'caja_imprimir_logo',
        ),
        const LogoTicketsEditor(),
      ],
    );
  }

  Widget _seccionCola(ConfigImpresora cfg) {
    final e = _estado;
    final cola = _cola;
    final trabajos = cola?.trabajos ?? const <TrabajoImpresion>[];
    final pendientes = cola?.pendientes ?? e?.colaPendientes ?? 0;
    return SeccionConfig(
      titulo: 'Cola de impresión',
      descripcion:
          '${cola?.completados ?? e?.colaCompletados ?? 0} impresos · '
          '$pendientes pendientes · '
          '${cola?.conError ?? e?.colaErrores ?? 0} con error',
      filas: [
        FilaSwitch(
          titulo: 'Pausar la cola',
          descripcion:
              'Los pedidos se siguen guardando pero no se mandan a imprimir '
              'hasta reanudarla.',
          valor: cfg.pausarCola,
          onChanged: _guardando ? null : _pausar,
        ),
        _switch(
          'Omitir lo pendiente de días anteriores',
          'Si la impresora se enciende otro día, esas comandas no se imprimen '
              '(ahorra papel).',
          cfg.descartarAntiguosDias,
          'descartar_antiguos_dias',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Cancelar los trabajos pendientes',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton(
                onPressed: pendientes == 0 ? null : _cancelarPendientes,
                child: const Text('Cancelar pendientes'),
              ),
            ],
          ),
        ),
        if (trabajos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Aún no hay trabajos de impresión.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          )
        else
          _ListaTrabajos(trabajos: trabajos, fila: _filaTrabajo),
      ],
    );
  }
}

// Trabajos de impresión: lista con scroll interno y paginación de 10 en 10.
class _ListaTrabajos extends StatefulWidget {
  final List<TrabajoImpresion> trabajos;
  final Widget Function(TrabajoImpresion) fila;

  const _ListaTrabajos({required this.trabajos, required this.fila});

  @override
  State<_ListaTrabajos> createState() => _ListaTrabajosState();
}

class _ListaTrabajosState extends State<_ListaTrabajos> {
  static const _porPagina = 10;
  int _pagina = 0;

  int get _paginas =>
      (widget.trabajos.length / _porPagina).ceil().clamp(1, 9999);

  @override
  Widget build(BuildContext context) {
    final total = widget.trabajos.length;
    final actual = _pagina.clamp(0, _paginas - 1);
    final ini = actual * _porPagina;
    final fin = (ini + _porPagina).clamp(0, total);
    final visibles = widget.trabajos.sublist(ini, fin);

    Widget boton(String texto, VoidCallback? onTap, {bool activo = false}) =>
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minWidth: 32),
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activo ? AppColors.primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: activo ? AppColors.primaryGreen : Colors.grey.shade300,
                ),
              ),
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: activo
                      ? Colors.white
                      : (onTap == null ? Colors.grey.shade400 : Colors.black87),
                ),
              ),
            ),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Scroll interno, con aire a los lados.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: BarraDesplazamiento(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                children: [for (final t in visibles) widget.fila(t)],
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Mostrando ${ini + 1}-$fin de $total',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
                boton(
                  '‹',
                  actual > 0
                      ? () => setState(() => _pagina = actual - 1)
                      : null,
                ),
                for (var i = 0; i < _paginas; i++)
                  boton(
                    '${i + 1}',
                    () => setState(() => _pagina = i),
                    activo: i == actual,
                  ),
                boton(
                  '›',
                  actual < _paginas - 1
                      ? () => setState(() => _pagina = actual + 1)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

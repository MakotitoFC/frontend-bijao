import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../models/config_impresora.dart';
import '../services/api_client.dart';
import '../services/impresion_service.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';
import 'app_toast.dart';
import 'campo_texto.dart';
import 'config_widgets.dart';
import 'logo_tickets_editor.dart';
import 'inventario/inventario_comun.dart' show EtiquetaFila, confirmarAccion;

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
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: etiqueta,
                hintText: '192.168.0.40:9100',
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
                    _seccionCocina(cfg),
                    const SizedBox(height: 32),
                    _seccionCaja(cfg),
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
      accion: OutlinedButton.icon(
        onPressed: _cargarEstadoYCola,
        icon: const Icon(LucideIcons.refreshCw, size: 15),
        label: const Text('Actualizar'),
      ),
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
          etiqueta: 'IP y puerto de la impresora de caja',
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
          for (final t in trabajos.take(15)) _filaTrabajo(t),
      ],
    );
  }
}

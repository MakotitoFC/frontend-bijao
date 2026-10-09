import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/mesas_store.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../data/usuarios_store.dart';
import '../models/app_role.dart';
import '../models/mesa.dart';
import '../models/pedido.dart';
import '../models/usuario.dart';
import '../models/zona.dart';
import '../services/catalog_service.dart';
import '../services/pedido_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../widgets/app_select.dart';
import '../widgets/app_toast.dart';
import '../widgets/marching_ants_border.dart';
import '../widgets/mesa_card.dart';
import '../widgets/mesa_form_dialog.dart';
import '../widgets/app_search_field.dart';
import '../widgets/zona_form_dialog.dart';

const _naranjaUnir = Color(0xFFF07F13);
const _fondoSala = Color(0xFFF6F8FB);
const _trazoSala = Color(0xFF9AA7B8);

// Pedido activo (no pagado/anulado/devuelto) de una mesa, considerando mesas unidas
// (`todasLasMesas`). Usado por el plano (T-1, T-2...).
Pedido? _pedidoActivoDeMesa(int mesaNumero) {
  for (final p in pedidos) {
    if (p.todasLasMesas.contains(mesaNumero) &&
        p.estado != 'pagado' &&
        p.estado != 'anulado' &&
        p.estado != 'devuelto' &&
        p.estado != 'cancelado') {
      return p;
    }
  }
  return null;
}

String _horaDe(DateTime fecha) =>
    '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

// Mesero que tomó el pedido (pedidos.usuario_id): así se ve, mesa por mesa,
// cuántas está atendiendo cada uno.
String? _meseroDe(Pedido? pedido) {
  if (pedido?.usuarioId == null) return null;
  for (final u in usuarios) {
    if (u.id == pedido!.usuarioId) return u.nombre;
  }
  return null;
}

// Plano de mesas (tabla `mesa`): visualización y gestión según RBAC.
class MesasPlano extends StatefulWidget {
  final ValueChanged<Mesa> onSeleccionarMesa;
  final Usuario? usuario;

  const MesasPlano({
    super.key,
    required this.onSeleccionarMesa,
    this.usuario,
  });

  @override
  State<MesasPlano> createState() => _MesasPlanoState();
}

class _MesasPlanoState extends State<MesasPlano> {
  bool get _puedeCrearMesa =>
      widget.usuario == null ||
      widget.usuario!.rol == AppRole.administrador ||
      widget.usuario!.tienePermiso('CREAR.MESA');

  bool get _puedeEditarMesa =>
      widget.usuario == null ||
      widget.usuario!.rol == AppRole.administrador ||
      widget.usuario!.tienePermiso('UPDATE.MESA');

  bool get _puedeEliminarMesa =>
      widget.usuario == null ||
      widget.usuario!.rol == AppRole.administrador ||
      widget.usuario!.tienePermiso('DELETE.MESA');

  bool get _puedeCrearZona =>
      widget.usuario == null ||
      widget.usuario!.rol == AppRole.administrador ||
      widget.usuario!.tienePermiso('CREAR.ZONA');

  bool get _puedeEditarZona =>
      widget.usuario == null ||
      widget.usuario!.rol == AppRole.administrador ||
      widget.usuario!.tienePermiso('UPDATE.ZONA');

  bool get _puedeEliminarZona =>
      widget.usuario == null ||
      widget.usuario!.rol == AppRole.administrador ||
      widget.usuario!.tienePermiso('DELETE.ZONA');

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    CatalogService.instance.cargarZonas().then((_) {
      if (mounted) setState(() {});
    });
    CatalogService.instance.cargarMesas().then((_) {
      if (mounted) setState(() {});
    });
    PedidoService.instance.cargarPedidos().then((_) {
      if (mounted) setState(() {});
    });
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        CatalogService.instance.cargarMesas().then((_) {
          if (mounted) setState(() {});
        });
        PedidoService.instance.cargarPedidos().then((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  bool _modoUnion = false;
  final Set<int> _paraUnir = {};
  String? _zona;
  String? _estado;
  final _busqueda = TextEditingController();

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  // Coincide con el número de mesa (solo o como "mesa 3") o con el cliente del
  // pedido activo.
  bool _coincideBusqueda(Mesa mesa) {
    final q = _busqueda.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final numeros = [mesa.numero, ...otrasUnidas(mesa.numero)];
    if (numeros.any((n) => 'mesa $n'.contains(q) || '$n' == q)) return true;
    final cliente = _pedidoActivoDeMesa(mesa.numero)?.clienteNombre;
    return cliente != null && cliente.toLowerCase().contains(q);
  }

  void _seleccionarMesa(Mesa mesa) {
    if (_modoUnion) {
      _alternarSeleccionParaUnir(mesa);
      return;
    }
    widget.onSeleccionarMesa(mesa);
  }

  void _alternarSeleccionParaUnir(Mesa mesa) {
    if (mesa.estado != 'disponible' && mesa.estado != 'libre' || estaUnida(mesa.numero)) return;
    setState(() {
      if (!_paraUnir.remove(mesa.numero)) _paraUnir.add(mesa.numero);
    });
  }

  void _confirmarUnion() {
    if (_paraUnir.length < 2) return;
    setState(() {
      unirMesas(_paraUnir.toList());
      _paraUnir.clear();
      _modoUnion = false;
    });
  }

  void _cancelarUnion() {
    setState(() {
      _paraUnir.clear();
      _modoUnion = false;
    });
  }

  Future<void> _nuevaMesa() async {
    final datos = await showBlurDialog<MesaFormResultado>(
      context: context,
      builder: (_) => MesaFormDialog(zonaInicial: _zonaActual),
    );
    if (datos == null || !mounted) return;
    try {
      await CatalogService.instance.crearMesa(
        numero: datos.numero,
        capacidad: datos.capacidad,
        zona: datos.zona,
      );
      setState(() {});
      if (!mounted) return;
      showAppToast(context, 'Mesa ${datos.numero} creada.', type: ToastType.success);
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'Error al crear mesa: $e', type: ToastType.error);
    }
  }

  Future<void> _editarMesa(Mesa mesa) async {
    final datos = await showBlurDialog<MesaFormResultado>(
      context: context,
      builder: (_) => MesaFormDialog(mesa: mesa),
    );
    if (datos == null || !mounted) return;
    try {
      if (datos.eliminar) {
        if (!_puedeEliminarMesa) {
          showAppToast(context, 'No tienes permiso para eliminar mesas.', type: ToastType.error);
          return;
        }
        await CatalogService.instance.eliminarMesa(mesa.id, mesa.numero);
        _paraUnir.remove(mesa.numero);
        setState(() {});
        if (!mounted) return;
        showAppToast(context, 'Mesa ${mesa.numero} eliminada.', type: ToastType.info);
      } else {
        await CatalogService.instance.actualizarMesa(
          mesa.id,
          numero: datos.numero,
          capacidad: datos.capacidad,
          zona: datos.zona,
          estado: datos.estado,
        );
        setState(() {});
        if (!mounted) return;
        showAppToast(context, 'Mesa ${datos.numero} actualizada.', type: ToastType.success);
      }
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'Error al actualizar mesa: $e', type: ToastType.error);
    }
  }

  Future<void> _nuevaZona() async {
    final datos = await showBlurDialog<ZonaFormResultado>(
      context: context,
      builder: (_) => const ZonaFormDialog(),
    );
    if (datos == null || !mounted) return;
    try {
      final nueva = await CatalogService.instance.crearZona(
        nombre: datos.nombre,
        estado: datos.estado,
      );
      setState(() {
        _zona = nueva.zona;
      });
      if (!mounted) return;
      showAppToast(context, 'Zona "${nueva.zona}" creada.', type: ToastType.success);
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'Error al crear zona: $e', type: ToastType.error);
    }
  }

  Future<void> _editarZona(String zona) async {
    final zonaObj = CatalogService.instance.zonas.firstWhere(
      (z) => z.zona.toLowerCase() == zona.toLowerCase(),
      orElse: () => Zona(id: '', zona: zona, estado: true),
    );

    final datos = await showBlurDialog<ZonaFormResultado>(
      context: context,
      builder: (_) => ZonaFormDialog(
        zona: zona,
        estadoInicial: zonaObj.estado,
      ),
    );
    if (datos == null || !mounted) return;

    if (datos.eliminar) {
      if (!_puedeEliminarZona) {
        showAppToast(context, 'No tienes permiso para eliminar zonas.', type: ToastType.error);
        return;
      }
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Eliminar zona "$zona"'),
          content: Text(
            mesasDeZona(zona).isEmpty
                ? '¿Seguro que deseas eliminar esta zona?'
                : '¿Seguro? También se eliminarán sus ${mesasDeZona(zona).length} mesa(s).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Volver'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
      try {
        if (zonaObj.id.isNotEmpty) {
          await CatalogService.instance.eliminarZona(zonaObj.id, zona);
        } else {
          eliminarZona(zona);
        }
        setState(() {
          if (_zona == zona) _zona = null;
        });
        if (!mounted) return;
        showAppToast(context, 'Zona "$zona" eliminada.', type: ToastType.info);
      } catch (e) {
        if (!mounted) return;
        showAppToast(context, 'Error al eliminar zona: $e', type: ToastType.error);
      }
      return;
    }

    try {
      if (zonaObj.id.isNotEmpty) {
        final act = await CatalogService.instance.actualizarZona(
          zonaObj.id,
          nombre: datos.nombre,
          estado: datos.estado,
        );
        setState(() {
          renombrarZona(zona, act.zona);
          if (_zona == zona) _zona = act.zona;
        });
      } else {
        setState(() {
          renombrarZona(zona, datos.nombre);
          if (_zona == zona) _zona = datos.nombre;
        });
      }
      if (!mounted) return;
      showAppToast(context, 'Zona actualizada.', type: ToastType.success);
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'Error al actualizar zona: $e', type: ToastType.error);
    }
  }

  void _desunir(int numero) {
    setState(() => separarMesas(numero));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _barraSuperior(),
        Expanded(child: _croquis()),
      ],
    );
  }

  // Zona mostrada: solo una sala a la vez, que se cambia con el select.
  String get _zonaActual {
    final activas = CatalogService.instance.zonas
        .where((z) => z.estado)
        .map((z) => z.zona)
        .toList();
    final lista = activas.isNotEmpty ? activas : zonasMesas;
    return _zona != null && lista.contains(_zona)
        ? _zona!
        : (lista.isNotEmpty ? lista.first : 'Salón Principal');
  }

  // Selector de zona/estado + Unir mesas / Mesa / Zona.
  Widget _barraSuperior() {
    final activas = CatalogService.instance.zonas
        .where((z) => z.estado)
        .map((z) => z.zona)
        .toList();
    final listaZonas = activas.isNotEmpty ? activas : zonasMesas;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AppSearchField(
            hint: 'Buscar mesa o cliente...',
            controller: _busqueda,
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(
            width: 170,
            child: AppSelect<String>(
              value: _zonaActual,
              compacto: true,
              items: [
                for (final z in listaZonas) AppSelectItem(value: z, label: z),
              ],
              onChanged: (v) => setState(() => _zona = v),
              hint: 'Zona',
            ),
          ),
          SizedBox(
            width: 190,
            child: AppSelect<String?>(
              value: _estado,
              compacto: true,
              items: const [
                AppSelectItem(value: null, label: 'Todos los estados'),
                AppSelectItem(value: 'disponible', label: 'Disponible'),
                AppSelectItem(value: 'ocupada', label: 'Ocupada'),
              ],
              onChanged: (v) => setState(() => _estado = v),
              hint: 'Todos los estados',
            ),
          ),
          FilledButton.icon(
            onPressed: () => setState(() {
              _modoUnion = !_modoUnion;
              _paraUnir.clear();
            }),
            style: FilledButton.styleFrom(
              backgroundColor: _modoUnion
                  ? const Color(0xFFD96F0A)
                  : _naranjaUnir,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            icon: const Icon(LucideIcons.link, size: 16),
            label: const Text('Unir mesas'),
          ),
          if (_puedeCrearMesa) _botonNuevaMesa(),
          if (_puedeCrearZona) _botonNuevaZona(),
        ],
      ),
    );
  }

  Widget _botonNuevaMesa() {
    return FilledButton.icon(
      onPressed: _nuevaMesa,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      icon: const Icon(Icons.add, size: 16),
      label: const Text(
        'Mesa',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  Widget _botonNuevaZona() {
    return OutlinedButton.icon(
      onPressed: _nuevaZona,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
        side: const BorderSide(color: AppColors.primaryGreen),
      ),
      icon: const Icon(Icons.add, size: 16),
      label: const Text(
        'Zona',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  // Croquis: la sala de la zona elegida, ocupando el espacio disponible.
  Widget _croquis() {
    final zona = _zonaActual;
    return LayoutBuilder(
      builder: (context, c) {
        // Escala del dibujo según el ancho disponible.
        final scale = c.maxWidth >= 640
            ? 1.0
            : (c.maxWidth >= 420 ? 0.82 : 0.68);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: _sala(zona, scale, c.maxWidth - 32),
        );
      },
    );
  }

  // Sala de una zona: contenedor de trazo gris (naranja al unir mesas, con una
  // pestaña de acciones encima). Todo su contenido, incluido el rótulo de la
  // zona, hace scroll interno con la barra oculta.
  Widget _sala(String zona, double scale, double anchoDisponible) {
    final visibles = mesas
        .where(
          (m) {
            final match = CatalogService.instance.zonas.firstWhere(
              (z) => z.zona.toLowerCase() == m.zona.toLowerCase(),
              orElse: () => const Zona(id: '', zona: '', estado: true),
            );
            if (!match.estado) return false;

            return m.zona == zona &&
                esAnclaDeGrupo(m.numero) &&
                (_estado == null || m.estado == _estado) &&
                _coincideBusqueda(m);
          },
        )
        .toList();
    final total = mesasDeZona(zona).length;
    final union = _modoUnion;
    final colorTrazo = union ? _naranjaUnir : Colors.grey.shade400;
    final grosor = union ? 1.5 : 1.0;
    final altoPestana = union ? _altoPestana : 0.0;
    final Widget contenido = visibles.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Text(
                total == 0
                    ? 'Zona sin mesas. Agrega una con "+ Mesa".'
                    : 'Sin mesas para este filtro o búsqueda',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ),
          )
        : Center(
            child: Wrap(
              spacing: 24 * scale,
              runSpacing: 22 * scale,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                for (final mesa in visibles)
                  _mesaCard(mesa, scale, anchoDisponible - 32),
              ],
            ),
          );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: altoPestana,
          child: Container(
            decoration: BoxDecoration(
              color: _fondoSala,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorTrazo, width: grosor),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: CustomPaint(
                painter: _SalaPainter(),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context)
                            .copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            12 + AppSizes.control + 14,
                            16,
                            24,
                          ),
                          child: contenido,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 16,
                      child: _cabeceraSala(zona, total),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (union)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: anchoDisponible),
                child: _pestanaUnion(grosor),
              ),
            ),
          ),
      ],
    );
  }

  static const double _altoPestana = 46;

  Widget _pestanaUnion(double grosor) {
    final n = _paraUnir.length;
    const blanco = Colors.white;
    // Tag de cantidad y botones comparten alto, más bajo que el estándar.
    const alto = 30.0;
    const texto = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
    final estiloBoton = FilledButton.styleFrom(
      backgroundColor: blanco,
      foregroundColor: _naranjaUnir,
      disabledBackgroundColor: blanco.withValues(alpha: 0.6),
      disabledForegroundColor: _naranjaUnir.withValues(alpha: 0.6),
      minimumSize: const Size(0, alto),
      maximumSize: const Size(double.infinity, alto),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      textStyle: texto,
      elevation: 0,
    );
    return CustomPaint(
      painter: _PestanaPainter(
        relleno: _naranjaUnir,
        trazo: _naranjaUnir,
        grosor: grosor,
        radio: 10,
      ),
      child: SizedBox(
        height: _altoPestana + grosor,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 12, grosor),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  n < 2
                      ? 'Elige 2 o más mesas libres para unir'
                      : 'Mesas elegidas para unir',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: blanco,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                height: alto,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.tag),
                  border: Border.all(color: blanco),
                ),
                child: Text(
                  n == 1 ? '1 mesa' : '$n mesas',
                  style: texto.copyWith(color: blanco),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: n >= 2 ? _confirmarUnion : null,
                style: estiloBoton,
                child: const Text('Unir'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _cancelarUnion,
                style: estiloBoton.copyWith(
                  backgroundColor: const WidgetStatePropertyAll(
                    AppColors.navbar,
                  ),
                  foregroundColor: const WidgetStatePropertyAll(blanco),
                ),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Rótulo de la sala: nombre de la zona, cantidad de mesas y editar.
  Widget _cabeceraSala(String zona, int total) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: AppSizes.control,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.tag),
            border: Border.all(color: _trazoSala),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.layoutDashboard,
                size: 14,
                color: _trazoSala,
              ),
              const SizedBox(width: 8),
              Text(
                zona.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF4A5568),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        if (_puedeEditarZona) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: 'Editar zona',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.tag),
              onTap: () => _editarZona(zona),
              child: Container(
                width: AppSizes.control,
                height: AppSizes.control,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.tag),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Icon(
                  LucideIcons.pencil,
                  size: 15,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _mesaCard(Mesa mesa, double scale, double anchoDisponible) {
    final ocupada = mesa.estado == 'ocupada';
    final pedido = ocupada ? _pedidoActivoDeMesa(mesa.numero) : null;
    final unidas = otrasUnidas(mesa.numero);
    final seleccionadaParaUnir = _paraUnir.contains(mesa.numero);
    // Mesa unida que no entra en el ancho disponible: se muestra compacta.
    final totalSillas = MesaCard.totalSillasDe(mesa.numero, unidas);
    final simplificada =
        unidas.isNotEmpty &&
        (scale < 1 || totalSillas > 8) &&
        (totalSillas * 34 * scale) > anchoDisponible * 0.85;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _modoUnion && !mesa.estaLibre ? 0.4 : 1,
      child: seleccionadaParaUnir
          ? MarchingAntsBorder(
              radius: 34,
              color: Colors.grey.shade400,
              child: MesaCard(
                numero: mesa.numero,
                zona: mesa.zona,
                ocupada: ocupada,
                estado: mesa.estado,
                horaInicio: pedido != null ? _horaDe(pedido.fechaPedido) : null,
                monto: pedido != null ? totalDePedido(pedido.id) : null,
                mesero: _meseroDe(pedido),
                onTap: () => _seleccionarMesa(mesa),
                scale: scale,
                simplificada: simplificada,
              ),
            )
          : MesaCard(
              key: ValueKey('mesa-${mesa.numero}'),
              numero: mesa.numero,
              zona: mesa.zona,
              unidas: unidas,
              ocupada: ocupada,
              estado: mesa.estado,
              horaInicio: pedido != null ? _horaDe(pedido.fechaPedido) : null,
              monto: pedido != null ? totalDePedido(pedido.id) : null,
              mesero: _meseroDe(pedido),
              onTap: () => _seleccionarMesa(mesa),
              onEditar: (_modoUnion || !_puedeEditarMesa) ? null : () => _editarMesa(mesa),
              onDesunir: unidas.isNotEmpty && mesa.estaLibre
                  ? () => _desunir(mesa.numero)
                  : null,
              scale: scale,
              simplificada: simplificada,
            ),
    );
  }
}

// Fondo de plano arquitectónico: cuadrícula tenue.
class _SalaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cuadricula = Paint()
      ..color = _trazoSala.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    const paso = 26.0;
    for (var x = paso; x < size.width; x += paso) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), cuadricula);
    }
    for (var y = paso; y < size.height; y += paso) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), cuadricula);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Pestaña tipo carpeta: esquinas superiores redondeadas, sin trazo en la base
// para que se funda con el contenedor.
class _PestanaPainter extends CustomPainter {
  final Color relleno;
  final Color trazo;
  final double grosor;
  final double radio;

  const _PestanaPainter({
    required this.relleno,
    required this.trazo,
    required this.grosor,
    required this.radio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final mitad = grosor / 2;
    final w = size.width;
    final h = size.height;
    final contorno = Path()
      ..moveTo(mitad, h)
      ..lineTo(mitad, radio)
      ..quadraticBezierTo(mitad, mitad, radio, mitad)
      ..lineTo(w - radio, mitad)
      ..quadraticBezierTo(w - mitad, mitad, w - mitad, radio)
      ..lineTo(w - mitad, h);
    canvas.drawPath(Path.from(contorno)..close(), Paint()..color = relleno);
    canvas.drawPath(
      contorno,
      Paint()
        ..color = trazo
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor,
    );
  }

  @override
  bool shouldRepaint(covariant _PestanaPainter old) =>
      old.relleno != relleno ||
      old.trazo != trazo ||
      old.grosor != grosor ||
      old.radio != radio;
}

// Vista principal de Mesas conectada al sidebar y navegación principal
class MesasScreen extends StatelessWidget {
  final Usuario usuario;

  const MesasScreen({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: MesasPlano(
        usuario: usuario,
        onSeleccionarMesa: (mesa) => _mostrarOpcionesMesa(context, mesa),
      ),
    );
  }

  Future<void> _mostrarOpcionesMesa(BuildContext context, Mesa mesa) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Mesa ${mesa.numero}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (mesa.estaOcupada
                                ? AppColors.error
                                : AppColors.primaryGreen)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        mesa.estado.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: mesa.estaOcupada ? AppColors.error : AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (mesa.estaOcupada) ...[
                  ListTile(
                    leading: const Icon(LucideIcons.checkCircle2, color: AppColors.primaryGreen),
                    title: const Text('Liberar mesa manualmente'),
                    subtitle: const Text('Marcar la mesa como disponible'),
                    onTap: () async {
                      Navigator.of(sheetCtx).pop();
                      final confirmar = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: Text('¿Liberar Mesa ${mesa.numero}?'),
                          content: const Text('La mesa volverá al estado disponible.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dCtx).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(dCtx).pop(true),
                              child: const Text('Liberar'),
                            ),
                          ],
                        ),
                      );
                      if (confirmar == true && context.mounted) {
                        try {
                          await PedidoService.instance.liberarMesa(mesa.id, mesa.numero);
                          if (context.mounted) {
                            showAppToast(context, 'Mesa ${mesa.numero} liberada a disponible.', type: ToastType.success);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showAppToast(context, 'Error al liberar mesa: $e', type: ToastType.error);
                          }
                        }
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}


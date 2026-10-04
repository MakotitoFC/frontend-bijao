import 'package:flutter/material.dart';

import '../data/configuracion_store.dart';
import '../data/usuarios_store.dart';
import '../models/app_role.dart';
import '../models/horario.dart';
import '../models/usuario.dart';
import '../theme/app_theme.dart';
import '../widgets/app_select.dart';
import '../widgets/app_toast.dart';
import '../widgets/config_widgets.dart';
import '../widgets/pestanas_vista.dart';

// Configuración: submódulos Servicio, Restaurantes, Métodos de pago,
// Usuarios y roles, y Negocio.
class ConfiguracionScreen extends StatefulWidget {
  final Usuario usuario;

  const ConfiguracionScreen({super.key, required this.usuario});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PestanasVista(
        pestanas: [
          (etiqueta: 'Servicio', contenido: (_) => _pagina(_servicio())),
          (
            etiqueta: 'Restaurantes',
            contenido: (_) => _pagina(_restaurantes()),
          ),
          (
            etiqueta: 'Métodos de pago',
            contenido: (_) => _pagina(_metodosPago()),
          ),
          (
            etiqueta: 'Usuarios y roles',
            contenido: (_) => _pagina(_usuarios()),
          ),
          (etiqueta: 'Negocio', contenido: (_) => _pagina(_negocio())),
        ],
      ),
    );
  }

  Widget _pagina(List<Widget> secciones) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < secciones.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                secciones[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Servicio ----------------

  List<Widget> _servicio() {
    return [
      SeccionConfig(
        titulo: 'Tipos de servicio',
        descripcion: 'Qué tipos de pedido se pueden tomar (tipo de servicio).',
        filas: [
          FilaSwitch(
            titulo: 'Servicio en local',
            descripcion: 'Pedidos para comer en las mesas',
            valor: config.servicioLocal,
            onChanged: (v) {
              if (!v && !config.servicioDelivery) return _minimoUno();
              setState(() => config.servicioLocal = v);
            },
          ),
          FilaSwitch(
            titulo: 'Delivery',
            descripcion: 'Pedidos con entrega a domicilio',
            valor: config.servicioDelivery,
            onChanged: (v) {
              if (!v && !config.servicioLocal) return _minimoUno();
              setState(() => config.servicioDelivery = v);
            },
          ),
        ],
      ),
      SeccionConfig(
        titulo: 'Propinas',
        filas: [
          CampoNumeroConfig(
            etiqueta: 'Propina sugerida (botón Propina de los pedidos)',
            valor: config.propinaSugerida,
            sufijo: '%',
            onChanged: (n) => config.propinaSugerida = n,
          ),
        ],
      ),
      SeccionConfig(
        titulo: 'Descuento de empleado',
        filas: [
          FilaSwitch(
            titulo: 'Permitir descuento de empleado',
            descripcion: 'Aparece como opción al tomar el pedido',
            valor: config.descuentoEmpleadoHabilitado,
            onChanged: (v) =>
                setState(() => config.descuentoEmpleadoHabilitado = v),
            extra: CampoNumeroConfig(
              etiqueta: 'Descuento',
              valor: config.descuentoEmpleadoPorcentaje,
              sufijo: '%',
              onChanged: (n) => config.descuentoEmpleadoPorcentaje = n,
            ),
          ),
        ],
      ),
    ];
  }

  void _minimoUno() => showAppToast(
    context,
    'Debe quedar al menos un tipo de servicio activo.',
    type: ToastType.info,
  );

  // ---------------- Restaurantes ----------------

  List<Widget> _restaurantes() {
    return [
      for (var i = 0; i < sedes.length; i++)
        SeccionConfig(
          titulo: 'Restaurante ${i + 1}',
          filas: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  CampoTextoConfig(
                    etiqueta: 'Dirección',
                    valor: sedes[i].direccion,
                    onChanged: (v) =>
                        sedes[i] = sedes[i].copyWith(direccion: v),
                  ),
                  const SizedBox(height: 12),
                  CampoTextoConfig(
                    etiqueta: 'Teléfono',
                    valor: sedes[i].celular ?? '',
                    teclado: TextInputType.phone,
                    onChanged: (v) => sedes[i] = sedes[i].copyWith(celular: v),
                  ),
                ],
              ),
            ),
            FilaSwitch(
              titulo: 'Activo',
              descripcion: 'Si se apaga, el local deja de operar en el sistema',
              valor: sedes[i].activo,
              onChanged: (v) =>
                  setState(() => sedes[i] = sedes[i].copyWith(activo: v)),
            ),
          ],
        ),
    ];
  }

  // ---------------- Métodos de pago ----------------

  List<Widget> _metodosPago() {
    return [
      SeccionConfig(
        titulo: 'Métodos de pago',
        descripcion:
            'Cuáles se ofrecen al cobrar y si llevan un cobro adicional.',
        filas: [
          for (var i = 0; i < mediosPago.length; i++)
            FilaSwitch(
              titulo: mediosPago[i].medioPago,
              descripcion: mediosPago[i].activo
                  ? null
                  : 'No se ofrece al cobrar',
              valor: mediosPago[i].activo,
              onChanged: (v) {
                if (!v && mediosPagoActivos.length == 1) {
                  showAppToast(
                    context,
                    'Debe quedar al menos un método de pago activo.',
                    type: ToastType.info,
                  );
                  return;
                }
                setState(
                  () => mediosPago[i] = mediosPago[i].copyWith(activo: v),
                );
              },
              extra: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Cobro adicional por usar este método',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Switch(
                        value: mediosPago[i].aplicaComision,
                        onChanged: (v) => setState(
                          () => mediosPago[i] = mediosPago[i].copyWith(
                            aplicaComision: v,
                          ),
                        ),
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppColors.primaryGreen,
                      ),
                    ],
                  ),
                  if (mediosPago[i].aplicaComision)
                    CampoNumeroConfig(
                      etiqueta: 'Porcentaje',
                      valor: mediosPago[i].porcentajeComision,
                      sufijo: '%',
                      onChanged: (n) => mediosPago[i] = mediosPago[i].copyWith(
                        porcentajeComision: n,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
      SeccionConfig(
        titulo: 'Cobro adicional por delivery',
        filas: [
          FilaSwitch(
            titulo: 'Cobrar un monto extra en pedidos delivery',
            descripcion: 'Se suma como una línea más al pedido',
            valor: config.cargoDeliveryHabilitado,
            onChanged: (v) =>
                setState(() => config.cargoDeliveryHabilitado = v),
            extra: CampoNumeroConfig(
              etiqueta: 'Monto',
              valor: config.cargoDeliveryMonto,
              prefijo: 'S/ ',
              onChanged: (n) => config.cargoDeliveryMonto = n,
            ),
          ),
        ],
      ),
    ];
  }

  // ---------------- Usuarios y roles ----------------

  List<Widget> _usuarios() {
    return [
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Usuarios',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _nuevoUsuario,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Usuario'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final u in usuarios) ...[
              Divider(height: 1, color: Colors.grey.shade200),
              _filaUsuario(u),
            ],
          ],
        ),
      ),
      SeccionConfig(
        titulo: 'Roles',
        descripcion: 'Qué puede hacer cada rol dentro del sistema.',
        filas: [
          for (final r in AppRole.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      r.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r.descripcion,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ];
  }

  Widget _filaUsuario(Usuario u) {
    final soyYo = u.id == widget.usuario.id;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
            child: Text(
              u.nombre.isEmpty ? '?' : u.nombre[0].toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.nombre + (soyYo ? ' (tú)' : ''),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  u.email,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          PopupMenuButton<AppRole>(
            tooltip: 'Cambiar rol',
            enabled: !soyYo,
            onSelected: (r) => setState(() => actualizarUsuario(_conRol(u, r))),
            itemBuilder: (_) => [
              for (final r in AppRole.values)
                PopupMenuItem(value: r, child: Text(r.label)),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(u.rol.label, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: soyYo ? 'No puedes desactivarte' : 'Activo',
            child: Switch(
              value: u.activo,
              onChanged: soyYo
                  ? null
                  : (v) => setState(() => actualizarUsuario(_conActivo(u, v))),
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Usuario _conRol(Usuario u, AppRole rol) => Usuario(
    id: u.id,
    nombre: u.nombre,
    email: u.email,
    password: u.password,
    rol: rol,
    sedeId: u.sedeId,
    activo: u.activo,
  );

  Usuario _conActivo(Usuario u, bool activo) => Usuario(
    id: u.id,
    nombre: u.nombre,
    email: u.email,
    password: u.password,
    rol: u.rol,
    sedeId: u.sedeId,
    activo: activo,
  );

  Future<void> _nuevoUsuario() async {
    final nombre = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    var rol = AppRole.mesero;
    final creado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Nuevo usuario'),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombre,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                ),
                const SizedBox(height: 12),
                AppSelect<AppRole>(
                  label: 'Rol',
                  value: rol,
                  items: [
                    for (final r in AppRole.values)
                      AppSelectItem(value: r, label: r.label),
                  ],
                  onChanged: (r) => setLocal(() => rol = r ?? rol),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (nombre.text.trim().isEmpty ||
                    !email.text.contains('@') ||
                    password.text.isEmpty) {
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
    if (creado == true) {
      setState(
        () => agregarUsuario(
          Usuario(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            nombre: nombre.text.trim(),
            email: email.text.trim(),
            password: password.text,
            rol: rol,
          ),
        ),
      );
    }
  }

  // ---------------- Negocio ----------------

  List<Widget> _negocio() {
    Widget par(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    );
    return [
      SeccionConfig(
        titulo: 'Información del negocio',
        filas: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                CampoTextoConfig(
                  etiqueta: 'Nombre',
                  valor: negocio.nombre,
                  onChanged: (v) => negocio.nombre = v,
                ),
                const SizedBox(height: 12),
                par(
                  CampoTextoConfig(
                    etiqueta: 'Teléfono',
                    valor: negocio.telefono,
                    teclado: TextInputType.phone,
                    onChanged: (v) => negocio.telefono = v,
                  ),
                  CampoTextoConfig(
                    etiqueta: 'Correo de contacto',
                    valor: negocio.emailContacto,
                    teclado: TextInputType.emailAddress,
                    onChanged: (v) => negocio.emailContacto = v,
                  ),
                ),
                const SizedBox(height: 12),
                CampoTextoConfig(
                  etiqueta: 'Dirección',
                  valor: negocio.direccion,
                  onChanged: (v) => negocio.direccion = v,
                ),
                const SizedBox(height: 12),
                par(
                  CampoTextoConfig(
                    etiqueta: 'Moneda',
                    valor: negocio.moneda,
                    onChanged: (v) => negocio.moneda = v,
                  ),
                  CampoTextoConfig(
                    etiqueta: 'Idioma',
                    valor: negocio.idioma,
                    onChanged: (v) => negocio.idioma = v,
                  ),
                ),
                const SizedBox(height: 12),
                par(
                  CampoTextoConfig(
                    etiqueta: 'País',
                    valor: negocio.pais,
                    onChanged: (v) => negocio.pais = v,
                  ),
                  CampoTextoConfig(
                    etiqueta: 'Zona horaria',
                    valor: negocio.zonaHoraria,
                    onChanged: (v) => negocio.zonaHoraria = v,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      SeccionConfig(
        titulo: 'Horario de atención',
        descripcion: 'Enciende los días que abre el local y elige su horario.',
        filas: [for (var i = 0; i < horarios.length; i++) _filaHorario(i)],
      ),
    ];
  }

  String _hora(TimeOfDay? t) => t == null
      ? '--:--'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _elegirHora(int i, {required bool inicio}) async {
    final h = horarios[i];
    final elegida = await showTimePicker(
      context: context,
      initialTime:
          (inicio ? h.inicio : h.fin) ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (elegida == null) return;
    setState(
      () => horarios[i] = inicio
          ? h.copyWith(inicio: elegida)
          : h.copyWith(fin: elegida),
    );
  }

  Widget _filaHorario(int i) {
    final Horario h = horarios[i];
    Widget hora(String etiqueta, TimeOfDay? t, bool inicio) => InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _elegirHora(i, inicio: inicio),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          '$etiqueta ${_hora(t)}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              h.dia,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Switch(
            value: h.abierto,
            onChanged: (v) =>
                setState(() => horarios[i] = h.copyWith(abierto: v)),
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primaryGreen,
          ),
          const SizedBox(width: 12),
          if (h.abierto) ...[
            hora('De', h.inicio, true),
            const SizedBox(width: 8),
            hora('a', h.fin, false),
          ] else
            Text(
              'Cerrado',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
        ],
      ),
    );
  }
}

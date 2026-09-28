import 'package:flutter/material.dart';

import '../data/configuracion_store.dart';
import '../models/app_role.dart';
import '../models/mock_user.dart';
import '../models/sede.dart';

// Alta/edición de un usuario (simula la tabla `usuario`).
class UsuarioFormScreen extends StatefulWidget {
  final MockUser? usuario;

  const UsuarioFormScreen({super.key, this.usuario});

  @override
  State<UsuarioFormScreen> createState() => _UsuarioFormScreenState();
}

class _UsuarioFormScreenState extends State<UsuarioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nombreController = TextEditingController(
    text: widget.usuario?.nombre ?? '',
  );
  late final _emailController = TextEditingController(
    text: widget.usuario?.email ?? '',
  );
  late final _passwordController = TextEditingController(
    text: widget.usuario?.password ?? '',
  );

  late AppRole _rol = widget.usuario?.rol ?? AppRole.mesero;
  late Sede? _sede = widget.usuario?.sedeId == null
      ? null
      : sedes.where((s) => s.id == widget.usuario!.sedeId).firstOrNull;
  late bool _activo = widget.usuario?.activo ?? true;

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;

    final resultado = MockUser(
      id:
          widget.usuario?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      nombre: _nombreController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      rol: _rol,
      sedeId: _sede?.id,
      activo: _activo,
    );
    Navigator.of(context).pop(resultado);
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.usuario != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? 'Editar usuario' : 'Nuevo usuario'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa el correo';
                if (!v.contains('@')) return 'Correo inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Ingresa la contraseña' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AppRole>(
              initialValue: _rol,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: AppRole.values
                  .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                  .toList(),
              onChanged: (value) => setState(() => _rol = value!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Sede?>(
              initialValue: _sede,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sede (opcional)'),
              items: [
                const DropdownMenuItem<Sede?>(
                  value: null,
                  child: Text('Sin asignar'),
                ),
                ...sedes.map(
                  (s) => DropdownMenuItem<Sede?>(
                    value: s,
                    child: Text(s.direccion),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _sede = value),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo'),
              subtitle: const Text(
                'Los usuarios inactivos no pueden iniciar sesión',
              ),
              value: _activo,
              onChanged: (value) => setState(() => _activo = value),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _guardar,
              child: Text(editando ? 'Guardar cambios' : 'Crear usuario'),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

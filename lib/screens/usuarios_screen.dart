import 'package:flutter/material.dart';

import '../data/mock_sedes.dart';
import '../data/usuarios_store.dart';
import '../models/app_role.dart';
import '../models/mock_user.dart';
import 'usuario_form_screen.dart';

// CRUD de usuarios (solo Administrador).
class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  Future<void> _crear() async {
    final creado = await Navigator.of(context).push<MockUser>(
      MaterialPageRoute(builder: (_) => const UsuarioFormScreen()),
    );
    if (creado != null) {
      setState(() => agregarUsuario(creado));
    }
  }

  Future<void> _editar(MockUser usuario) async {
    final editado = await Navigator.of(context).push<MockUser>(
      MaterialPageRoute(builder: (_) => UsuarioFormScreen(usuario: usuario)),
    );
    if (editado != null) {
      setState(() => actualizarUsuario(editado));
    }
  }

  Future<void> _eliminar(MockUser usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Eliminar a "${usuario.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      setState(() => eliminarUsuario(usuario.id));
    }
  }

  String? _sedeDe(String? sedeId) {
    if (sedeId == null) return null;
    for (final sede in mockSedes) {
      if (sede.id == sedeId) return sede.direccion;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _crear,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: usuarios.length,
        itemBuilder: (context, index) {
          final usuario = usuarios[index];
          final sede = _sedeDe(usuario.sedeId);
          return Card(
            child: ListTile(
              title: Text(usuario.nombre),
              subtitle: Text(
                '${usuario.email} · ${usuario.rol.label}'
                '${sede != null ? ' · $sede' : ''}'
                '${usuario.activo ? '' : ' · Inactivo'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editar(usuario),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _eliminar(usuario),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

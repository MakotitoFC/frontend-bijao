import '../models/mock_user.dart';
import 'mock_users.dart';

// Estado en memoria de usuarios, compartido entre Login y el módulo Usuarios.
// TODO: reemplazar por `usuario` real al conectar el servidor local.
final List<MockUser> usuarios = List.of(usuariosIniciales);

void agregarUsuario(MockUser usuario) => usuarios.add(usuario);

void actualizarUsuario(MockUser usuario) {
  final index = usuarios.indexWhere((u) => u.id == usuario.id);
  if (index != -1) usuarios[index] = usuario;
}

void eliminarUsuario(String id) => usuarios.removeWhere((u) => u.id == id);

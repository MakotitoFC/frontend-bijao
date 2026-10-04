import '../models/app_role.dart';
import '../models/usuario.dart';

// Usuarios del sistema (tabla `usuarios`). Se cargan desde el backend; el
// login valida contra esta lista.
// Credenciales de prueba mientras no hay backend: admin@bijao.com/admin123,
// mesero@bijao.com/mesero123, cocina@bijao.com/cocina123.
final List<Usuario> usuarios = [
  const Usuario(
    id: 'user1',
    nombre: 'Ana Torres',
    email: 'admin@bijao.com',
    password: 'admin123',
    rol: AppRole.administrador,
    sedeId: '1',
  ),
  const Usuario(
    id: 'user2',
    nombre: 'Luis Ramírez',
    email: 'mesero@bijao.com',
    password: 'mesero123',
    rol: AppRole.mesero,
    sedeId: '1',
  ),
  const Usuario(
    id: 'user3',
    nombre: 'Carla Quispe',
    email: 'cocina@bijao.com',
    password: 'cocina123',
    rol: AppRole.trabajador,
    sedeId: '1',
  ),
];

void agregarUsuario(Usuario usuario) => usuarios.add(usuario);

void actualizarUsuario(Usuario usuario) {
  final index = usuarios.indexWhere((u) => u.id == usuario.id);
  if (index != -1) usuarios[index] = usuario;
}

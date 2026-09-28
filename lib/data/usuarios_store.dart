import '../models/app_role.dart';
import '../models/mock_user.dart';

// Usuarios del sistema (tabla `usuarios`). Se cargan desde el backend; el
// login valida contra esta lista.
// Credenciales de prueba mientras no hay backend: admin@bijao.com/admin123,
// mesero@bijao.com/mesero123, cocina@bijao.com/cocina123.
final List<MockUser> usuarios = [
  const MockUser(
    id: 'user1',
    nombre: 'Ana Torres',
    email: 'admin@bijao.com',
    password: 'admin123',
    rol: AppRole.administrador,
    sedeId: '1',
  ),
  const MockUser(
    id: 'user2',
    nombre: 'Luis Ramírez',
    email: 'mesero@bijao.com',
    password: 'mesero123',
    rol: AppRole.mesero,
    sedeId: '1',
  ),
  const MockUser(
    id: 'user3',
    nombre: 'Carla Quispe',
    email: 'cocina@bijao.com',
    password: 'cocina123',
    rol: AppRole.trabajador,
    sedeId: '1',
  ),
];

void agregarUsuario(MockUser usuario) => usuarios.add(usuario);

void actualizarUsuario(MockUser usuario) {
  final index = usuarios.indexWhere((u) => u.id == usuario.id);
  if (index != -1) usuarios[index] = usuario;
}

void eliminarUsuario(String id) => usuarios.removeWhere((u) => u.id == id);

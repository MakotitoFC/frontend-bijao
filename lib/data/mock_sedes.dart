import '../models/sede.dart';

// Datos de prueba mientras no hay conexión a un backend real.
// TODO: reemplazar por la lista de sedes obtenida del servidor local (laptop)
// una vez esté listo el backend que sincroniza con Supabase.
const mockSedes = [
  Sede(
    id: '1',
    ruc: '20123456789',
    direccion: 'Av. Principal 123, San Isidro',
    celular: '987654321',
  ),
  Sede(
    id: '2',
    ruc: '20123456790',
    direccion: 'Jr. Los Olivos 456, Miraflores',
    celular: '987654322',
  ),
  Sede(
    id: '3',
    ruc: '20123456791',
    direccion: 'Calle Las Flores 789, Surco',
    celular: null,
  ),
];

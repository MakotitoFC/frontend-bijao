> Documento para el equipo de backend. Lo revisado está en `backend_bijao`
> (`caja_repository.go`, `TraspasoCaja`; rutas en `cmd/api/main.go`). El frontend
> ya tiene el modal de traspaso; falta lo de abajo para avisar al receptor y
> dejar registro.

# Traspaso de responsable de caja: aviso al receptor y registro para seguimiento

## Cómo funciona hoy (revisado en el backend)

`POST /api/v1/caja/traspaso` (`TraspasoCaja` en `caja_repository.go`) solo cambia `apertura_caja.usuario_id` por el nuevo responsable y agrega una línea de texto a `apertura_caja.notas`:

```
[Traspaso 21:45:10 01/11/2026: de Alexis a María] - Motivo: cambio de turno
```

- La caja es de la sede (una apertura abierta por sede), no de cada usuario: el receptor **no necesita tener caja abierta**.
- **No se avisa al receptor**: no se emite ningún evento. Se entera solo si recarga Caja y ve otro nombre como responsable.
- **No hay registro estructurado**: el traspaso solo existe como texto dentro de las notas de la apertura. No se puede listar ni consultar (quién, a quién, cuándo, por qué), y si se hacen varios traspasos las líneas se acumulan en el mismo texto.

## Qué se pide

### 1. Registro de cada traspaso (para seguimiento)

Una tabla propia, por ejemplo `caja_traspaso`, con una fila por traspaso:

| Campo | Contenido |
|-------|-----------|
| `id` | uuid |
| `sede_id` | sede |
| `apertura_caja_id` | apertura (turno) sobre la que se traspasó |
| `usuario_origen_id` | quien entregó la caja |
| `usuario_destino_id` | quien la recibe |
| `fecha_hora` | momento del traspaso |
| `motivo` | texto opcional escrito por quien traspasa |
| `efectivo_esperado` | efectivo esperado en caja al momento (si se puede calcular), para cuadrar entre responsables |
| `visto_por_destino` | `false` al crear; pasa a `true` cuando el receptor lo ve |
| `visto_at` | cuándo lo vio |

Se sigue actualizando `apertura_caja.usuario_id` y, si se quiere, la línea en `notas`, pero la fuente de verdad pasa a ser esta tabla.

### 2. Evento en vivo

Al traspasar, emitir `CAJA_TRASPASADA` (a la sede, como los demás eventos) con el mismo objeto del registro: `id`, `apertura_caja_id`, `usuario_origen_id` y su nombre, `usuario_destino_id` y su nombre, `fecha_hora` y `motivo`.

### 3. Aviso que no se pierde

- `GET /api/v1/caja/traspasos?visto=false` (o `?destino=yo`): los traspasos recibidos por el usuario que aún no vio, para mostrar el aviso al abrir la app si estaba desconectado.
- `POST /api/v1/caja/traspasos/:id/visto`: marca el traspaso como visto (igual que `POST /api/v1/mozo/traspasos/:id/visto`).

### 4. Consulta del historial

`GET /api/v1/caja/traspasos?desde=&hasta=&apertura_id=` para ver los traspasos de un turno o de un rango de fechas (administración), y que el reporte detallado del día y el cierre de caja puedan listar quién tuvo la caja y en qué horario.

### 5. Lista de destinatarios para el cajero

El modal de traspaso lista a los otros administradores y cajeros activos con `GET /api/usuarios`, que exige `LEER.USUARIO`: el administrador lo tiene, el **cajero no**, y a un cajero le sale "No se encontraron otros usuarios".

**Se pide:** una ruta liviana para `ADMINISTRADOR` y `CAJERO`, por ejemplo `GET /api/v1/caja/responsables`, que devuelva `id`, `nombre` y `rol` de los administradores y cajeros activos de la sede (como ya existe `/api/v1/mozo/mozos` para los traspasos entre mozos).

## Qué hará la app con esto (frontend)

- Al nuevo responsable le sale un modal "Te traspasaron la caja": quién, a qué hora, el motivo y el botón **Ir a Caja** (en vivo por el evento, o al abrir la app por la lista de no vistos).
- A quien traspasa se le confirma con el nombre del receptor.
- En Caja se podrá ver el historial de traspasos del turno.

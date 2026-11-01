# Traspaso rechazado entre mozos: qué falta en el backend

## Qué hace la app (ya hecho)

Cuando el mozo destino rechaza un traspaso, al mozo que lo solicitó le sale el aviso "Traspaso rechazado" con el botón **Elegir otro mozo**, que abre el selector de traspaso de ese pedido.

La app lo detecta así, sin cambios en el servidor:

1. Escucha el evento `TRASPASO_RESUELTO` (y `TRASPASO_SOLICITADO`) del flujo `GET /api/v1/eventos` y vuelve a leer los traspasos.
2. Compara los traspasos pendientes que ese mozo había enviado: los que dejan de estar pendientes se buscan en `GET /api/v1/mozo/traspasos?estado=rechazado`. Si el traspaso está ahí, es un rechazo y se avisa.

## Qué ya existe en el backend (revisado)

- `POST /api/v1/mozo/traspasos/:id/rechazar` cambia `pedido_traspaso.estado` a `rechazado` y el pedido sigue con el mozo de origen.
- `GET /api/v1/mozo/traspasos?estado=...` devuelve los traspasos donde el usuario es origen o destino.
- Al rechazar se emite `TRASPASO_RESUELTO` (`traspaso_service.go`, `RechazarTraspaso`).

## Qué falta o está incompleto

### 1. El evento de rechazo no dice a quién va ni de qué pedido es

Hoy se emite así:

```json
{ "traspaso_id": "...", "estado": "rechazado" }
```

Sin `pedido_id`, sin `mozo_origen_id`, sin `mozo_destino_id` ni nombres. Además se manda a **toda la sede** (`BroadcastToSede`): todos los clientes se enteran y todos tienen que consultar la lista para saber si les toca.

**Se pide:** que el evento de rechazo (y los de aceptado y cancelado) lleve el mismo objeto que `TRASPASO_SOLICITADO`: `id`, `pedido_id`, `pedido_numero`, `ubicacion`, `mozo_origen_id`, `mozo_origen_nombre`, `mozo_destino_id`, `mozo_destino_nombre` y `estado`. Con eso la app puede avisar al mozo de origen directo, sin la segunda consulta.

### 2. Evento dirigido

**Se pide (opcional):** poder enviar el evento solo al usuario de origen (y al administrador), en vez de a toda la sede.

### 3. Aviso que no se pierde

Si el mozo de origen no tiene la app abierta (o cerró sesión) cuando se rechaza, no se entera: el evento se pierde y la lista de pendientes ya no incluye el traspaso.

**Se pide:** un campo para saber qué rechazos el mozo de origen aún no vio, por ejemplo `visto_por_origen` (boolean, falso al rechazar) y un `POST /api/v1/mozo/traspasos/:id/visto` que lo marque. Así, al abrir la app, `GET .../traspasos?estado=rechazado&visto=false` trae los rechazos pendientes de avisar.

### 4. Motivo del rechazo (opcional)

`POST .../rechazar` podría aceptar un `motivo` opcional y devolverlo en el evento y en la lista, para mostrarlo en el aviso al mozo de origen.

## Resumen de prioridad

| # | Cambio | Prioridad |
|---|--------|-----------|
| 1 | Completar el payload de `TRASPASO_RESUELTO` | Alta (quita una consulta por evento) |
| 3 | Rechazos "no vistos" | Media (evita perder el aviso) |
| 2 | Evento solo para el usuario de origen | Baja |
| 4 | Motivo del rechazo | Baja |

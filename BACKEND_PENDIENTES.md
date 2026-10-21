# Pendientes del backend

1. Categorías y subcategorías no se actualizan en vivo (error).
2. Presentaciones de bebida (vaso, jarra) sin API (mejora, no urgente).

---

# 1. Categorías y subcategorías no se actualizan en vivo

## Problema

Cuando alguien crea, edita o elimina una **categoría** o **subcategoría** de la carta, los demás equipos conectados (otro navegador, otra tablet, la nube) no ven el cambio hasta recargar la página. El equipo que hizo el cambio sí lo ve al instante.

## Causa

El flujo de eventos en vivo (`GET /api/v1/eventos`, SSE) solo emite `CARTA_ACTUALIZADA` cuando cambia un **plato** o un **tamaño** (`internal/handlers/catalog_handler.go`, líneas ~590 a ~750). Estos handlers **no emiten ningún evento**:

| Handler | Ruta |
|---|---|
| `CreateCategoria` | `POST /api/categorias` |
| `UpdateCategoria` | `PUT /api/categorias/:id` |
| `DeleteCategoria` | `DELETE /api/categorias/:id` |
| `CreateSubcategoria` | `POST /api/subcategorias` |
| `UpdateSubcategoria` | `PUT /api/subcategorias/:id` |
| `DeleteSubcategoria` | `DELETE /api/subcategorias/:id` |

## Qué se pide

En cada uno de esos 6 handlers, después de que el servicio responda sin error y antes de devolver la respuesta, emitir el mismo evento que ya usan los platos:

```go
h.hub.Broadcast("CARTA_ACTUALIZADA", map[string]interface{}{
    "origen": "categoria", // "subcategoria" en los handlers de subcategoría
    "id":     id.String(),
})
```

Basta con ese evento. No hace falta crear uno nuevo ni cambiar el formato.

## Lado del frontend (ya hecho)

- `CARTA_ACTUALIZADA` ya está mapeado: el frontend vuelve a leer categorías, subcategorías, platos y tamaños.
- La pantalla Carta se redibuja cuando llega ese evento. No usa temporizadores ni consultas periódicas.
- Si otro equipo elimina la categoría seleccionada, la selección vuelve a "Todos".

## Cómo probarlo

1. Abrir la carta en dos equipos (o dos pestañas) contra el mismo servidor.
2. En el equipo A, crear, renombrar y eliminar una categoría, y lo mismo con una subcategoría.
3. En el equipo B, sin recargar, el cambio debe aparecer en menos de un segundo.

---

# 2. Presentaciones de bebida (vaso, jarra) sin API

> Mejora, no un error. Hoy se resuelve registrando vaso y jarra como **tamaños** del plato (`carta_variante`, vía `variantes` en `POST/PUT /api/carta` o `/api/carta-variantes`). Solo hace falta si el restaurante necesita guardar los ml y el catálogo de unidades de bebida.

## Situación

La base de datos ya tiene las tablas:

- `unidad_bebida` (`id`, `unidad_presentacion`, `estado`, `sede_id`): catálogo (vaso, jarra, botella...).
- `carta_presentacion` (`id`, `carta_id`, `unidad_bebida_id`, `volumen_ml`, `precio_cliente`, `precio_personal`, `url_imagen`, `estado`): presentaciones de cada bebida.

Pedidos, disponibilidad, promociones e insumos ya usan `carta_presentacion_id`. En `pedidos_detalle` solo puede ir presentación o tamaño (`chk_pres_var`).

Pero **no hay ninguna ruta** para leerlas ni escribirlas. En `cmd/api/main.go` solo existen `/carta-variantes` y `/tamanos`. Los DTO `CartaPresentacionDTO` y `UnidadBebidaDTO` (`internal/dto/carta.go`) no los usa nadie, y el seed solo trae permisos de lectura (`LEER.CARTA_PRESENTACION`, `LEER.UNIDAD_BEBIDA`).

## Qué se pide

1. Rutas CRUD para `unidad_bebida` (por ejemplo `/api/unidades-bebida`) y `carta_presentacion` (por ejemplo `/api/carta-presentaciones`), con sus permisos `CREAR`, `UPDATE` y `DELETE` en el seed y asignados al rol ADMINISTRADOR.
2. Aceptar y devolver `presentaciones` en `POST/PUT /api/carta`, igual que ya se hace con `variantes`.
3. Emitir `CARTA_ACTUALIZADA` al crear, editar o borrar (ver punto 1).
4. Avisar al frontend de las rutas y del formato JSON.

## Lado del frontend (pendiente hasta que exista la API)

La lista `presentaciones` (`lib/data/presentaciones_store.dart`) hoy siempre está vacía: nada la llena. Cuando exista la API se cargará desde el servidor y se hará la pantalla para registrarlas (volumen en ml, unidad, precios).

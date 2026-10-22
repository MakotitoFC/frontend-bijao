# Pendientes del backend

Estado revisado contra el commit `69838c4` del backend.

1. **Error urgente:** el rol CAJERO no puede leer los pedidos (le falta `LEER.PEDIDO`).
2. **Error:** `GET /api/carta` devuelve repetidos los platos con variantes o presentaciones.
3. El seed no trae métodos de pago ni categorías de movimiento.
4. El rol MOZO conserva el permiso `CREAR.PAGO`.
5. Caja: tres puntos del cálculo del efectivo esperado a revisar.
6. Solicitud: varios tápers por plato (hoy es uno solo). La app ya los envía.
7. Vender un táper sin stock suficiente: el servidor hoy lo rechaza.
8. Aviso: los pedidos en mesa ya no llevan nombre de cliente.
9. Menor: `uploads/` no está completo en `.gitignore`.
10. Comprobantes: imprimir con los datos de Lucode y manejar la espera de SUNAT (3 a 4 segundos).

---

# 1. El rol CAJERO no puede leer los pedidos

## Síntoma

El cajero tiene pedidos por cobrar pero **no le aparece ninguno**: ni en su vista de Pedidos (comandas) ni en el Historial de pedidos. La app no muestra error, solo la lista vacía.

## Causa

`GET /api/pedidos`, `GET /api/pedidos/:id` y `GET /api/pedidos/anulaciones` exigen el permiso **`LEER.PEDIDO`** (`cmd/api/main.go`, líneas ~399 a 403). En el seed (`00002_seed_initial_data.sql`), el rol CAJERO tiene solo `LEER.PEDIDOS` (con S), `LEER.DETALLES_PEDIDO` y `LEER.MESA_PEDIDO`, pero **no** `LEER.PEDIDO`. El servidor responde 403 y la app, al fallar la consulta, deja la lista vacía.

## Qué se pide

- Agregar `LEER.PEDIDO` (id `d10de7fc-dca4-48c3-9cfa-3061303fb051`) al rol CAJERO (`22222222-2222-2222-2222-222222222222`) en el seed.
- Aplicarlo también a las bases ya creadas (local y nube), por ejemplo con:

```sql
INSERT INTO rol_permiso VALUES
  ('22222222-2222-2222-2222-222222222222', 'd10de7fc-dca4-48c3-9cfa-3061303fb051')
ON CONFLICT DO NOTHING;
```

- Revisar el resto de lo que hace el cajero: con la vista nueva paga, imprime la cuenta (`POST /api/v1/impresion/pedidos/:id/reimprimir`) y emite comprobantes (`/api/v1/facturacion/comprobantes`); esas rutas no piden un permiso del seed, pero conviene confirmar que el rol CAJERO las alcanza.

## Cómo probarlo

Iniciar sesión (de nuevo, para que se carguen los permisos) con un usuario CAJERO: debe ver los pedidos abiertos en Pedidos y todos los del rango en Ventas › Historial.

---

# 2. `GET /api/carta` repite los platos con variantes o presentaciones

## Síntoma

En la Carta aparece el mismo plato varias veces cuando ese plato tiene variantes o presentaciones con stock diario. Los platos sin variantes ni presentaciones salen una sola vez.

## Causa

En `internal/repositories/catalog_repository.go`, función `GetCarta` (consulta con `con_disponibilidad`, línea ~850):

```sql
LEFT JOIN carta_disponibilidad cd
  ON cd.carta_id = c.id
 AND cd.fecha = (CURRENT_TIMESTAMP AT TIME ZONE 'America/Lima')::date
 AND ($1::uuid IS NULL OR cd.sede_id = $1)
```

`carta_disponibilidad` guarda **una fila por cada variante o presentación** de un plato, para cada día (su índice único `uq_carta_disponibilidad_dia` incluye `carta_presentacion_id` y `carta_variante_id`). El `JOIN` no distingue entre ellas, así que cada fila de disponibilidad del día multiplica la fila del plato: un plato con 2 variantes con stock sale 2 veces.

## Qué se pide

Traer solo la disponibilidad **del plato en sí**:

```sql
AND cd.carta_presentacion_id IS NULL
AND cd.carta_variante_id IS NULL
```

(o agrupar por plato). La disponibilidad por variante o presentación debe pedirse por separado, junto con `variantes` y `presentaciones`, que ya se cargan en un lote aparte.

Efecto colateral a corregir: al mezclar filas, un plato puede salir con `estado = 'agotado'` solo porque se agotó **una** de sus variantes, y con el `stock` de otra fila.

## Lado del frontend (ya hecho)

La app deja un solo plato por `id` y, si hay repetidos, prefiere el que no está agotado. Eso solo oculta el síntoma: el `stock` y el estado mostrados pueden seguir siendo los de una variante hasta que se corrija la consulta.

## Cómo probarlo

Crear un plato con 2 variantes, abrir el día con cantidades para ambas y llamar a `GET /api/carta?con_disponibilidad=true`: el plato debe venir **una sola vez**.

---

# 3. El seed no trae `medio_pago` ni `categoria_movimiento`

`migrations/00002_seed_initial_data.sql` no inserta métodos de pago ni categorías de movimiento de caja. En una base creada desde cero la app no tiene con qué cobrar ni cómo registrar ingresos y salidas: no hay métodos de pago en el servidor y hay que cargarlos a mano.

## Qué se pide

Incluir en el seed, con `ON CONFLICT DO NOTHING`:

- Métodos de pago como mínimo: Efectivo, Yape y Tarjeta (con su porcentaje de comisión).
- Categorías de movimiento básicas de caja (por ejemplo, las de ingreso por venta y las de salidas más comunes).

## Cómo probarlo

Crear una base nueva con `go run ./cmd/migrate`, iniciar sesión en la app y cobrar un pedido sin haber cargado nada a mano.

---

# 4. El rol MOZO conserva `CREAR.PAGO`

La app ya **no muestra** Pagar ni Imprimir al mozo (solo administración y caja cobran). Pero ocultar un botón no es control de acceso: en el seed, el rol MOZO sigue teniendo `CREAR.PAGO`, así que podría registrar un cobro llamando a `POST /api/pagos` directamente.

## Qué se pide

- Quitar `CREAR.PAGO` del rol MOZO en `00002_seed_initial_data.sql` y confirmar que `POST /api/pagos` responde 403 para ese rol.
- Revisar si el MOZO necesita algún otro permiso de pago o caja; hoy en el seed solo tiene ese.

---

# 5. Caja: efectivo esperado, tres puntos a revisar

`GetTotalesCajaActual` (`internal/repositories/caja_repository.go`, ~línea 1295 a 1363) calcula:

> efectivo esperado = monto inicial + cobros en efectivo + ingresos en efectivo − salidas en efectivo

La fórmula es coherente y no duplica los cobros. A revisar:

1. **"Efectivo" se detecta por el nombre exacto** (`"efectivo"` en minúsculas). Un método llamado, por ejemplo, "Efectivo S/" no cuenta como efectivo, y cualquier nombre que no reconoce cae en el grupo **tarjeta**. Conviene identificar el tipo de método con un campo, no por el nombre.
2. **La propina no entra** en el efectivo esperado (se guarda aparte del pago). Si el cajero recibe la propina en efectivo y la deja en el cajón, el cierre mostrará que sobra. Definir si debe sumarse.
3. **Anular un movimiento automático no cambia los totales.** Cada cobro crea un movimiento "Cobro de pedido" ligado al pedido (`pedidos_id`), y los totales **excluyen** esos movimientos (`m.pedidos_id IS NULL`). La app los lista con Editar y Anular; si alguien anula uno queda tachado pero el efectivo esperado sigue igual. Se pide que el backend rechace editar o anular movimientos que tengan `pedidos_id`, o que defina qué debe pasar con el total.

---

# 6. Solicitud: varios tápers por plato

Hoy `carta.taper_id` es un solo táper por plato. El negocio necesita asociar **varios tápers** a un plato: en la Carta se marcan y desmarcan, y el selector muestra cuántos tiene el plato.

## Lado del frontend (ya hecho)

Al crear o editar un plato, la app envía **ambos** campos en `POST/PUT /api/carta`:

- `taper_ids`: lista de uuid con todos los tápers elegidos (lista vacía si no tiene ninguno).
- `taper_id`: el **primero** de la lista (o ausente/nulo si no hay), para no romper lo que ya existe.

Al leer, si `GET /api/carta` devuelve `taper_ids` la app usa esa lista; si solo trae `taper_id`, la toma como un único táper.

## Qué se pide

- Una relación de varios a varios entre plato y táper (por ejemplo, una tabla `carta_taper`) y aceptar `taper_ids` en `POST/PUT /api/carta`.
- Devolver `taper_ids` en `GET /api/carta`.
- Mantener `taper_id` (el principal) mientras tanto.

## Mientras no exista

El servidor ignora `taper_ids` y guarda solo `taper_id`: **solo el primer táper elegido queda guardado**; al recargar, el plato aparece con uno solo.

---

# 7. Vender un táper sin stock suficiente

En los pedidos la app muestra el **stock** de cada táper, pero **ya no bloquea** agregarlo si no alcanza (el stock es solo informativo).

Hoy el backend sí lo rechaza: `descontarStockTaper` (`internal/repositories/pedido_mozo_repository.go`) devuelve el error `stock insuficiente para táper '…'` y el pedido no se crea ni se agrega el producto.

## Qué se pide

Permitir registrar el pedido aunque el stock del táper no alcance: no devolver error y dejar el stock en cero o negativo, según lo que prefiera el negocio. Idealmente, dejar rastro del faltante en el movimiento de inventario.

---


# 8. Aviso: los pedidos en mesa ya no llevan nombre de cliente

El nombre del cliente no es importante en un pedido **en mesa**, así que la app ya no lo pide ni lo envía cuando el tipo de pedido es `mesa`: `nombre_cliente` llega vacío o ausente.

Para el backend:

- No debe exigir `nombre_cliente` en pedidos de tipo `mesa` (en `Para llevar` sí se sigue enviando y es obligatorio en la app).
- Si el backend agrega a los comentarios el texto `Cliente: …` cuando recibe un nombre, en mesa simplemente no se agregará.
- Revisar que no haya validaciones, reportes ni tickets del lado del servidor que den por hecho que una mesa siempre trae cliente.

---

# 9. Menor: `uploads/` en `.gitignore`

El `.gitignore` solo ignora `uploads/carta` y `uploads/evidencias`. Las carpetas `uploads/comprobantes` y `uploads/anulaciones` (PDF y fotos que genera el servidor) aparecen como archivos nuevos en Git y pueden subirse por error. Se pide ignorar `uploads/` completo.

---

# 10. Comprobantes: imprimir con los datos de Lucode y espera de SUNAT

Consultar a SUNAT (Lucode) tarda **3 a 4 segundos**. Mientras responde, el comprobante ya está guardado, pero la app lo mostraba como "sin respuesta", y si se imprimía en ese momento el papel salía sin los datos que devuelve Lucode.

## Lado del frontend (ya hecho)

Para **boleta y factura**:

1. `POST /api/v1/facturacion/comprobantes` se manda con `imprimir: false` (el ticket de venta interno sí se imprime en ese momento, porque no pasa por SUNAT).
2. Si el estado vuelve `PENDIENTE` (o `ERROR_CONEXION`), la app consulta `POST …/comprobantes/:id/consultar-status` **cada 2 segundos, hasta 10 veces**, mostrando "Esperando la respuesta de SUNAT…".
3. Cuando el estado deja de ser pendiente y no fue rechazado, llama a `POST …/comprobantes/:id/imprimir`.
4. Si pasados ~20 segundos SUNAT no responde, el comprobante queda guardado y la app ofrece "Consultar de nuevo"; al responder, se imprime.

## Qué se pide

- **`/imprimir` debe tomar los datos de Lucode** (serie y número, hash, código QR, enlaces y estado), no solo lo guardado antes de la respuesta. Si el comprobante sigue pendiente, consultar primero o responder con un error claro, en vez de imprimir incompleto.
- **`/consultar-status` debe actualizar** el comprobante con lo que devuelva Lucode (estado, hash, QR y PDFs) y devolverlo ya actualizado.
- **`POST /comprobantes` no debe fallar por la demora:** guardar el comprobante y devolverlo con `estado_sunat = PENDIENTE` sin esperar, o esperar hasta cerca de 4 segundos como máximo y devolver lo que haya.
- Un comprobante **rechazado** no debe imprimirse.

---

# 11. Turnos de los mozos (mañana y tarde-noche)

El negocio trabaja con **2 turnos para los mozos**: **mañana-tarde** y **tarde-noche**. Cada mozo tiene un turno y **solo puede entrar a la app dentro de su turno**. El administrador define los turnos y asigna el turno a cada mozo desde **Configuración**.

Hoy no existe nada de esto en el servidor, y el frontend no lo implementa hasta que el backend lo defina (no se inventan datos).

## Qué se pide

- **Turnos configurables:** una tabla o ajuste con nombre, hora de inicio y hora de fin de cada turno (el de tarde-noche cruza la medianoche), con endpoints de lectura y edición para el administrador.
- **Turno por usuario:** que cada usuario con rol mozo tenga asignado un turno (o ninguno) y que se pueda cambiar desde Configuración.
- **Límite de acceso:** el login (y las peticiones con sesión abierta) de un mozo debe rechazarse fuera de su turno, con un error claro, por ejemplo `403 fuera_de_turno`, que incluya el horario del turno para mostrarlo en la app. El administrador, el cajero y el trabajador no se ven afectados. Si el mozo tiene una sesión abierta cuando termina su turno, debe poder expirar o cerrarse.
- **Permisos:** `LEER.TURNO`, `CREAR.TURNO`, `ACTUALIZAR.TURNO` para el rol administrador.

## Lado del frontend (pendiente)

Una vez definido, la app agrega en Configuración una vista de turnos, un selector de turno en el usuario mozo y el mensaje de "fuera de turno" al iniciar sesión.

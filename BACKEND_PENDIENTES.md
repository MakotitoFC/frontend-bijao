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

---

# 12. Series de comprobantes por sede y por caja

Cada caja debe emitir con su propia **serie**, armada con el tipo de comprobante, la sede y el número de caja. La serie SUNAT tiene **4 caracteres**:

`[tipo][sede][caja de 2 dígitos]` → ejemplos de formato: `BA01` (boleta, sede A, caja 01) o `F101` (factura, sede 1, caja 01). Cada negocio decide qué carácter usa por sede.

- Tipo: `B` boleta, `F` factura.
- Sede: **un carácter, letra o número**, que el negocio asigna a cada sede (por ejemplo `A`, `B` o `1`, `2`). Lo define el administrador; no hay valores fijos.
- Caja: número de la caja dentro de la sede (01, 02…).

## Hoy

`facturacion_service.go` usa series fijas por defecto (`B001`, `F001`, `T001`) cuando la app no manda `serie`, y la tabla `sede` no tiene código de serie. No existe dónde guardar la caja a la que pertenece cada serie.

## Qué se pide

- **`sede`:** columna para el código de la sede (1 carácter, letra o número, único por negocio), con lectura y edición para el administrador.
- **Cajas:** que cada caja tenga su número dentro de la sede (01, 02…) y que el backend entregue, por caja, su serie de boleta y de factura (por ejemplo `serie_boleta: "BA01"`, `serie_factura: "FA01"`) en el estado/listado de cajas.
- **Emisión:** que `POST /comprobantes` use la serie de la caja que emite (y siga aceptando `serie` si la app la manda), con el correlativo propio de esa serie (`uq_comprobante_sede_serie_numero`).
- **Validación:** rechazar series que no tengan 4 caracteres alfanuméricos o que no empiecen con `B`/`F`.
- **Permisos:** `LEER`/`ACTUALIZAR` para el administrador sobre la letra de sede y el número de caja.

## Lado del frontend (pendiente hasta que el backend lo entregue)

- En **Configuración > Negocio**, definir el código (letra o número) de cada sede.
- En la vista **Caja**, una columna "Serie" por caja (boleta y factura).
- Al emitir un comprobante, mostrar la serie que se usará antes de confirmar.

No se muestran ni se inventan series en la app mientras el servidor no las envíe.

# 13. DNI en boletas (aviso)

La app exige el DNI (8 dígitos) cuando la boleta es de **más de S/ 700**; hasta S/ 700 (inclusive) es opcional y sale como `CLIENTES VARIOS`. El backend debería validar lo mismo: rechazar una boleta de más de S/ 700 sin DNI.

---

# 14. Reportes: rutas que necesita la vista (habilitada para el administrador)

La vista **Reportes** (Ventas > Reportes) está habilitada y hoy calcula todo en la app con los pedidos y pagos que ya tiene cargados (solo lo que hay en memoria). Para que sea correcta con todo el historial y en tiempo real, el backend debe entregar los agregados por rango de fechas. Sin definir todavía: caja ciega, arqueo y reportes diario/semanal/mensual de ventas (no se implementan hasta que se definan).

Todas las rutas reciben `desde` y `hasta` (fecha) y opcionalmente `sede_id`; permiso `LEER.MOVIMIENTO` (administrador):

| Sección de la vista | Ruta sugerida | Qué devuelve |
|---|---|---|
| Cantidad de pedidos, ventas totales, ticket promedio | `GET /api/reportes/resumen` | `pedidos`, `ventas_total`, `ticket_promedio` del rango (sin anulados) |
| Progreso de pedidos | `GET /api/reportes/pedidos-por-estado` | cantidad por estado (`pendiente`, `servido`, `pagado`, `anulado`, `devuelto`) |
| Rendimiento de mozos | `GET /api/reportes/rendimiento-mozos` | por mozo: pedidos, ventas, ticket promedio |
| Horas con más ventas | `GET /api/reportes/ventas-por-hora` | ventas y pedidos por hora del día (0–23) |
| Días con más ventas | `GET /api/reportes/ventas-por-dia-semana` | ventas y pedidos por día de la semana |
| Tipo de servicio | `GET /api/reportes/ventas-por-tipo` | pedidos, ventas y ticket promedio por tipo (`mesa`, `llevar`, `delivery`) |
| Plato más vendido | `GET /api/reportes/platos-mas-vendidos` | ranking de platos por unidades vendidas y por importe (`carta_id`, nombre, cantidad, ventas); parámetro `limite` (por defecto 10). Sin contar líneas anuladas ni devueltas |

Notas:
- Los importes deben salir de los pagos cobrados (no de pedidos anulados ni devoluciones).
- La hora y el día deben calcularse en la zona horaria de la sede.
- El nombre del rol del usuario es **mozo** (no "mesero"); los textos y campos del servidor deberían usar "mozo".

---

# 15. Pago compartido con un comprobante distinto por pagador

En el pago compartido, cada pagador puede pedir lo suyo: uno ningún comprobante, otro boleta y otro factura. La app registra los pagos de cada uno y luego emite **un comprobante por pagador**, vinculado con `pago_id` al primer pago de ese pagador (`POST /api/v1/facturacion/comprobantes`).

Para el backend, confirmar o ajustar:

- **Varios comprobantes por pedido:** `ExisteComprobanteActivo(pedido, pago)` ya distingue por pago; debe permitir una boleta y una factura activas en el mismo pedido si son de pagos distintos.
- **Importe del comprobante:** cuando viene `pago_id`, el comprobante debe cubrir **lo pagado por ese pagador** y no el total del pedido. Si un pagador pagó con varios métodos (varios pagos), el comprobante debería cubrir todos sus pagos: se propone aceptar `pago_ids` (lista) además de `pago_id`.
- **Sin duplicar el total:** la suma de los comprobantes de un pedido no debería superar su total.

---

---

# 17. Error al emitir comprobantes en pagos compartidos: "el campo total no coincide con la sumatoria de los ítems"

Síntoma (mesa y para llevar, solo en pago compartido): al emitir boleta o factura, SUNAT/Lucode rechaza con `El campo total 94 no coincide con la sumatoria de los ítems 55 (diferencia: 39)`.

## Causa (revisado en el código del backend)

1. `POST /api/pagos` sin `detalles` **reparte el pago automáticamente** entre las líneas del pedido y guarda en `pago_detalle` un `monto_aplicado` parcial con `cantidad_pagada = 1` (`caja_repository.go`, "Auto-repartir entre líneas con saldo pendiente").
2. Al emitir con `pago_id`, `ObtenerDatosPedidoParaFacturacion` (`facturacion_repository.go`) arma los ítems desde `pago_detalle` con **`PrecioUnitario = pd.precio_base`** (precio completo de la unidad), **`Cantidad = cantidad_pagada`** (1) y **`Subtotal = monto_aplicado`** (parcial). El total del comprobante sale de la suma de los `Subtotal`.
3. Lucode calcula cada ítem como `valor_unitario × cantidad` (`facturacion_service.go` usa `PrecioUnitario/1.18` y `Cantidad`), es decir, el precio completo × 1, no el monto aplicado. Con un pago parcial (compartido), la suma de los ítems no coincide con el `total` enviado.
4. Pasa igual con líneas de más de 1 unidad, con presentaciones/variantes/agregados (`precio` ≠ `precio_base × cantidad`) y con los tápers que se suman como ítem aparte.

## Qué se pide

- En los ítems del comprobante por pago, usar **`PrecioUnitario = Subtotal / Cantidad`** (el valor realmente cobrado), de modo que `Σ(valor_unitario × cantidad) = total`.
- En general, calcular siempre el valor unitario de cada ítem desde su `Subtotal` y no desde `precio_base`; ajustar el último ítem por redondeo, como ya se hace con los descuentos.
- Con `pago_detalle` parcial, `Cantidad` debería ser la cantidad real cubierta (o 1 con la descripción de la fracción), nunca la del pedido completo.
- Validar antes de llamar a Lucode que `Σ(valor_unitario × cantidad × 1.18) == total` y devolver un error claro del servidor en vez del rechazo del PSE.

Mientras no se corrija, los comprobantes por pagador de un pago compartido dividido en partes pueden ser rechazados; el pago de una sola persona (pago único) no se ve afectado.

---

# 18. El cajero no recibe el número de orden ni el detalle completo de los pedidos (bloquea la comanda del cajero)

## Síntoma

- El mozo ve el pedido como `#0004` y el cajero como `#ed09` (el prefijo del id): **no es el mismo número**.
- En la comanda del cajero no aparecen las **presentaciones** (jarra, vaso, volumen) ni las **variantes** ni los **agregados** de cada plato.

## Causa (revisado en el backend)

- El número de orden del día (`codigo_orden`, `#0004`) solo lo entrega `GET /api/v1/mozo/pedidos/:id` (`pedido_mozo_repository.go`). Esas rutas están limitadas a los roles `MOZO` y `ADMINISTRADOR` (`main.go`: `RequireRole("MOZO", "ADMINISTRADOR")`), así que el **cajero recibe 403** y solo puede usar `GET /api/pedidos`.
- `GET /api/pedidos` no trae `codigo_orden` y sus `detalles` no traen los nombres de la presentación, de la variante ni los agregados.

## Qué se pide (cualquiera de las dos)

1. **Permitir el rol `CAJERO` en lectura** de `GET /api/v1/mozo/pedidos` y `GET /api/v1/mozo/pedidos/:id` (solo esas dos rutas, sin crear ni modificar). La app ya sabe leer ese detalle completo (número, presentaciones, variantes, agregados, táper).
2. **O completar `GET /api/pedidos`** con `codigo_orden` en cada pedido y, en cada fila de `detalles`: `carta_presentacion_id` y `presentacion_nombre`/`volumen_ml`, `carta_variante_id` y `variante_nombre`, y los agregados/modificadores elegidos.

## Lado del frontend

Lista para mostrar lo que llegue: toma `codigo_orden` si viene, y busca presentación y variante por id en la carta cargada. Mientras el servidor no lo envíe, el cajero seguirá viendo el prefijo del id y sin presentaciones. La app no inventa el número ni los detalles.

## Actualización del ítem 18: la ruta ya está abierta al cajero, pero filtra por usuario

`GET /api/v1/mozo/pedidos` y `GET /api/v1/mozo/pedidos/:id` ya aceptan el rol `CAJERO` (`mozoLectura`), pero el repositorio sigue filtrando por el usuario que consulta (`pedido_mozo_repository.go`: lista en la consulta de ~línea 157 con `AND p.usuario_id = $2`, y detalle en ~línea 281 con `AND p.usuario_id = $3`). El cajero solo recibe sus propios pedidos (ninguno), así que su comanda sigue mostrando el listado antiguo: otro número (`#1047` en vez de `#0008`), el táper como "Plato" y sin la cantidad de tápers.

**Se pide:** en esas dos consultas de **lectura**, no filtrar por usuario cuando el rol es `CAJERO` o `ADMINISTRADOR` (mismo patrón que ya se usa en otra consulta: `AND ($2::uuid IS NULL OR p.usuario_id = $2)`, pasando `NULL` para esos roles). Las rutas que modifican pedidos siguen restringidas al mozo dueño.

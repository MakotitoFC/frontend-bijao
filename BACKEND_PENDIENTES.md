# Pendientes del backend

Estado revisado contra el commit `6a28e71` del backend (28-oct-2026). Solo quedan los ítems **sin resolver**.

**Ya resueltos por el backend (quitados de este archivo):** lectura de pedidos por el cajero (1), semillas de medios de pago y categorías (3), `uploads/` en `.gitignore` (9), series de comprobantes por caja (12), número de orden y detalle para el cajero (18), grupo de medios de pago (19), efectivo recibido y vuelto (22), columna `apertura_caja.caja_id` (23) y comprobante "Solo Consumo".

**Sin volver a comprobar en el código:** los ítems 2, 4 a 8, 10, 13 y 15 vienen de revisiones anteriores; que el backend confirme cuáles siguen abiertos.

## Ítems

2. `GET /api/carta` repite los platos con variantes o presentaciones
4. El rol MOZO conserva `CREAR.PAGO`
5. Caja: efectivo esperado, tres puntos a revisar
6. Solicitud: varios tápers por plato
7. Vender un táper sin stock suficiente
8. Aviso: los pedidos en mesa ya no llevan nombre de cliente
10. Comprobantes: imprimir con los datos de Lucode y espera de SUNAT
11. Turnos de los mozos (mañana y tarde-noche)
13. DNI en boletas (aviso)
14. Reportes: rutas que necesita la vista (habilitada para el administrador)
15. Pago compartido con un comprobante distinto por pagador
17. (Confirmar si el commit 0552d58 ya lo resolvió) Error al emitir comprobantes en pagos compartidos: "el campo total no coincide con la sumatoria de los ítems"
20. Mesas unidas: el pedido solo toma la primera mesa
21. Delivery lo registran caja y administración; caja abierta para todos; cambio de mesa
24. Delivery al imprimir, reimpresión de la cuenta y fecha de pago
25. Guardar los datos del negocio y del restaurante
26. Traspaso de pedidos entre mozos (con aceptación)
27. Qué categorías y platos se imprimen en la comanda de cocina
28. El administrador debe poder operar los pedidos de cualquier usuario
29. Pedido de personal: el precio de cada plato se escribe a mano

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

El backend ya tiene turnos de caja (`/configuracion/turnos`), pero **no hay turno por mozo ni límite de acceso** al iniciar sesión. El frontend no lo implementa hasta que exista.

## Qué se pide

- **Turnos configurables:** una tabla o ajuste con nombre, hora de inicio y hora de fin de cada turno (el de tarde-noche cruza la medianoche), con endpoints de lectura y edición para el administrador.
- **Turno por usuario:** que cada usuario con rol mozo tenga asignado un turno (o ninguno) y que se pueda cambiar desde Configuración.
- **Límite de acceso:** el login (y las peticiones con sesión abierta) de un mozo debe rechazarse fuera de su turno, con un error claro, por ejemplo `403 fuera_de_turno`, que incluya el horario del turno para mostrarlo en la app. El administrador, el cajero y el trabajador no se ven afectados. Si el mozo tiene una sesión abierta cuando termina su turno, debe poder expirar o cerrarse.
- **Permisos:** `LEER.TURNO`, `CREAR.TURNO`, `ACTUALIZAR.TURNO` para el rol administrador.

## Lado del frontend (pendiente)

Una vez definido, la app agrega en Configuración una vista de turnos, un selector de turno en el usuario mozo y el mensaje de "fuera de turno" al iniciar sesión.

---

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

# 17. (Confirmar si el commit 0552d58 ya lo resolvió) Error al emitir comprobantes en pagos compartidos: "el campo total no coincide con la sumatoria de los ítems"

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

# 20. Mesas unidas: el pedido solo toma la primera mesa

## Síntoma

Al unir mesas (por ejemplo T-1 y T-3) y crear el pedido, el servidor solo registra la primera mesa. La unión vive solo en la memoria de la app: se pierde al recargar y los demás dispositivos no la ven.

## Causa (revisado en el backend)

La tabla `mesa_pedido` ya admite **varias mesas por pedido** (una fila por mesa), pero `POST /api/v1/mozo/pedidos` recibe un solo `mesa_id` y `pedido_mozo_repository.go` inserta una sola fila en `mesa_pedido`. La app guarda la unión en una lista local (`gruposUnidos`).

## Qué se pide

- **Crear** el pedido con una lista de mesas (por ejemplo `mesas_ids`), insertar una fila en `mesa_pedido` por cada una y marcar **todas** como ocupadas. Si llega solo `mesa_id`, seguir funcionando igual.
- **Devolver** la lista de mesas del pedido en el listado y en el detalle (`mesas`: número e id de cada una), para que todos los dispositivos vean la unión.
- **Liberar** todas las mesas del pedido al cobrarlo o anularlo (cerrar todas las filas de `mesa_pedido`).
- Opcional: desunir una mesa de un pedido en curso.

## Lado del frontend

Enviar todas las mesas de la unión al crear el pedido y mostrar la unión que devuelve el servidor, en vez de la lista local. Mientras el servidor no lo devuelva, la unión sigue solo en la app.

---

# 21. Delivery lo registran caja y administración; caja abierta para todos; cambio de mesa

## Delivery: el cajero debe poder crear pedidos de delivery

Decisión: los pedidos de **delivery** los registran **mozo, caja (cajero) y administración**. El monto del delivery es **obligatorio** (varía por pedido) y se escribe al crear el pedido, junto con el nombre, el celular y la dirección. La app muestra Delivery como tipo de pedido a todos los roles y agrega un botón "Nuevo delivery" en las comandas del cajero.

Hoy `POST /api/v1/mozo/pedidos` está limitado a `MOZO` y `ADMINISTRADOR` (`main.go`), así que el cajero recibiría 403. Se pide:

- Permitir al rol `CAJERO` crear pedidos **solo de tipo delivery** (y sus productos, `POST /:id/items`), con `CREAR.PEDIDO` y `CREAR.PEDIDO_DETALLE`.
- Rechazar en el servidor un delivery sin `costo_envio` (campo obligatorio, se acepta 0), con un error claro. **Ya no** se debe rechazar un delivery creado por un mozo.
- Opcional: ruta para que caja y administración cambien el costo de envío de un delivery ya creado.

## Estado de la caja para todos los roles

`GET /api/v1/caja/estado-actual` exige `LEER.CIERRE_CAJA`, y el mozo probablemente no lo tiene, por lo que la app no puede saber que la caja está cerrada. Se pide una ruta liviana (por ejemplo `GET /api/v1/caja/abierta` → `{ "abierta": true }`) que puedan leer todos los roles, y **rechazar la creación de pedidos con la caja cerrada** (`409`, con código `CAJA_CERRADA`).

## Cambio de mesa

**Caso real:** el cliente de la mesa 24, con su pedido ya hecho, se pasó a la mesa 1 y el sistema no lo reflejó. Se debe poder mover el pedido a la mesa 1: la mesa 24 queda **libre** y la mesa 1 **ocupada**, lo hace el mozo del pedido.

## Lo que ya hace `PATCH /api/v1/mozo/pedidos/:id/cambiar-mesa`

Revisado en el código: valida que el pedido no esté pagado ni anulado y que la mesa destino sea de la sede y esté disponible; cierra el vínculo con la mesa de origen (`mesa_pedido.hora_fin`), la deja `disponible` si no tiene otros pedidos, ocupa la destino, crea el nuevo `mesa_pedido`, agrega una nota de auditoría al `comentarios` del pedido y emite el evento `CAMBIO_MESA`. **No crea trabajos de impresión.**

## Qué se pide

1. **Cocina no debe reimprimir:** confirmar (con una prueba) que al cambiar de mesa **no se imprime** de nuevo la comanda ya impresa, porque parecería un pedido nuevo. Los platos que se agreguen después sí se imprimen, pero con el **número de la mesa nueva** (que el trabajo de impresión lea la mesa vigente de `mesa_pedido`, la de `hora_fin IS NULL`).
2. **Historial real:** hoy el cambio solo queda como texto dentro de `comentarios` ("[Traspasado de Mesa 24 a Mesa 1 por X el …]"). Se pide un registro propio (por ejemplo `pedido_historial`: pedido, tipo de evento `cambio_mesa`, mesa origen, mesa destino, usuario, fecha) y una ruta para leerlo (`GET /api/v1/mozo/pedidos/:id/historial`). El mismo registro serviría para los traspasos entre mozos (ítem 26).
3. **Quién puede hacerlo:** el mozo dueño del pedido. Decidir si la ruta deja pasar al administrador en pedidos de otros mozos (hoy la consulta no filtra por dueño; la restricción está solo en la app).
4. **Mesa destino ocupada:** hoy se rechaza ("ya tiene un pedido en curso. Debe liberarse primero"). Para este caso (mesa libre) no hace falta cambiarlo.

## Lado del frontend

El botón "Cambiar mesa o entrega" del detalle llama a esa ruta y recarga las mesas; el aviso dice qué mesa quedó libre y cuál ocupada. No imprime nada al cambiar de mesa. Cuando exista la ruta del historial, se agrega la pestaña "Historial" en el detalle del pedido.

---

# 24. Delivery al imprimir, reimpresión de la cuenta y fecha de pago

## El monto del delivery no sale al imprimir ni se suma (confirmar: el comprobante ya tiene `incluir_delivery`; falta la cuenta y el ticket)

En pantalla el cargo por delivery se ve y se suma al total, pero lo que **imprime el servidor** (cuenta, ticket de venta y comprobante) no lo trae. Se pide agregar la línea **CARGO POR DELIVERY** y que el total impreso y el del comprobante lo incluyan (el monto sale de `costo_envio` del pedido).

## Reimprimir la cuenta, también ya pagada

Caja y administración deben poder **imprimir y reimprimir la cuenta las veces que quieran**, esté o no pagado el pedido, y sin importar quién lo tomó. Hoy `POST` de reimpresión (`tipo: 'cuenta'`) debe verificarse para `CAJERO` y `ADMINISTRADOR`: que no exija ser el mozo dueño ni un pedido sin pagar. La app ya muestra el botón "Imprimir cuenta" a ambos.

## Cierre de caja sin límite de horas

No encontré en el backend ninguna regla de 12 horas ni cierre automático (`CerrarCaja`/`RegistrarCierre` no comparan horas). Si hay una regla en el servidor o en otro proceso, hay que quitarla para que cajero y administrador cierren cuando quieran. Confirmar con el backend si existe.

## Historial de ventas por fecha de pago

El historial de ventas ahora muestra la **fecha y hora del pago** (no la del pedido) y filtra el día por esa fecha. Se pide que `GET /api/pagos` (por rango de fechas) filtre por **`fecha_pago`**, y que el pedido de un pago hecho en el rango venga en la lista de pedidos aunque se haya tomado otro día (por ejemplo, tomado a las 23:50 y cobrado a las 00:10). Los totales de Caja por grupo de medio de pago deben filtrarse igual, por `fecha_pago`.

---

# 25. Guardar los datos del negocio y del restaurante

En Configuración, "Información del negocio" y "Restaurante" ahora tienen Editar / Guardar. Hoy solo se puede guardar en el servidor la **dirección y el teléfono de la sede de la sesión**, con `PUT /api/v1/sede/config` (solo ADMINISTRADOR; la app lee la configuración y reenvía los datos fiscales para no borrarlos).

## Qué falta

- **Información del negocio:** nombre comercial, correo de contacto, moneda, idioma, país y zona horaria no tienen dónde guardarse. Se pide una ruta (por ejemplo `GET/PUT /api/v1/negocio`) y sus columnas.
- **Restaurante activo / inactivo:** el interruptor "Activo" de cada restaurante no se guarda en el servidor.
- **Varios restaurantes:** la ruta actual solo edita la sede del usuario. Para editar otro restaurante haría falta `PUT /api/v1/sedes/:id`.

## Lado del frontend

Dirección y teléfono se guardan en el servidor; el resto queda en la app mientras esté abierta. Al existir las rutas, solo se conecta el botón Guardar.

---

# 26. Traspaso de pedidos entre mozos (con aceptación)

## El pedido

Cuando un mozo termina su turno y deja pedidos pendientes, el cliente a veces quiere agregar platos y solo el mozo dueño puede modificar su pedido. Se pide que el mozo que se va pueda **traspasar** sus pedidos a otro mozo, y que el otro mozo **acepte o rechace**.

## Reglas

- El traspaso lo pide el mozo dueño del pedido.
- Se envía a **un solo mozo a la vez**: mientras haya una solicitud pendiente, no puede pedir otra para ese pedido.
- El mozo destino **acepta** (el pedido pasa a ser suyo y desde ese momento solo él lo modifica) o **rechaza** (el pedido sigue con el mozo anterior, que ya puede enviar la solicitud a otro mozo).
- Hasta que se acepte, el pedido sigue siendo del mozo anterior.

## Rutas que la app ya llama

Todas bajo `RequireRole("MOZO", "ADMINISTRADOR")`, salvo que se indique otra cosa. Si una ruta no existe, la app no muestra el aviso ni la bandeja y, al intentar traspasar, muestra el error del servidor.

| Método y ruta | Quién | Qué hace |
|---|---|---|
| `POST /api/v1/mozo/pedidos/:id/traspaso` con `{"mozo_destino_id": "<uuid>"}` | el mozo dueño del pedido | Crea la solicitud en estado `pendiente`. Rechazar con `409` si el pedido ya tiene una pendiente, si no está abierto, si el destino no es un MOZO activo de la sede o si es el mismo mozo. |
| `GET /api/v1/mozo/mozos` | cualquier mozo | Lista los **mozos activos de la sede** (`id`, `nombre`) para elegir a quién traspasar. Hoy el mozo no puede leer `GET /api/usuarios` (pide `LEER.USUARIO`). Sin esta ruta la lista queda vacía. |
| `GET /api/v1/mozo/traspasos?estado=pendiente` | cualquier mozo | Solicitudes pendientes **enviadas y recibidas** por el usuario. |
| `POST /api/v1/mozo/traspasos/:id/aceptar` | solo el mozo destino | Cambia `usuario_id` del pedido al destino (en una transacción) y marca `aceptado`. |
| `POST /api/v1/mozo/traspasos/:id/rechazar` | solo el mozo destino | Marca `rechazado`; el pedido sigue con el origen. |
| `POST /api/v1/mozo/traspasos/:id/cancelar` | solo el mozo origen | Marca `cancelado`. |
| `POST /api/v1/mozo/pedidos/:id/reasignar` con `{"mozo_destino_id": "<uuid>"}` | solo ADMINISTRADOR | Pasa el pedido al mozo destino **sin aceptación** (por ejemplo, si el mozo dueño ya se fue). Cancela cualquier solicitud pendiente de ese pedido y deja auditoría. |

Cada solicitud que devuelve el `GET` (y las respuestas) trae: `id`, `pedido_id`, `pedido_numero` (el `codigo_orden`), `ubicacion` ("Mesa 3", "Delivery"…), `mozo_origen_id`, `mozo_origen_nombre`, `mozo_destino_id`, `mozo_destino_nombre`, `estado` (`pendiente | aceptado | rechazado | cancelado`) y `created_at`.

## Reglas en el servidor

- Un solo traspaso pendiente por pedido (índice único parcial sobre `pedido_id` donde `estado = 'pendiente'`): así el mozo que se va ofrece el pedido a un mozo a la vez y solo envía otra solicitud cuando el destino rechaza o él cancela.
- Hasta que se acepte, el pedido sigue siendo del mozo anterior y solo él puede modificarlo.
- Al aceptar, dejar constancia (auditoría): quién, a quién, cuándo.
- Si el pedido se cobra, se anula o se cierra mientras hay una solicitud pendiente, pasarla a `cancelado`.
- **Sin vencimiento:** una solicitud pendiente se queda así hasta que el destino la acepte o rechace, o el origen la cancele (o el administrador reasigne).
- Aplica a pedidos de **mesa, para llevar y delivery**.

## Para después (opcional)

- Un evento en tiempo real (`TRASPASO_SOLICITADO` al destino y `TRASPASO_RESUELTO` al origen). Hoy la app consulta cada 4 a 32 segundos y abre un modal al detectar una solicitud nueva.

## Lado del frontend (ya hecho)

- El mozo dueño ve en el detalle de su pedido abierto un botón con el ícono de personas, "Traspasar a otro mozo", que abre la lista de mozos activos. Con una solicitud pendiente, el mismo botón (en naranja) permite cancelarla, y bajo el título dice "Traspaso pendiente a X".
- En Pedidos, al llegar una solicitud nueva se abre un **modal** con Aceptar y Rechazar (se avisa una vez por solicitud). Además queda un aviso naranja "Tienes N pedidos por aceptar" con el botón "Ver" para reabrirlo.
- El administrador ve en el detalle de cualquier pedido abierto el botón "Reasignar a otro mozo" (sin aceptación).
- Se consulta junto con los pedidos (cada 4 a 32 segundos).

---

# 27. Qué categorías y platos se imprimen en la comanda de cocina

## Problema

Hoy el pedido se imprime **completo** en cocina, aunque lleve un táper, una bebida o una paleta, que no se preparan allí.

## Lo que se quiere

El administrador elige **qué categorías van a cocina**. Dentro de una categoría que no va (por ejemplo Bebidas) hay platos que **sí** deben salir (limonada, aguaje y otros que se preparan en cocina); y al revés, en una categoría que sí va puede haber platos que no. Por defecto sale todo.

## Qué se pide

- Guardar las reglas por sede: una por categoría (`imprime` sí/no) y excepciones por plato (`imprime` sí/no; sin excepción, el plato sigue a su categoría).
- **Ruta que la app ya llama** (solo ADMINISTRADOR para escribir):
  - `GET /api/v1/impresion/reglas-cocina`
  - `PUT /api/v1/impresion/reglas-cocina`
  - Cuerpo y respuesta (reemplazo completo):
```json
{
  "categorias": [{ "categoria_id": "<uuid>", "imprime": false }],
  "platos": [{ "carta_id": "<uuid>", "imprime": true }]
}
```
  Solo viajan las categorías apagadas y las excepciones; una categoría que no aparece se imprime.
- **Al imprimir la comanda de cocina** (al crear el pedido y al agregar platos), dejar fuera las líneas que según estas reglas no van: plato con excepción → su valor; si no, la regla de su categoría. Si **no queda ninguna línea**, no crear el trabajo de impresión.
- Los **tápers** no van a la comanda de cocina.
- La **cuenta**, el ticket de venta y los comprobantes siguen llevando todo: la regla es solo de la comanda de cocina.
- Una **reimpresión** de la comanda aplica las mismas reglas.

## Lado del frontend (ya hecho)

Configuración → Negocio → **Impresión en cocina** (solo administrador): lista de categorías con un interruptor "Va a cocina"; al abrir una, cada plato tiene "Como la categoría / Sí sale / No sale". Un botón Guardar envía las reglas. Mientras el servidor no tenga la ruta, la pantalla avisa que todavía no se aplican.

---

# 28. El administrador debe poder operar los pedidos de cualquier usuario

## Problema

Las rutas de `/api/v1/mozo/pedidos` filtran por dueño: agregar o cambiar platos, cantidades, comentarios, tipo de entrega, anular, descuentos, promociones y demás usan `WHERE ... usuario_id = $dueño` (por ejemplo, en `pedido_mozo_repository.go` las consultas de las líneas ~757, 819, 1014, 1056, 1102, 1171, 1248, 1310, 1461 y 1630). Para el administrador esas operaciones sobre pedidos de otros usuarios devuelven "pedido no encontrado".

## Qué se pide

El **administrador no tiene límites**: puede crear y modificar pedidos, promociones, descuentos, tipo de entrega, mesa, etc. de **cualquier usuario** de su sede. Aplicar la excepción de rol ADMINISTRADOR en esas consultas (el filtro por dueño queda solo para el mozo) y conservar el dueño original del pedido; la auditoría debe registrar quién hizo el cambio.

## Lado del frontend (ya hecho)

La app ya deja al administrador operar cualquier pedido (antes solo los suyos). Mientras el servidor no lo permita, verá el error que devuelva.

---

# 29. Pedido de personal: el precio de cada plato se escribe a mano

## Cómo funciona

Solo **administración y caja** crean pedidos de personal (empleado). El precio **no es fijo**: se escribe plato por plato en el detalle del pedido, también para las variantes y presentaciones. Ya no se usa un porcentaje de descuento de empleado ni `carta.precio_personal` como valor fijo.

## Qué se pide

- **Crear:** en `POST /api/v1/mozo/pedidos` con `tipo: "empleado"`, cada ítem de plato trae **`precio_personal`** (por unidad, junto con `carta_id`, `carta_variante_id` o `carta_presentacion_id` y `cantidad`). Usarlo como precio de la línea en lugar del de la carta, y guardarlo para los reportes. Rechazar un ítem de un pedido de empleado sin `precio_personal` (con `0` permitido).
- **Quién:** el rol `CAJERO` hoy no puede crear pedidos por esta ruta (ver ítem 21). Permitir también `CAJERO` y `ADMINISTRADOR` para `tipo: "empleado"`; el mozo no.
- **Editar el precio después:** ruta nueva **`PATCH /api/v1/mozo/pedidos/:id/items/:detalle_id/precio-personal`** con `{ "precio_personal": 8.5, "version": n }`, solo ADMINISTRADOR y CAJERO, solo en pedidos de empleado abiertos. Devuelve el pedido completo, como las demás rutas de ítems.
- Si se agregan platos a un pedido de empleado ya creado, el ítem también lleva `precio_personal`.

## Lado del frontend (ya hecho)

- Nuevo pedido (solo administrador y caja): interruptor "Pedido de personal"; con él, cada plato muestra un campo "Precio (S/)" en blanco y no se puede confirmar sin escribirlos todos. El total sale con esos precios.
- Detalle de un pedido de empleado abierto: un lápiz junto al precio de cada plato para corregirlo.
- Se quitó el ticket "Empleado" del Descuento extra y el interruptor "Permitir descuento de empleado" de Configuración.

# Pendientes del backend

## Lo que falta, por prioridad

Los cambios de esta versión de la app (modal de pagar, precio manual, pedidos de empleado, etiqueta "Empleado: Nombre") dependen de los **ítems 33, 34 y 35**. Los demás son anteriores.

1. **34.** Precio escrito a mano en un producto de la carta
2. **33.** Roturas o alquiler de menaje al cobrar un pedido
3. **35.** El ticket que imprime el servidor debe decir "Empleado: Nombre" en los pedidos de empleado
4. **21.** Caja cerrada, delivery del cajero y su permiso en el seed
5. **31.** `GET /api/pedidos` devuelve también las líneas anuladas
6. **7.** Vender un táper sin stock suficiente
7. **5.** Caja: efectivo esperado, tres puntos a revisar
8. **20.** Mesas unidas: el pedido solo toma la primera mesa
10. **13.** DNI en boletas (más de S/ 700)
11. **24.** Historial de ventas por fecha de pago
12. **30.** El cajero es el rol invitado: sus permisos por defecto
13. **36.** Descuentos guardados

---

# 34. Precio escrito a mano en un producto de la carta

## Qué hace la app

- Al registrar un pedido (y al agregar un producto desde el detalle), el modal del producto tiene un **lápiz junto al precio**: se escribe el precio de ese pedido y un **motivo** (obligatorio).
- En los **platos familiares** hay además "Cambio de plato": se elige por cuál plato se cambia (sus variantes o, si no tiene, otro plato de la carta) y un **adicional**. El precio queda en el de la carta más el adicional.
- El precio vale **solo para ese pedido**: no cambia la carta.

## Qué pasa hoy en el servidor

`CreateItemMozoRequest` solo acepta un precio distinto en `precio_unitario_libre` (plato libre) y `precio_personal` (pedido de empleado, y siempre se exige). Para un producto normal ignora cualquier precio y cobra el de la carta, así que **la cuenta del servidor no coincide con la de la app**.

Además, `PATCH …/items/:detalle_id/precio-personal` responde "solo se puede modificar el precio manual en pedidos de tipo personal (empleado)". Por eso el botón **Empleado** del detalle de un pedido normal falla con ese error.

## Qué se pide

- Aceptar en cada ítem de `POST /api/v1/mozo/pedidos` y de `POST /:id/items` un campo **`precio_manual`** (precio por unidad) que reemplace el de la carta **solo en esa fila**, sin tocar la carta.
- Guardar el motivo: la app lo manda hoy dentro de `comentario` como una línea `Precio manual: …`. Mejor un campo propio **`motivo_precio`**.
- Auditar el cambio: quién, precio de carta, precio manual y motivo.
- Que el `PATCH …/precio-personal` (o uno equivalente) sirva también en pedidos normales, para corregir el precio de un pedido ya registrado y para el botón Empleado del detalle.

---

# 33. Roturas o alquiler de menaje al cobrar un pedido

## Qué hace la app

En el modal de Pagar, sección **Extras**, hay un interruptor **Roturas / alquiler**: se busca el menaje (plato, vaso, copa, cubierto, jarra… o "Otro" escrito a mano), se escribe el costo y se agrega. Se pueden agregar varios. Se suman al total a cobrar y al efectivo, sin recargo del medio de pago, y salen como una línea por cada cosa en la boleta, el ticket de venta y la cuenta que arma la app.

## Problema

Hoy esos cargos solo viven en la app (`cargos_extra_store.dart`): el servidor no los conoce, así que no entran en el cierre de caja, los reportes ni los comprobantes electrónicos.

## Qué se pide

- Un registro de cargos extra por pedido: `pedido_id`, `concepto` (rotura o alquiler), `producto` (texto) y `monto`.
- Que `POST /api/pagos` los acepte junto al cobro (o un endpoint aparte) y que el ingreso entre en la caja del turno.
- Que salgan como ítems en el comprobante electrónico. Decidir si el monto cuenta dentro de la venta (con IGV) o aparte.

---

# 35. El ticket que imprime el servidor debe decir "Empleado: Nombre"

## Qué hace la app

En un pedido de empleado, la tarjeta y el detalle muestran la etiqueta **Empleado: Nombre**, y los tickets que arma la app (boleta, ticket de venta, cuenta en texto) dicen `Empleado: Nombre` en lugar de `Cliente: …`. El nombre se escribe en el campo del cliente al crear el pedido.

## Qué se pide

Que la comanda, la cuenta y los comprobantes que imprime el servidor (`printer_service.go`) usen **`EMPLEADO: Nombre`** cuando el pedido es `tipo = 'empleado'`, en lugar de `CLIENTE`. Hoy imprimen siempre "Cliente".

---

# 21. Caja cerrada, delivery del cajero y su permiso en el seed

## Ya resuelto

`POST /api/v1/mozo/pedidos` ya se controla por permiso (`CREAR.PEDIDO`), no por rol fijo, y `PATCH …/cambiar-mesa` existe.

## Lo que falta

1. **Caja abierta para todos los roles:** `GET /api/v1/caja/estado-actual` exige `LEER.CIERRE_CAJA` y el mozo no lo tiene, así que la app no puede saber que la caja está cerrada. Se pide una ruta liviana, por ejemplo `GET /api/v1/caja/abierta` → `{ "abierta": true }`, que lean todos los roles.
2. **Rechazar pedidos con la caja cerrada:** hoy el servidor no lo valida. Que `POST /api/v1/mozo/pedidos` responda `409` con código `CAJA_CERRADA`.
3. **El cajero no puede crear pedidos:** el seed del rol CAJERO no trae `CREAR.PEDIDO` ni `CREAR.PEDIDO_DETALLE`, así que recibe 403 al crear un delivery o un pedido de empleado. Agregar esos permisos al cajero en el seed.
4. **`costo_envio` obligatorio en delivery:** hoy el servidor solo rechaza un costo negativo. Que un delivery sin `costo_envio` (se acepta 0) devuelva un error claro.
5. **Cambio de mesa:** confirmar con una prueba que no reimprime la comanda ya impresa y que los platos agregados después salen con el número de la mesa nueva.

---

# 31. `GET /api/pedidos` devuelve también las líneas anuladas

## Problema

La lista general de pedidos (`GET /api/pedidos`, la que usan el administrador y el cajero) trae **todas** las filas de `pedidos_detalle` del pedido, incluidas las **anuladas o devueltas** (`estado = 'anulado'` o `'devuelto'`) y las borradas (`deleted_at`). La consulta de detalles (`pedido_repository.go`) solo filtra por `pd.pedidos_id`.

Efecto: si se corrige el precio de un plato y se quita la línea vieja para agregar la nueva, la vieja **sigue saliendo** en la cuenta y en la vista previa del comprobante, y se suma al total. En `GET /api/v1/mozo/pedidos` (el del mozo) no pasa, porque esa ruta ya las deja fuera.

## Qué se pide

- Que `GET /api/pedidos` y `GET /api/pedidos/:id` excluyan de `detalles` las filas con `estado IN ('anulado', 'devuelto')` o `deleted_at IS NOT NULL`, igual que la ruta del mozo. (Quedan guardadas en la base para la auditoría; solo no se devuelven como parte de la cuenta.)
- Revisar que los totales del pedido y de la caja no cuenten esas filas.

## Lado del frontend (ya hecho)

La app ya descarta esas líneas al leer la lista general. Con este ajuste del servidor deja de depender de ese filtro.

---

# 7. Vender un táper sin stock suficiente

En los pedidos la app muestra el **stock** de cada táper, pero **ya no bloquea** agregarlo si no alcanza (el stock es solo informativo).

Hoy el backend sí lo rechaza: `descontarStockTaper` (`internal/repositories/pedido_mozo_repository.go`) devuelve el error `stock insuficiente de '…'` y el pedido no se crea ni se agrega el producto.

## Qué se pide

Permitir registrar el pedido aunque el stock del táper no alcance: no devolver error y dejar el stock en cero o negativo, según lo que prefiera el negocio. Idealmente, dejar rastro del faltante en el movimiento de inventario.

---

# 5. Caja: efectivo esperado, tres puntos a revisar

`GetTotalesCajaActual` (`internal/repositories/caja_repository.go`, ~línea 1295 a 1363) calcula:

> efectivo esperado = monto inicial + cobros en efectivo + ingresos en efectivo − salidas en efectivo

La fórmula es coherente y no duplica los cobros. A revisar:

1. **"Efectivo" se detecta por el nombre exacto** (`"efectivo"` en minúsculas). Un método llamado, por ejemplo, "Efectivo S/" no cuenta como efectivo, y cualquier nombre que no reconoce cae en el grupo **tarjeta**. Conviene identificar el tipo de método con un campo, no por el nombre.
2. **La propina no entra** en el efectivo esperado (se guarda aparte del pago). Si el cajero recibe la propina en efectivo y la deja en el cajón, el cierre mostrará que sobra. Definir si debe sumarse.
3. **Anular un movimiento automático no cambia los totales.** Cada cobro crea un movimiento "Cobro de pedido" ligado al pedido (`pedidos_id`), y los totales **excluyen** esos movimientos (`m.pedidos_id IS NULL`). La app los lista con Editar y Anular; si alguien anula uno queda tachado pero el efectivo esperado sigue igual. Se pide que el backend rechace editar o anular movimientos que tengan `pedidos_id`, o que defina qué debe pasar con el total.

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



# 13. DNI en boletas (aviso)

La app exige el DNI (8 dígitos) cuando la boleta es de **más de S/ 700**; hasta S/ 700 (inclusive) es opcional y sale como `CLIENTES VARIOS`. El backend debería validar lo mismo: rechazar una boleta de más de S/ 700 sin DNI.

---

# 24. Historial de ventas por fecha de pago 

El historial de ventas muestra la **fecha y hora del pago** (no la del pedido) y filtra el día por esa fecha. Se pide que `GET /api/pagos` (por rango de fechas) filtre por **`fecha_pago`**, y que el pedido de un pago hecho en el rango venga en la lista aunque se haya tomado otro día (tomado a las 23:50 y cobrado a las 00:10). Los totales de Caja por grupo de medio de pago deben filtrarse igual.


# 30. El cajero es el rol invitado: sus permisos por defecto

## Ya resuelto

Las rutas de pedidos ya usan `RequirePermission(...)`, de modo que lo que el administrador marque en `rol_permiso` y `permiso_usuario` se cumple.

## Lo que falta

- **Permisos por defecto del cajero en el seed**, iguales a lo que hace hoy (pedidos, ventas, caja, cobros, delivery y pedidos de personal): hoy el seed del CAJERO no incluye `CREAR.PEDIDO` ni `CREAR.PEDIDO_DETALLE` (ver ítem 21).
- **Permisos por acción** que el administrador pueda dar o quitar al cajero: abrir y cerrar caja, registrar ingresos y salidas, anular, dar descuentos, devolver, crear pedidos y crear pedidos de personal, cada uno comprobado en el servidor.
- Revisar las rutas que todavía usan `RequireRole(...)` fijo y que el cajero debería poder abrir según sus permisos (por ejemplo las de impresión).

Para la app, mientras esto no esté, la barra de vistas sigue ocultando por rol varias vistas al cajero. Se cambia a "solo por permiso" cuando se confirme este ítem.

---

# 37. Reporte detallado del día: no salen las anulaciones

## Síntoma

En Caja > Reportes > "Detallado Día", la sección de anulaciones sale vacía aunque se anularon pedidos o platos.

## Causa (revisado en el backend, `caja_repository.go`, consulta `queryAnulaciones`)

Con una caja abierta, la consulta solo trae las anulaciones de pedidos que **tienen un pago en esa apertura** (`EXISTS (SELECT 1 FROM pago ... apertura_caja_id = $2)`). Un pedido o plato anulado antes de cobrarse no tiene pago, así que nunca aparece. Además, si una fila falla al leerse (`Scan`), se descarta en silencio.

## Qué se pide

Filtrar las anulaciones por la fecha/hora de la anulación dentro del turno (o por `pedido_anulado.created_at` entre la apertura y el cierre), no por la existencia de un pago. Registrar el error de lectura en vez de ignorarlo.

---

# 38. Roturas / alquiler y propina en el ticket y los comprobantes

## Qué hace la app

Las roturas o alquiler de menaje se envían con el pago (`cargos_extra`) y a la boleta/factura como ítems `Rotura/alq. X` (o como `otros_extras` si no se editan ítems). La vista previa del ticket y el detalle del pedido ya muestran roturas y propina.

## Qué se pide

Que el ticket impreso por el servidor (cuenta, ticket de venta, boleta y factura) incluya la **propina** del pago (`pago.propina`) y los `cargos_extra` guardados, cada uno en su línea y dentro del total.

---

# 39. Editar un producto ya registrado en el pedido

## Qué se quiere

En el detalle del pedido, al tocar la card de un producto, abrir el mismo modal del registro ("Agregar al pedido") con lo que ya tiene (cantidad, variante o presentación, extras, nota, tipo de entrega, precio manual con su motivo, cambio de plato) y guardar los cambios sobre la misma fila. Es lo que ya hace el registro de pedido antes de enviarlo.

## Qué hay hoy

Solo hay rutas para cambiar una cosa a la vez: `PATCH /api/v1/mozo/pedidos/:id/items/:detalle_id/cantidad`, `/comentario`, `/tipo-entrega` y `/precio-personal`. No hay forma de cambiar variante, presentación, extras ni precio manual de una fila ya enviada. Hacerlo con anular + agregar nuevo deja una anulación falsa en la auditoría y puede mover el stock dos veces.

## Qué se pide

`PATCH /api/v1/mozo/pedidos/:id/items/:detalle_id` con el mismo cuerpo de un ítem de `POST .../items` (`carta_id`, `cantidad`, `carta_variante_id`, `carta_presentacion_id`, `modificadores`, `comentario`, `tipo_entrega`, `precio_manual`) más `version`:

- Reemplaza la fila en la misma transacción y recalcula el precio.
- Ajusta el consumo de stock por la diferencia, no devolviendo y descontando todo.
- Solo si la fila no está servida ni tiene pagos (o con el permiso `UPDATE.PEDIDO_DETALLE`, igual que cantidad y comentario).
- Registra la edición en el historial del pedido, sin crear una anulación.
- Devuelve el pedido actualizado, como las demás rutas de filas.

La app ya tiene el modal listo para reutilizar (`ProductoOpcionesDialog` con `lineaInicial`): al tener la ruta, solo hay que conectar el toque de la card del detalle.

---

# 40. Ticket de venta con S/ 0.00 en pagos por partes (empleados)

## Síntoma

Al pagar un pedido por abonos (por ejemplo 3.50 en 1.50 y 1.00), el modal "Comprobante emitido" muestra `Ticket de venta · Interno · S/ 0.00`.

## Causas (revisado en el backend)

1. **`ExisteComprobanteActivo` devuelve el comprobante incompleto** (`facturacion_repository.go`). Su `SELECT` solo trae `id, sede_id, pedidos_id, tipo_documento, serie, numero, estado_sunat`: no lee `total`, `total_gravado`, `total_igv`, cliente ni fechas. Cuando ya existe un ticket de venta del pedido, `EmitirComprobante` devuelve esa estructura (`return compActivo, nil`) y la app ve `total = 0`. Pasa en el 2.º abono y en cualquier reemisión.
2. **Un solo ticket por pedido.** Con `pago_id` vacío, el 2.º abono no genera un ticket nuevo: reimprime el primero. Un ticket "de lo que se va pagando" necesita uno por pago (`pago_id`).
3. **Descuento aplicado dos veces.** `ObtenerDatosPedidoParaFacturacion` (pedido completo) ya prorratea el descuento en los ítems, y `EmitirComprobante` vuelve a restar `datosPedido.Descuento` a `baseItemsTotal`. Con un descuento (por ejemplo de empleado) el total puede quedar en 0.

## Qué se pide

- Que `ExisteComprobanteActivo` lea todas las columnas del comprobante (o que `EmitirComprobante` recargue el comprobante completo por id antes de devolverlo).
- No restar `Descuento` otra vez en `EmitirComprobante` cuando los ítems ya vienen prorrateados.
- Mantener un ticket por `pago_id` (la app ya lo pide así en los abonos parciales).

## Lado de la app (ya hecho)

En un abono parcial (queda saldo) la app emite el comprobante con el `pago_id` del abono, así el ticket muestra lo que se paga en ese momento; al saldar la cuenta emite el de toda la cuenta.

---

# 41. Ya existe en el backend: editar un producto del pedido (reemplaza al punto 39)

Se encontró `PATCH /api/v1/mozo/pedidos/:id/items/:detalle_id` (`UpdateItemFila`, permiso `UPDATE.PEDIDO_DETALLE`). La app aún no lo usa: falta conectar el toque de la card del detalle con esa ruta (el modal ya se puede reabrir con lo que tenía el producto).

---

# 42. Rol CAJERO: las mismas acciones del administrador en pedidos

## Qué hace la app (ya hecho)

El cajero entra solo a **Pedidos, Ventas y Caja**, y en Pedidos usa la misma pantalla del administrador: crear pedidos (incluidos los de empleado), agregar y quitar productos, descuentos, traspasos y reasignaciones, cobrar y anular.

## Qué falta en el backend (revisado)

1. **Ve solo sus pedidos.** `GetPedidosMozo` y `GetPedidoMozoDetalle` filtran por `usuario_id` salvo para el administrador (`r.esAdmin`). El cajero debería ver los de todos los mozos, igual que el administrador.
2. **Mesas por liberar y liberar mesa:** `GetMesasPorLiberar` y `LiberarMesa` distinguen solo `esAdmin`; el cajero debería contar igual.
3. **Reasignar un pedido** (`POST /api/v1/mozo/pedidos/:id/reasignar`) es solo `ADMINISTRADOR`.
4. **Permisos del rol CAJERO.** La migración 00012 le dio `CREAR.PEDIDO` y `CREAR.PEDIDO_DETALLE`. Para igualar al administrador en pedidos faltan, como mínimo: `UPDATE.PEDIDO`, `UPDATE.PEDIDO_DETALLE`, `CREAR.PEDIDO_ANULADO`, `CREAR.DESCUENTO_APLICADO` y `LEER.MESA` (para elegir la mesa al crear).
5. **Anulación sin PIN:** si el administrador anula sin PIN de supervisor, el cajero debería poder igual.

---

# 43. Traspaso de responsable de caja: aviso al receptor y registro para seguimiento

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

## Qué hará la app con esto

- Al nuevo responsable le sale un modal "Te traspasaron la caja": quién, a qué hora, el motivo y el botón **Ir a Caja** (en vivo por el evento, o al abrir la app por la lista de no vistos).
- A quien traspasa se le confirma con el nombre del receptor.
- En Caja se podrá ver el historial de traspasos del turno.

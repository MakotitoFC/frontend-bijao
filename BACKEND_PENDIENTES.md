# Pendientes del backend

Lista revisada contra el código de `backend_bijao`. Solo quedan los puntos que
**todavía faltan**. Lo que el backend ya resolvió se quitó (precio manual y
motivo, edición de un producto del pedido, cargos extra al cobrar, "EMPLEADO:"
en el ticket, `GET /api/v1/caja/abierta`, permisos de pedidos del cajero en el
seed, líneas anuladas en la lista de pedidos, táper sin stock, mesas unidas,
DNI de más de S/ 700, filtro de pagos por fecha de pago, anulaciones del
reporte del día, grupo del medio de pago, movimientos automáticos de cobro,
traspaso entre mozos y traspaso de caja con su evento).

## Resumen

1. **44.** Pedidos ya cobrados que quedaron como `servido` o `pendiente` (reparación de datos)
2. **40.** Ticket de venta con S/ 0.00 en pagos por partes
3. **42.** Rol CAJERO igual al administrador en pedidos
4. **21.** Pedidos con la caja cerrada y costo de delivery
5. **38.** Roturas / alquiler en el ticket que imprime el servidor
6. **5.** Propina en el efectivo esperado de la caja

---

# 44. Pedidos ya cobrados que quedaron como `servido` o `pendiente`

## Síntoma

El pedido #0014 (01/11/2026, mozo Alexis, S/ 4.00) figuraba como **Servido** en
la lista de pedidos aunque ya tenía su cobro de S/ 4.00 registrado en Caja (14:28).
Al pulsar Pagar, la app lee los pagos del servidor, ve la cuenta saldada, y el
pedido desaparece de la cola.

## Causa (revisado en el backend)

- Al registrar un pago, `RegistrarPagoTx` (`caja_repository.go`) marca el pedido
  como `pagado` cuando el saldo queda en cero o menos.
- Si después alguien llama a `servido` o `pendiente`, hoy el backend lo impide:
  la ruta del mozo (`CambiarEstadoPedidoMozo`) y la ruta antigua
  (`UpdateEstadoPedido`, `pedido_repository.go`) respetan el estado `pagado`.
- Esas protecciones se agregaron **después**. Los pedidos que ya habían quedado
  mal (cobrados y vueltos a `servido`) siguen así en la base de datos. Es un
  problema de **datos antiguos**, no de la lógica actual.

## Qué se pide

1. **Revisar** cuántos pedidos están en esa situación (consulta de abajo).
2. **Repararlos una sola vez** con el `UPDATE` de abajo, revisando antes el
   listado.

El total del pedido se calcula igual que en `RegistrarPagoTx`: detalles activos
menos descuentos, más delivery y cargos extra. Solo se cuentan los pagos
`activo`.

### 1. Pedidos cobrados que siguen como `pendiente` o `servido` (los del tipo #0014)

```sql
WITH calc AS (
  SELECT p.id, p.numero_pedido, p.estado, p.fecha_pedido,
    COALESCE((SELECT SUM(pd.precio) FROM pedidos_detalle pd
      WHERE pd.pedidos_id = p.id AND pd.deleted_at IS NULL
        AND pd.estado NOT IN ('anulado','devuelto')), 0)
    - COALESCE((SELECT SUM(da.monto_aplicado) FROM descuento_aplicado da
      WHERE da.pedidos_id = p.id), 0)
    + COALESCE((SELECT SUM(d.costo_envio) FROM delivery d
      WHERE d.pedidos_id = p.id), 0)
    + COALESCE((SELECT SUM(pce.monto) FROM pedido_cargo_extra pce
      WHERE pce.pedidos_id = p.id), 0) AS total,
    COALESCE((SELECT SUM(pg.monto_abonado) FROM pago pg
      WHERE pg.pedidos_id = p.id
        AND COALESCE(pg.estado,'activo') = 'activo'), 0) AS pagado
  FROM pedidos p
  WHERE p.deleted_at IS NULL
)
SELECT * FROM calc
WHERE estado IN ('pendiente','servido')
  AND total > 0
  AND pagado >= total - 0.01
ORDER BY fecha_pedido DESC;
```

### 2. Reparación (después de revisar el listado anterior)

```sql
BEGIN;

WITH calc AS (
  SELECT p.id,
    COALESCE((SELECT SUM(pd.precio) FROM pedidos_detalle pd
      WHERE pd.pedidos_id = p.id AND pd.deleted_at IS NULL
        AND pd.estado NOT IN ('anulado','devuelto')), 0)
    - COALESCE((SELECT SUM(da.monto_aplicado) FROM descuento_aplicado da
      WHERE da.pedidos_id = p.id), 0)
    + COALESCE((SELECT SUM(d.costo_envio) FROM delivery d
      WHERE d.pedidos_id = p.id), 0)
    + COALESCE((SELECT SUM(pce.monto) FROM pedido_cargo_extra pce
      WHERE pce.pedidos_id = p.id), 0) AS total,
    COALESCE((SELECT SUM(pg.monto_abonado) FROM pago pg
      WHERE pg.pedidos_id = p.id
        AND COALESCE(pg.estado,'activo') = 'activo'), 0) AS pagado
  FROM pedidos p
  WHERE p.deleted_at IS NULL AND p.estado IN ('pendiente','servido')
)
UPDATE pedidos p
SET estado = 'pagado', version = p.version + 1, updated_at = CURRENT_TIMESTAMP
FROM calc
WHERE p.id = calc.id
  AND calc.total > 0
  AND calc.pagado >= calc.total - 0.01
RETURNING p.id, p.numero_pedido, p.estado;

-- Revisar lo devuelto; si es correcto: COMMIT; si no: ROLLBACK;
```

No toca las mesas (se liberan a mano, como ya está definido) ni los pedidos
sin pagos.

### 3. Otros registros con fallos parecidos (solo revisar, no reparar a ciegas)

Pedido marcado `pagado` pero con cobro menor al total (por ejemplo, un pago
anulado después):

```sql
-- misma CTE "calc" de arriba
SELECT * FROM calc
WHERE estado = 'pagado' AND pagado < total - 0.01;
```

Pagos registrados en cero (cobros de S/ 0.00 de pedidos con total mayor a cero):

```sql
SELECT pg.id, p.numero_pedido, p.estado, pg.monto_abonado, pg.fecha_pago
FROM pago pg JOIN pedidos p ON p.id = pg.pedidos_id
WHERE pg.monto_abonado = 0
  AND COALESCE(pg.estado,'activo') = 'activo'
ORDER BY pg.fecha_pago DESC;
```

Un cobro de S/ 0.00 solo es válido en cuentas en cero a propósito (familia,
empleado o cumpleaños). Cualquier otro caso es un registro erróneo para
anular o investigar.

---

# 40. Ticket de venta con S/ 0.00 en pagos por partes

## Síntoma

Al pagar un pedido por abonos, el modal "Comprobante emitido" muestra
`Ticket de venta · Interno · S/ 0.00`.

## Causas (revisado en `facturacion_repository.go` y `facturacion_service.go`)

1. **`ExisteComprobanteActivo` devuelve el comprobante incompleto.** Su `SELECT`
   solo trae `id, sede_id, pedidos_id, tipo_documento, serie, numero,
   estado_sunat`: no lee `total`, `total_gravado`, `total_igv`, el cliente ni
   las fechas. Cuando ya existe un ticket de venta, `EmitirComprobante` devuelve
   esa estructura (`return compActivo, nil`) y la app ve `total = 0`.
2. **Descuento restado dos veces.** `ObtenerDatosPedidoParaFacturacion` (pedido
   completo) ya prorratea el descuento en los ítems, y `EmitirComprobante`
   vuelve a restar `datosPedido.Descuento` a `baseItemsTotal`. Con un descuento
   (por ejemplo de empleado o "Cuenta cero") el total puede quedar en 0.

## Qué se pide

- Que `ExisteComprobanteActivo` lea todas las columnas del comprobante (o que
  `EmitirComprobante` recargue el comprobante completo por id antes de
  devolverlo).
- No restar `Descuento` otra vez en `EmitirComprobante` cuando los ítems ya
  vienen prorrateados.

(El backend ya admite un ticket por `pago_id`; la app lo pide así en los abonos
parciales.)

---

# 42. Rol CAJERO igual al administrador en pedidos

La app ya le da al cajero la misma pantalla de pedidos del administrador
(crear, modificar, descuentos, traspasos, cobrar y anular). Falta en el backend:

1. **Ve solo sus pedidos.** `GetPedidosMozo` y `GetPedidoMozoDetalle`
   (`pedido_mozo_repository.go`) filtran por `usuario_id` salvo cuando
   `esAdmin` (solo `administrador` / `admin`). El cajero debería ver los de todos
   los mozos, igual que el administrador.
2. **Mesas por liberar.** `GetMesasPorLiberar` y `LiberarMesa` distinguen solo
   `esAdmin`; el cajero debería contar igual.
3. **Reasignar un pedido.** `POST /api/v1/mozo/pedidos/:id/reasignar` es solo
   `ADMINISTRADOR`.
4. **Descuentos.** El seed del cajero no trae `CREAR.DESCUENTO_APLICADO`
   (sí trae `UPDATE.PEDIDO`, `UPDATE.PEDIDO_DETALLE`, `CREAR.PEDIDO_ANULADO` y
   `LEER.MESA`), así que no puede aplicar descuentos como el administrador.

---

# 21. Pedidos con la caja cerrada y costo de delivery

1. **Rechazar pedidos con la caja cerrada.** `POST /api/v1/mozo/pedidos` no
   valida que haya una caja abierta (no hay ningún error `CAJA_CERRADA`). Se pide
   responder `409` con ese código cuando la caja esté cerrada. (La ruta
   `GET /api/v1/caja/abierta` ya existe y la app la usa para avisar.)
2. **`costo_envio` en delivery.** `Delivery.CostoEnvio` es opcional
   (`*float64`) y solo se usa si viene. Se pide que un delivery sin
   `costo_envio` (se acepta 0) devuelva un error claro.

---

# 38. Roturas / alquiler en el ticket que imprime el servidor

La cuenta que imprime el servidor ya lleva la **propina** y el **recargo de
tarjeta** (`printer_service.go`), y el comprobante electrónico ya incluye los
cargos extra como ítems (`facturacion_repository.go`). Falta que la cuenta y el
ticket de venta **impresos** listen también los cargos extra
(`pedido_cargo_extra`: roturas o alquiler de menaje), una línea por cada cargo
con su producto y monto, y que entren en el total impreso.

---

# 5. Propina en el efectivo esperado de la caja

`GetTotalesCajaActual` (`caja_repository.go`) calcula el efectivo esperado con
el monto inicial, los cobros y los ingresos y salidas en efectivo, sin la
propina (que se guarda aparte del pago, en la tabla `propina`). Si el cajero
recibe la propina en efectivo y la deja en el cajón, el cierre mostrará que
sobra efectivo. Definir si la propina cobrada en efectivo debe sumarse (y
restarse cuando se entrega al mozo).

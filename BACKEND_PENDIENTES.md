# Pendientes del backend

Solo lo que sigue sin resolver, revisado contra el código del backend, la guía
`T0004` y el esquema `BD-3`. Lo que ya está corregido se quitó de esta lista.

## Esquema vs. código

1. **Columnas que el código usa y el esquema no tiene.** En `BD-3` (y en las
   migraciones 00001 a 00029) la tabla `pedidos` no tiene `total`, `mesa_id` ni
   `tipo_pedido`. Pero el archivo
   `internal/repositories/caja_repository.go` (commit `6f1690e`) las consulta
   en el cobro y en la caja. Para encontrarlas, buscar `p.total`,
   `p.mesa_id` o `tipo_pedido` en ese archivo:
   - `RegistrarPagoTx` (~línea 418): `SELECT p.total ... LEFT JOIN mesa m ON m.id = p.mesa_id`.
   - Resumen de pagos del pedido (~líneas 635 y 657) y `GET /pagos` (~línea 742).
   - Pedidos de caja (~líneas 1103 y 1226): `p.tipo_pedido`, `p.total`, `p.mesa_id`.
   - Totales de caja (~línea 925): `ped.tipo_pedido = 'delivery'` (ahí el error
     se ignora, así que el delivery saldría siempre en 0).

   Con ese esquema, `POST /api/pagos` fallaría con "column does not exist".
   No puedo ejecutar la base, así que lo dejo como duda: ¿la base real tiene
   esas columnas (de otra migración o vista) o hay que ajustar el código para
   calcular el total desde `pedidos_detalle` y la mesa desde `mesa_pedido`?
   Si el cobro ya funciona en su base, mándennos el esquema real.

## Pagos

2. **Validaciones de `POST /api/pagos`.** `T0004` (punto 6.1) habla de "control
   de sobrecobro", pero en `RegistrarPagoTx` el único rechazo sigue siendo el
   pedido anulado, y en el servicio el monto igual a 0. No se comprueba que el
   monto no supere el saldo (se puede cobrar de más), que el pedido no esté ya
   pagado, que un reembolso (monto negativo) no supere lo pagado, ni que la
   suma de `detalles[].monto_aplicado` sea igual a `monto_abonado`. El reparto
   automático usa `precio × cantidad`, sin descuentos. En
   `GET /api/pedidos/:id/pagos` la propina se une por pedido y medio de pago,
   así que con dos pagos del mismo método puede repetirse.

3. **Flujo de devoluciones en el servidor.** Las devoluciones (reembolso, cambio
   de plato, nota de crédito y vale) viven hoy solo en memoria del frontend:
   ajustan la cuenta localmente y se pierden al recargar. En `BD-3` no hay
   tablas de notas de crédito, vales ni cambios. `T0004` propone anular la fila y emitir un pago
   negativo (la ruta que cita, `POST .../filas/:detalle_id/anular`, no existe:
   la real es `PATCH /api/v1/mozo/pedidos/:id/items/:detalle_id/anular`), pero deja notas de crédito, vales y cambio de plato para una
   "próxima entrega". Falta el contrato de: (a) la operación única "devolver
   una línea" (baja la línea y reembolsa el dinero juntos, para no dejar la
   cuenta inconsistente); (b) notas de crédito, con su número y el saldo a
   favor del cliente; (c) vales, con código y vigencia; (d) cambio de plato con
   diferencia de precio.

4. **La propina del mesero y el táper no llegan al servidor.** En la app la propina es una
   línea de ajuste de la cuenta ("Propina: mesero") que vive solo en memoria:
   no se manda al crear ni al editar el pedido (`CreatePedidoMozoRequest` no
   tiene campo de propina) y los diálogos de cobro tampoco envían el campo
   `propina` de `POST /api/pagos`, que es lo único que llena la tabla
   `propina`. Por eso se pierde al recargar y no aparece en `GET /api/propinas`.
   Pedimos definir el contrato: ¿la propina forma parte del total del pedido
   (campo al crear/editar el pedido) o se manda solo al cobrar como monto
   aparte de `monto_abonado`? Con la respuesta el frontend la conecta.
   Lo mismo pasa con el táper (grande o mediano, con precio editable): es otra
   línea de ajuste en memoria. El backend tiene la tabla `taper` y las líneas
   con `taper_id`, pero la app no las usa; hace falta saber si el precio sale
   del catálogo `taper` o se manda como una línea libre, y si un pedido puede
   ser solo un táper (sin productos de la carta).

## Caja

5. **Ingresos y salidas de caja (movimientos): editar y anular, sin eliminar.**
   Ya existen `/api/categorias-movimiento` y `/api/movimientos` (tipo `I`/`E` y
   medio de pago). Así queremos dejar la vista de Caja, y esto es lo que
   necesita el backend para sostenerla:

   *Vista (frontend).* Una sola pantalla simple:
   1. Resumen del turno, una fila por medio de pago: ventas, ingresos, salidas
      y neto. El efectivo esperado en caja es: monto inicial + ventas en
      efectivo + ingresos en efectivo − salidas en efectivo.
   2. Botones **+ Ingreso** y **+ Salida**. El formulario tiene solo: categoría,
      monto, medio de pago (efectivo por defecto) y una nota opcional.
   3. Lista de movimientos del turno (hora, tipo, categoría, nota, medio, monto,
      quién lo registró) con **Editar** y **Anular**. Un movimiento anulado
      sigue en la lista, tachado y con su motivo, y no cuenta en los totales.
   4. Cerrar caja, igual que hoy pero con esos totales.

   *Lo que falta en el backend:*
   - **Anular y editar, nunca eliminar.** `POST /api/movimientos/:id/anular`
     con `motivo` (obligatorio) y `PUT /api/movimientos/:id` (categoría, monto,
     medio de pago, nota). La fila se conserva con `estado` (`activo` o
     `anulado`), quién y cuándo la anuló, el motivo, y quién y cuándo la editó.
     No debe haber `DELETE`. Un movimiento de una caja ya cerrada no se edita
     ni se anula. Pedimos que nos digan qué rol puede editar y anular (¿solo
     administrador o también cajero?).
   - **Datos del movimiento.** `movimiento` no guarda quién lo registró
     (`usuario_id`) ni una nota. `GET /api/movimientos` debería devolver
     `usuario_nombre`, `nota`, `estado` y `motivo_anulacion`, y aceptar los
     filtros `tipo`, `medio_pago_id` e `incluir_anulados`.
   - **Totales y cierre.** `GET /caja/totales-actual` y `POST /caja/cierre`
     solo suman pagos: no restan egresos ni suman ingresos extra, y
     `cierre_caja` no tiene dónde guardarlos, así que el arqueo no cuadra.
     Además `cierre_caja` tiene columnas fijas (efectivo, tarjeta, Yape, Plin):
     un medio de pago nuevo cae en tarjeta (`GetTotalesCajaActual`, ~línea
     912). Pedimos totales por medio de pago (ventas, ingresos, salidas) que
     excluyan los movimientos anulados.
   - **Apertura de caja.** No existe: el monto inicial solo se guarda al
     cerrar.

## Tickets

6. **El ticket de cuenta no incluye el recargo por tarjeta.** En
   `internal/services/printer_service.go` no aparece ningún manejo de recargo o
   comisión (`FormatPrecuenta` y `BuildPrecuentaPayloadFromDB`). La boleta que
   muestra el frontend sí trae "TOTAL CUENTA", "RECARGO POR PAGO CON TARJETA" y
   "TOTAL A PAGAR". Cuando el pedido ya tiene pagos, el ticket impreso debería
   mostrar el mismo recargo (`monto_comision` de los pagos) para que coincida
   con lo que se cobró.

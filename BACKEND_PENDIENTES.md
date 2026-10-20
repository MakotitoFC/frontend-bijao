# Pendientes del backend

Solo lo que sigue sin resolver, revisado contra el código del backend (commit
`21fea2f`). Lo que ya está corregido se quitó de esta lista.

## Fotos

1. **PWA: devolver siempre la ruta relativa de la foto.** Si en la nube se define
   `R2_PUBLIC_URL`, `StorageService.Upload` devuelve la dirección completa del
   bucket y el frontend la usa tal cual: la PWA pediría la foto directo a R2 y
   el navegador la bloquearía por CORS (Flutter web descarga la imagen con una
   petición, no con `<img>`). La guía `T0003` pide usar siempre
   `/uploads/carta/...`, que el servidor sí sirve con CORS. Pedimos que
   `url`/`url_imagen` sea siempre la ruta relativa `/uploads/...` (y que el
   servidor la entregue desde R2 si hace falta), o que se configure CORS en el
   bucket. Confirmarlo probando la PWA contra la nube.

## Eventos en vivo (SSE)

2. **`CARTA_ACTUALIZADA` en la sincronización solo si hubo cambios.** Ya se emite
   al crear, editar o eliminar un plato o una variante en local. Pero en
   `sync_service.go` (~línea 109) se sigue emitiendo **cada minuto** después de
   cualquier descarga exitosa de catálogos, haya cambiado algo o no, y el
   frontend recarga la carta cada vez. Pedimos emitirlo solo cuando la descarga
   trajo diferencias.

3. **El evento de cobro llega a todas las sedes.** `caja_service.go` (~línea 116)
   usa `hub.Broadcast("PEDIDO_ESTADO_CAMBIADO", ...)`, mientras que el de pedidos
   del mozo usa `BroadcastToSede`. Con varias sedes, el evento de un cobro
   llegaría a las pantallas de las otras. Pedimos `BroadcastToSede`.

## Tickets (impresión)

4. **Imprimir la boleta o cuenta de caja.** `T0003` dice que existe
   `POST /api/v1/impresion/pedidos/:id/reimprimir?tipo=cuenta` e
   `imprimir-raw`, pero en el código no están: `ReimprimirPedido` no lee el
   parámetro `tipo` y no hay ninguna ruta `imprimir-raw`. Hace falta un
   endpoint que imprima la cuenta o la boleta (existe `FormatPrecuenta`, sin
   ruta). El frontend ya muestra la boleta como ticket (48 columnas, con logo,
   sede, número, resumen del pago con recargo, "SON", QR y pie) pero no puede
   imprimirla.

5. **Número de orden diario en el detalle del pedido.** `codigo_orden` existe en
   los datos de impresión (`internal/dto/impresion.go`), pero no en el detalle
   del pedido (`GET /api/v1/mozo/pedidos/:id`), que es lo que lee el frontend.
   Pedimos incluirlo para mostrar en pantalla el mismo número de la comanda.

6. **Logo de los tickets.** `GET /api/v1/impresion/config` devuelve solo la ruta
   (`logo_path`) y no entrega la imagen; el frontend guarda una copia local para
   mostrarlo. `T0003` dice que la ruta es accesible (`/uploads/logos/logo.png`):
   confirmar que el servidor la sirve, para que el frontend la muestre sin
   copia local.

## Pagos

7. **El nombre del pagador no se guarda.** `CreatePagoRequest` acepta `pagador`
   (pago compartido), pero ni la tabla `pago` ni `PagoExtendidoResponse` lo
   guardan o devuelven: tras recargar se pierde quién pagó cada parte. `T0003`
   dice que se asocia al detalle o a las notas del pedido; no lo encuentro en
   `RegistrarPagoTx`. Pedimos guardarlo (migración nueva) y devolverlo.

8. **Validaciones de `POST /api/pagos`.** En el servicio solo se rechaza
   `monto_abonado` igual a 0 y, en el repositorio, el pedido anulado. No se
   comprueba que el monto no supere el saldo (se puede cobrar de más), que el
   pedido no esté ya pagado, que un reembolso (monto negativo) no supere lo
   pagado, ni que la suma de `detalles[].monto_aplicado` sea igual a
   `monto_abonado`. El reparto automático usa `precio × cantidad`, sin
   descuentos. En `GET /api/pedidos/:id/pagos` la propina se une por pedido y
   medio de pago, así que con dos pagos del mismo método puede repetirse.

9. **Flujo de devoluciones en el servidor.** Las devoluciones (reembolso, cambio
   de plato, nota de crédito y vale) viven hoy solo en memoria del frontend:
   ajustan la cuenta localmente y se pierden al recargar. `POST /api/pagos`
   acepta montos negativos (el reembolso de dinero), pero eso por sí solo no baja
   el total del pedido en el servidor, así que la cuenta quedaría inconsistente
   (dinero devuelto y saldo pendiente). Falta un flujo completo en el servidor:
   (a) ajuste de una línea del pedido por devolución (o usar la anulación parcial
   de fila, que ya baja el total y repone stock, junto con el reembolso del
   dinero en una sola operación); (b) notas de crédito, con su número y el saldo
   a favor del cliente; (c) vales, con código y vigencia; (d) cambio de plato con
   diferencia de precio. El frontend lo conectará cuando el contrato esté
   definido.
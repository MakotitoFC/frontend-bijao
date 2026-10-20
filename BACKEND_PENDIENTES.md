# Pendientes del backend

Solo lo que sigue sin resolver, revisado contra el código del backend (commit
`a7e6c2e`). Lo que ya está corregido se quitó de esta lista.

## Fotos y sincronización

1. **Ruta de foto del plato: roles y documentación.**
   `POST /api/v1/carta/:id/foto` (y `/api/carta/:id/foto`) admite los roles
   `ADMINISTRADOR`, `CAJERO`, `MOZO`, `COCINERO` y `SUPERVISOR` (`main.go`, ~líneas
   445 y 446): cualquiera puede cambiar la foto de un plato. Confirmar si es lo
   deseado; el frontend solo muestra el botón al administrador. Además la guía
   `T0001-Flujo-Robusto-Subida-Imagenes-y-Refresco-Carta.md` dice que la
   respuesta es "el estado del plato actualizado", pero devuelve los datos de la
   subida (`url`, `storage`, `warning`, `plato_actualizado`).

2. **CORS del bucket para la PWA.** Cuando la PWA muestre fotos desde R2 (otro
   dominio), el bucket necesita una política CORS que permita el dominio de la
   PWA: Flutter web descarga la imagen con una petición, no con una etiqueta
   `<img>`. No se puede ver en el código: confirmarlo probando la PWA contra R2.

3. **Sincronización nube → local: tamaños y fotos huérfanas.** Los tamaños
   (`carta_variante`) no tienen `sede_id` propio: dependen del plato. Al filtrar
   la bajada por sede, confirmar que los tamaños de un plato de esa sede bajan
   con él. Además quedaron fotos en el bucket que ningún plato usa (la subida
   anterior, en dos pasos, fallaba a veces): conviene un proceso para detectar y
   borrar las que no estén en `carta.url_imagen`.

## Eventos en vivo (SSE)

4. **`CARTA_ACTUALIZADA`: emitirlo al editar en local y solo si hubo cambios.**
   El frontend ya escucha el evento y recarga la carta al recibirlo. Hoy el
   backend lo emite únicamente en `sync_service.go` (~línea 109), al traer
   catálogos de la nube, y **cada minuto aunque no haya cambios**. No se emite
   cuando se crea, edita o inhabilita un plato en el servidor local
   (`POST`/`PUT /api/carta`, `estado`), así que ese cambio no llega a los otros
   equipos hasta que abren la carta o pulsan "Actualizar carta". Pedimos: (a)
   emitirlo en esos cambios locales y (b) emitirlo en la sincronización solo
   cuando algo cambió. Además, que `GET /api/carta` no devuelva los
   inhabilitados a quien no sea administrador.

5. **Cobrar no emite ningún evento.** `POST /api/pagos` pasa el pedido a
   `pagado`, pero no emite un evento SSE (por ejemplo `PEDIDO_ESTADO_CAMBIADO`):
   las otras pantallas no se enteran hasta consultar.

## Tickets (impresión)

6. **Imprimir la boleta de caja.** La comanda de cocina sí se imprime
   (`/api/v1/impresion/pedidos/:id/reimprimir`), pero no hay endpoint para
   imprimir la cuenta o la boleta (existe `FormatPrecuenta` en el servidor, sin
   ruta). El frontend ya muestra la boleta como ticket (48 columnas, blanco y
   negro, con logo, sede, número, resumen del pago con recargo, "SON", QR y pie)
   pero no puede imprimirla. Hace falta un endpoint que reciba o arme esos datos.

7. **Número de orden diario.** `ORDEN #0001` solo está en `print_jobs` y en
   `/impresion/cola`: pedimos que el detalle del pedido
   (`GET /api/v1/mozo/pedidos/:id`) incluya `orden` o `codigo_orden` para
   mostrar en pantalla el mismo número que sale en la comanda.

8. **Logo de los tickets.** `GET /api/v1/impresion/config` devuelve solo la ruta
   del logo y no entrega la imagen; el frontend guarda una copia local para
   mostrarlo. Si se puede, servir el logo (por ejemplo
   `GET /api/v1/impresion/config/logo`).

## Carta

9. **Una sola subcategoría por plato.** La carta guarda una única
   `subcategoria_id`. Si el formulario permite elegir varias subcategorías, solo
   se guarda la primera y las demás desaparecen al recargar. Confirmar si es lo
   deseado.

## Pagos

10. **`GET /api/caja/totales-actual` suma sin el recargo.** En
    `caja_repository.go` (~líneas 824 a 877) los totales por método (efectivo,
    tarjeta, yape, plin, delivery) suman `monto_abonado`, no `monto_cobrado`. Con
    tarjeta, el POS cobró 104 pero el total de tarjeta sale 100, y el arqueo
    (`POST /api/caja/cierre`) marcaría una diferencia de 4 por cada cobro.
    Pedimos sumar `monto_cobrado` por método (y decidir si el total de delivery
    también) y mostrar los recargos como un dato aparte.

11. **Lista de pagos para las pantallas Pagos y Caja.** Solo existe
    `GET /api/pedidos/:id/pagos` (por pedido). Tras recargar la página, las
    pantallas Pagos y Caja del frontend quedan vacías porque no hay cómo traer
    los pagos de un día. Pedimos
    `GET /api/pagos?desde=&hasta=&usuario_id=&medio_pago_id=` (filtrado por la
    sede del usuario) con el mismo `PagoExtendidoResponse`, incluidos
    `monto_comision` y `monto_cobrado`.

12. **Reembolso de pagos.** Existe `POST /api/propinas/:id/reembolso`, pero no
    hay forma de devolver dinero de un pago (devoluciones y anulaciones). El
    frontend hoy registra el reembolso solo en memoria. Pedimos un endpoint
    (por ejemplo `POST /api/pagos/:id/reembolso` con monto y motivo) que genere
    el movimiento negativo y defina si se devuelve también el recargo
    (proporcional al monto devuelto), reflejado en caja.

13. **El nombre del pagador no se guarda.** `CreatePagoRequest` acepta `pagador`
    (pago compartido), pero la tabla `pago` no tiene esa columna y
    `PagoExtendidoResponse` no lo devuelve: tras recargar se pierde quién pagó
    cada parte. Pedimos agregarlo (migración nueva) y devolverlo.

14. **Validaciones de `POST /api/pagos`.** En `RegistrarPagoTx` solo se rechaza
    el pedido anulado. No se comprueba que `monto_abonado` sea positivo ni que no
    supere el saldo (se puede cobrar de más), que el pedido no esté ya pagado, ni
    que la suma de `detalles[].monto_aplicado` sea igual a `monto_abonado` (se
    confía en el cliente). El reparto automático usa `precio × cantidad`, sin
    descuentos. En `GET /api/pedidos/:id/pagos` la propina se une por pedido y
    medio de pago, así que con dos pagos del mismo método puede repetirse.

## Documentación de las guías

15. **Las guías usan nombres que no existen en el código.**
    `GUIA_TAMANOS_Y_TAPER_FRONTEND.md`: los ejemplos traen `imagen_url`,
    `tiempo_preparacion` y `categoria_comida_nombre` (los reales son
    `url_imagen` y `categoria_nombre`; `tiempo_preparacion` no existe), y el
    ejemplo de `POST /api/tapers` trae `costo` y `tamano_id`, que
    `CreateTaperRequest` no acepta (los campos reales son `nombre`, `precio`,
    `stock`, `stock_minimo`, `sede_id`, `estado`).
    `T0002-Contrato-API-Pagos-Recargo-Tarjeta-y-Eventos-SSE.md`: nombra archivos
    que no existen (`events_service.dart` / `sse_service.dart`; el real es
    `eventos_service.dart`) y dice que `CARTA_ACTUALIZADA` se emite "al editar o
    inhabilitar un plato en local", lo que no ocurre (ver punto 4). El frontend
    sigue los nombres del código.

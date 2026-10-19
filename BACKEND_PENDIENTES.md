# Pendientes del backend — posibles chequeos

Solo lo que sigue sin resolver. Ya corregido y comprobado en el código del
backend: usuarios (rol desconocido da 400, validaciones de longitud, protecciones
del `DELETE`, solo un administrador asigna ese rol), rol `COCINERO`, creación
atómica de platos con `variantes`, `precio_personal` opcional, táper (crea solo
el tipo "Desechable" y la unidad "Unidad"), caché de `/assets/*` con revalidación,
`CacheControl` al subir a R2 y Supabase, `por-liberar`, mesa ocupada en
`CreatePedidoMozo` y `PUT /api/carta/:id` conserva `url_imagen`.

## Imágenes: nube (R2) y subida

1. **`POST /api/v1/carta/:id/foto` deja el `UPDATE` sin comprobar.** En
   `handleUpload` (`upload_handler.go`, ~línea 215) el `UPDATE carta SET
   url_imagen` no mira cuántas filas cambió: si el `id` no existe responde 200
   con `plato_actualizado: true` igual (solo falla si la base devuelve error, y
   en ese caso solo se registra en el log y la respuesta omite
   `plato_actualizado`). Pedimos comprobar `RowsAffected` y responder 404 si el
   plato no existe, y un error claro si el `UPDATE` falla. El frontend ya trata
   la falta de `plato_actualizado: true` como error.

   Además la ruta `/api/v1/carta/:id/foto` admite los roles `MOZO`, `COCINERO` y
   `SUPERVISOR` (la anterior `/uploads/carta` solo `ADMINISTRADOR` y
   `CAJERO`): cualquiera de ellos puede cambiar la foto de un plato. Confirmar
   si es lo deseado; el frontend solo muestra el botón al administrador.

   La guía `T0001-Flujo-Robusto-Subida-Imagenes-y-Refresco-Carta.md` dice que la
   respuesta es "el estado del plato actualizado", pero devuelve los datos de la
   subida (`url`, `storage`, `warning`, `plato_actualizado`). Conviene corregir
   el texto. (La advertencia `warning` cuando la foto no llega a la nube ya está
   resuelta: el frontend la muestra.)

2. **CORS del bucket para la PWA.** Cuando la PWA muestre fotos desde R2 (otro
   dominio), el bucket necesita una política CORS que permita el dominio de la
   PWA: Flutter web descarga la imagen con una petición, no con una etiqueta
   `<img>`. No se puede ver en el código: confirmarlo probando la PWA contra R2.

3. **`R2_PUBLIC_URL`.** El servidor ya descarga de R2 las fotos que faltan en su
   disco, así que la ruta `/uploads/...` funciona en la nube. Aun así, definir
   `R2_PUBLIC_URL` evita que cada foto pase por el servidor.

4. **`CacheStaticMiddleware` sin usar.** `internal/middleware/cache_assets.go`
   define un middleware de caché (7 días, `immutable`) que no se usa en ninguna
   ruta. Quitarlo.

## Documentación de las guías

5. **`GUIA_TAMANOS_Y_TAPER_FRONTEND.md` usa nombres de campos que no existen.**
   En los ejemplos aparecen `imagen_url`, `tiempo_preparacion` y
   `categoria_comida_nombre`; el código real usa `url_imagen` y
   `categoria_nombre`, y `tiempo_preparacion` no existe. El ejemplo de
   `POST /api/tapers` trae `costo` y `tamano_id`, que `CreateTaperRequest` no
   acepta (los campos reales son `nombre`, `precio`, `stock`, `stock_minimo`,
   `sede_id`, `estado`). El frontend sigue los nombres del código. Conviene
   corregir la guía.

## Realtime

6. **Evento `CARTA_ACTUALIZADA` en vivo.** Hoy la carta solo se entera de los
   cambios cuando el usuario la abre (Carta o Nuevo pedido) o pulsa el botón
   "Actualizar carta"; no se recarga sola. Un plato nuevo o editado que llega de
   la nube (el backend lo trae cada minuto) o de otro equipo, o un plato que el
   administrador inhabilita (`PUT /api/carta/:id`, `estado`), no se ve hasta
   entonces. Pedimos emitir por SSE un evento `CARTA_ACTUALIZADA` cuando se
   cree o cambie un plato (local o recién sincronizado desde la nube): el
   frontend lo escucharía y recargaría la carta al instante, sin consultar cada
   cierto tiempo. Además, que `GET /api/carta` no devuelva los inhabilitados a
   quien no sea administrador.
## Tickets (impresión)

7. **Imprimir la boleta de caja.** La comanda de cocina sí se imprime
   (`/api/v1/impresion/pedidos/:id/reimprimir`), pero no hay endpoint para
   imprimir la cuenta o la boleta (existe `FormatPrecuenta` en el servidor, sin
   ruta). El frontend ya muestra la boleta como ticket (48 columnas, blanco y
   negro, con logo, sede, número, resumen del pago, "SON", QR y pie) pero no
   puede imprimirla. Hace falta un endpoint que reciba o arme esos datos.

8. **Número de orden diario.** `ORDEN #0001` solo está en `print_jobs` y en
   `/impresion/cola`: pedimos que el detalle del pedido
   (`GET /api/v1/mozo/pedidos/:id`) incluya `orden` o `codigo_orden` para
   mostrar en pantalla el mismo número que sale en la comanda.

9. **Logo de los tickets.** `GET /api/v1/impresion/config` devuelve solo la ruta
   del logo y no entrega la imagen; el frontend guarda una copia local para
   mostrarlo. Si se puede, servir el logo (por ejemplo
   `GET /api/v1/impresion/config/logo`).

## Carta

10. **`POST` y `PUT /api/carta` no devuelven la categoría.** El `RETURNING` de
    `CreateCarta` y `UpdateCarta` (`catalog_repository.go`) trae solo las
    columnas de `carta`, sin `categoria_comida_id`, `categoria_nombre` ni
    `subcategoria_nombre`; `GET /api/carta` y `GET /api/carta/:id` sí los traen
    por el JOIN. El frontend ya conserva la categoría que elige el usuario, pero
    conviene que la respuesta sea igual a la del `GET`. Además la carta guarda
    **una sola** `subcategoria_id` por plato: si el formulario permite elegir
    varias subcategorías, solo se guarda la primera.

11. **Sincronización nube → local de tamaños y fotos de platos.** Los tamaños
    (carta_variante) no tienen sede_id propio: dependen del plato. Al filtrar
    la bajada por sede, confirmar que los tamaños de un plato de esa sede bajan
    con él (y no quedan platos sin sus tamaños o tamaños de otra sede). Además
    quedaron fotos en el bucket que ningún plato usa (la subida anterior, en dos
    pasos, fallaba a veces): conviene un proceso para detectar y borrar las que
    no estén en carta.url_imagen. Con el endpoint nuevo
    POST /api/v1/carta/:id/foto ya no deberían aparecer más.

## Pagos

12. **Recargo al cliente por pagar con tarjeta (4 %).** Regla del negocio: solo
    cuando el cliente paga con tarjeta, se le suma un recargo del 4 % sobre la
    cuenta. El cliente paga **cuenta + recargo**. El porcentaje no está fijo en
    el código: se configura por método de pago en Configuración > Métodos de
    pago (interruptor "Recargo al cliente por usar este método" y su
    porcentaje), usando los campos que ya existen, `aplica_comision` y
    `porcentaje_comision`.

    **Lo que hace hoy el backend (no coincide).** `RegistrarPago`
    (`caja_repository.go`, ~líneas 444 a 459) trata ese porcentaje como una
    comisión que se **resta**: `monto_comision = monto_abonado × %` y
    `monto_cobrado = monto_abonado − monto_comision`. Para un recargo es al
    revés: `monto_cobrado = monto_abonado + recargo`.

    **Flujo en el frontend (ya implementado en pantalla).**
    1. El cajero elige el método. La app calcula
       `recargo = redondear(monto × % / 100, 2)` y muestra: Cuenta, Recargo y
       Total a cobrar (el botón dice "Pagar · S/ total").
    2. El pago se registra con `monto_abonado` = lo que se descuenta de la
       cuenta (sin recargo) y el recargo aparte. El recargo **no** reduce el
       saldo del pedido.
    3. Pago compartido: el recargo se calcula por cada método de cada pagador,
       sobre el monto que paga con ese método.
    4. Boleta y cuentas por pagador: líneas "TOTAL CUENTA", "RECARGO POR PAGO
       CON TARJETA" y "TOTAL A PAGAR"; el "SON", el QR y "PAGO CON" usan el
       total con recargo.
    5. Caja: lo que entra por tarjeta es cuenta + recargo.
    Hoy los pagos se guardan solo en memoria de la app: el frontend todavía no
    llama a `POST /api/pagos`. Lo conectaremos cuando el contrato esté definido.

    **Lo que necesita el backend.**
    - **Modelo:** separar el recargo de una comisión bancaria futura. Sugerencia:
      migración **nueva** (no editar las existentes) con `porcentaje_recargo` y
      `monto_recargo` en `pago`, y `monto_cobrado = monto_abonado +
      monto_recargo`. Si prefieren reutilizar `monto_comision`, cambiar su
      significado y documentarlo.
    - **`POST /api/pagos`:** calcular el recargo en el servidor a partir del
      método de pago (no confiar solo en el cliente). Si el frontend envía
      `monto_recargo`, validar que coincida (tolerancia de 0,01). Responder
      `porcentaje_recargo`, `monto_recargo` y `monto_cobrado`.
    - **Saldo:** `total_pagado` y `saldo_pendiente` siguen contando solo
      `monto_abonado`. Agregar `total_recargo` y `total_cobrado` en
      `GET /api/pedidos/:id/pagos` y en el resumen del pedido.
    - **Caja, arqueos y reportes:** sumar `monto_cobrado` por método (el POS de
      tarjeta cobra el total con recargo) y mostrar los recargos como una línea
      aparte.
    - **Reembolsos y anulaciones:** definir si se devuelve también el recargo
      (proporcional al monto devuelto) y reflejarlo en `monto_cobrado`.
    - **Boleta/cuenta impresa** (cuando exista el endpoint del punto 7):
      incluir el recargo como línea propia.
    - **Dudas a resolver:** cómo debe aparecer el recargo en la boleta
      electrónica (tratamiento tributario) y si aplica a otros métodos además de
      la tarjeta (el frontend lo permite por método).
# Pendientes del backend — posibles chequeos

Solo lo que sigue sin resolver. Ya corregido y comprobado en el código del
backend: usuarios (rol desconocido da 400, validaciones de longitud, protecciones
del `DELETE`, solo un administrador asigna ese rol), rol `COCINERO`, creación
atómica de platos con `variantes`, `precio_personal` opcional, táper (crea solo
el tipo "Desechable" y la unidad "Unidad"), caché de `/assets/*` con revalidación,
`CacheControl` al subir a R2 y Supabase, `por-liberar`, mesa ocupada en
`CreatePedidoMozo` y `PUT /api/carta/:id` conserva `url_imagen`.

## Imágenes: nube (R2) y subida

1. **Fallo de subida a R2 sin aviso.** En `handleUpload`
   (`upload_handler.go`, ~línea 183), si falla la subida a la nube se guarda la
   copia en el disco local y la respuesta es 200 igual (solo queda un
   `[UPLOAD-WARN]` en el log; la respuesta trae `storage: "local"`). Al
   administrador le parece que todo salió bien, pero la foto queda en un lugar
   que en la nube se puede perder. Pedimos devolver una advertencia visible o
   responder error.

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

6. **Plato inhabilitado → mozos.** El administrador inhabilita un plato con
   `PUT /api/carta/:id` (`estado`). Los mozos dejan de verlo cuando recargan la
   carta (al abrir Carta o un pedido nuevo), pero no hay un evento SSE que lo
   avise al instante. Ideal: un evento `CARTA_ACTUALIZADA`; y que
   `GET /api/carta` no devuelva los inhabilitados a quien no sea administrador.

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

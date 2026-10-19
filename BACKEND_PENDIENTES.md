# Pendientes del backend — posibles chequeos

Solo lo que sigue sin resolver. (El conflicto de rutas `/uploads` que impedía arrancar el servidor ya se corrigió en el commit 436ecc2.)

## Imágenes: nube (R2) y subida

1. **En la nube hay que definir `R2_PUBLIC_URL`.** `StorageService.Upload` sube
   el archivo a R2 y, si `R2_PUBLIC_URL` no está configurada, devuelve
   `/uploads/<carpeta>/<archivo>` (no la dirección del bucket). Esa ruta solo
   existe en el disco del servidor, que en la nube es temporal: tras un reinicio
   o un nuevo despliegue la foto desaparece aunque esté en R2. Pedimos: (a)
   configurar `R2_PUBLIC_URL` en la nube para devolver siempre la dirección
   completa, o (b) que el servidor sirva `/uploads/...` leyendo desde R2.
   El frontend acepta las dos formas: `http...` tal cual y `/uploads/...`
   anteponiendo el servidor.

2. **Fallo de subida a R2 sin aviso.** En `handleUpload`, si falla la subida a
   la nube se guarda la copia en el disco local y la respuesta es 200 igual
   (solo queda un `[UPLOAD-WARN]` en el log). Al mozo o administrador le parece
   que todo salió bien, pero la foto queda en un lugar que se puede perder.
   Pedimos al menos devolver `storage: "local"` con una advertencia visible
   (ya se devuelve `storage`; el frontend puede mostrarla) o responder error.

3. **Confirmar `PUT /api/carta/:id`.** Debe conservar `url_imagen` cuando no
   viene en el cuerpo (el frontend la envía siempre que la conoce).

## Realtime y pedidos

4. **Plato inhabilitado → mozos.** El administrador inhabilita un plato con
   `PUT /api/carta/:id` (`estado`). Los mozos dejan de verlo cuando recargan la
   carta (al abrir Carta o un pedido nuevo), pero no hay un evento SSE que lo
   avise al instante. Ideal: un evento `CARTA_ACTUALIZADA`; y que
   `GET /api/carta` no devuelva los inhabilitados a quien no sea administrador.

5. **`por-liberar` puede listar una mesa que ya está en uso.** La consulta de
   `GetMesasPorLiberar` (`pedido_mozo_repository.go`) devuelve la mesa si el
   mozo tiene un pedido `pagado` con `mesa_pedido.hora_fin IS NULL` y la mesa
   está `ocupada`, sin mirar si la mesa tiene hoy otro pedido abierto
   (`pendiente` o `servido`, de otro mozo). Además `CreatePedidoMozo` ocupa la
   mesa sin comprobar que esté libre, así que dos pedidos pueden quedar abiertos
   en la misma mesa. Pedimos: (a) que `CreatePedidoMozo` rechace una mesa
   ocupada y (b) que `por-liberar` excluya las mesas con otro pedido abierto
   (`NOT EXISTS` sobre `mesa_pedido`/`pedidos` en `pendiente` o `servido`).
   El frontend ya se protege de lo que puede (filas de otro mozo, listas de un
   usuario anterior, mesas con un pedido abierto que la app conoce), pero no
   puede ver los pedidos de otros mozos.

## Tickets (impresión)

6. **Imprimir la boleta de caja.** La comanda de cocina sí se imprime
   (`/api/v1/impresion/pedidos/:id/reimprimir`), pero no hay endpoint para
   imprimir la cuenta o la boleta (existe `FormatPrecuenta` en el servidor, sin
   ruta). El frontend ya muestra la boleta como ticket (48 columnas, blanco y
   negro, con logo, sede, número, resumen del pago, "SON", QR y pie) pero no
   puede imprimirla. Hace falta un endpoint que reciba o arme esos datos.

7. **Número de orden diario.** `ORDEN #0001` solo está en `print_jobs` y en
   `/impresion/cola`: pedimos que el detalle del pedido
   (`GET /api/v1/mozo/pedidos/:id`) incluya `orden` o `codigo_orden` para
   mostrar en pantalla el mismo número que sale en la comanda.

8. **Logo de los tickets.** `GET /api/v1/impresion/config` devuelve solo la ruta
   del logo y no entrega la imagen; el frontend guarda una copia local para
   mostrarlo. Si se puede, servir el logo (por ejemplo
   `GET /api/v1/impresion/config/logo`).

## Carta

9. **POST y PUT /api/carta no devuelven la categoría.** El RETURNING de
   CreateCarta y UpdateCarta (catalog_repository.go, ~líneas 958 y 1029)
   trae solo las columnas de carta, sin categoria_comida_id,
   categoria_nombre ni subcategoria_nombre; GET /api/carta y
   GET /api/carta/:id sí los traen por el JOIN. El frontend ya conserva la
   categoría que elige el usuario, pero conviene que la respuesta sea igual a
   la del GET. Además la carta guarda **una sola** subcategoria_id por
   plato: si el formulario permite elegir varias subcategorías, solo se
   guarda la primera (al recargar desde el servidor las demás desaparecen).
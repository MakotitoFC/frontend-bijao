posibles chequeos

1. **Foto del plato.** El frontend ya sube la foto del plato (ícono de cámara
   en la carta, solo administrador) y guarda la dirección en `carta.url_imagen`.
   Como no existe una subida propia para la carta, usa
   `POST /api/v1/uploads/evidencias`: sirve, pero las fotos de platos quedan
   mezcladas con las evidencias de anulaciones y mermas. Conviene un
   `POST /api/v1/uploads/carta` (o una carpeta aparte) con el mismo contrato.
   También confirmar que `PUT /api/carta/:id` conserva `url_imagen` cuando no
   viene en el cuerpo (el frontend la envía siempre que la conoce).

2. **Plato inhabilitado → mozos.** El administrador inhabilita un plato con
   `PUT /api/carta/:id` (`estado`). Los mozos dejan de verlo cuando recargan la
   carta (al abrir Carta o un pedido nuevo), pero no hay un evento SSE que lo
   avise al instante. Ideal: un evento `CARTA_ACTUALIZADA`; y que
   `GET /api/carta` no devuelva los inhabilitados a quien no sea administrador.

3. **`por-liberar` puede listar una mesa que ya está en uso.** La consulta de
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

4. **Tickets (impresión).**
   (a) La comanda de cocina sí se imprime
   (`/api/v1/impresion/pedidos/:id/reimprimir`), pero **no hay endpoint para
   imprimir la cuenta o la boleta de caja** (existe `FormatPrecuenta` en el
   servidor, sin ruta). El frontend ya muestra la boleta como ticket (48
   columnas, blanco y negro, con logo, sede, número, resumen del pago, "SON",
   QR y pie) pero no puede imprimirla. Para que salga igual en papel hace falta
   un endpoint que reciba o arme esos datos.
   (b) El número de orden diario (`ORDEN #0001`) solo está en `print_jobs` y en
   `/impresion/cola`: pedimos que el detalle del pedido
   (`GET /api/v1/mozo/pedidos/:id`) incluya `orden` o `codigo_orden` para
   mostrar en pantalla el mismo número que sale en la comanda.
   (c) `GET /api/v1/impresion/config` devuelve solo la ruta del logo y no
   entrega la imagen; el frontend guarda una copia local para mostrarlo. Si se
   puede, servir el logo (por ejemplo `GET /api/v1/impresion/config/logo`).

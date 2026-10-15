# Pendientes para el backend

Documento para el desarrollador del backend. Resume lo que el frontend usa hoy,
lo que encontramos al conectar los endpoints de pedidos del mozo y lo que sigue
abierto. Se actualizó después de las respuestas del backend (`RESPUESTA_BACKEND.md`)
y de aplicar las migraciones 00021–00023.

## Estado: pedidos del mozo ya conectados

El frontend usa `/api/v1/mozo/pedidos` para crear, listar y operar pedidos
(roles mesero y administrador). Ya está conectado:

- Crear pedido (mesa o delivery, táper en fila aparte, plato libre).
- Lista liviana con sincronización cada 4 s (solo pide el detalle de lo que
  cambió: compara `version`, `updated_at` y `total`).
- Cantidad, nota de fila, nota del pedido, servido (fila), estado
  pendiente/servido, agregar producto.
- Anular fila (total o parcial) y anular pedido, con motivo y foto
  (`/api/v1/uploads/evidencias`).
- Descuentos (aplicar y quitar) y autorización por PIN
  (`/api/auth/validar-pin-supervisor`) cuando el usuario no puede otorgarlos.
- Cambiar mesa, cambiar tipo de entrega del pedido y de una fila.
- Reimprimir comanda y liberar mesa.
- Conflictos 409 sin `codigo`: el frontend recarga el pedido y avisa que
  cambió; con `codigo` (stock) muestra el mensaje y actualiza la disponibilidad.

El administrador conserva la lista general del servicio anterior
(`GET /api/pedidos`) y sobre ella carga con la API nueva los pedidos propios.
Solo se puede operar un pedido propio.

---

## Resuelto por el backend (`BACKEND_RESPUESTA.md`)

Ya implementado y comprobado en el frontend:

- **Táper:** la fila de solo táper entra (migración `00024`).
- **Delivery:** INSERT corregido; `referencia` vacía se guarda como `""`.
- **Detalle y lista:** traen `tipo_entrega` (mesa, llevar, delivery),
  `nombre_cliente` y el objeto `delivery`. El frontend ya los lee y los envía al
  crear el pedido; también hay pedidos "Para llevar".
- **Pedido de empleado:** `tipo: "empleado"` y descuento posterior.
- **Estados:** solo `pendiente`, `servido`, `pagado`, `anulado` y `devuelto`.
  El frontend quitó "preparando", "listo", "en camino", "entregado" y
  "en cuenta".
- **PIN:** guardado con bcrypt, `debe_cambiar_pin` en el login y PIN de 4 a 10
  dígitos. El frontend pide el cambio al entrar (administrador o quien puede
  otorgar descuentos).
- **Liberar mesa:** manual, por el mozo o el administrador. El frontend muestra
  "Mesas por liberar" en Pedidos (las mesas de pedidos ya cobrados).
- **Promociones:** el frontend ya lista, crea, edita y borra promociones,
  componentes y opciones contra el backend, y las vende en pedidos.
- **Tiempo real (SSE):** el frontend ya se conecta a `/api/v1/eventos` (cabecera
  `Authorization` en escritorio y móvil; `?token=` en el navegador), reconecta
  solo y, al recibir un evento, vuelve a leer lo que cambió. La consulta
  periódica queda como respaldo (cada 32 s en vez de cada 4 s).

## 1. Pendientes con el backend

1. **Cocina.** Con solo 5 estados y rutas de pedidos solo para MOZO y
   ADMINISTRADOR, el rol cocinero no tiene cómo ver pedidos ni marcar nada. Hoy
   la pantalla de Cocina es solo de consulta (usa la lista general). ¿Habrá un
   endpoint de lectura para cocina?
2. **`devuelto`.** ¿Quién lo marca y con qué endpoint (caja)?
3. **Mesas por liberar.** La lista del mozo no incluye pedidos pagados, así que
   el frontend deduce las mesas por liberar al ver que un pedido desaparece de
   su lista (y lo recuerda en el dispositivo). Sería más fiable un dato del
   backend: por ejemplo `GET /api/v1/mozo/mesas?por_liberar=true`, con las mesas
   ocupadas cuyos pedidos están todos pagados.
4. **El cobro antiguo libera la mesa.** `PUT /api/pedidos/:id/estado` (el que
   usa hoy el botón "Pagar" de la app) pone la mesa en `disponible` cuando el
   pedido pasa a `pagado`, `anulado` o `devuelto`. Eso contradice la regla
   oficial de que la mesa la libera el mozo con `POST /liberar` después del
   pago. Mientras no exista el flujo de caja del backend, así se cobra en la
   app, y por eso hoy no se puede probar de punta a punta que la mesa quede
   ocupada tras el pago. Pedimos que el cobro (nuevo o antiguo) no toque la
   mesa.
5. **Eventos en vivo que faltan.** Los nombres reales son `PEDIDO_NUEVO`,
   `PRODUCTO_AGREGADO`, `PEDIDO_ACTUALIZADO`, `ITEM_SERVIDO`,
   `PEDIDO_ESTADO_CAMBIADO`, `PEDIDO_ANULADO`, `CAMBIO_MESA`, `MESA_LIBERADA`,
   `PLATO_AGOTADO`, `STOCK_ACTUALIZADO` y `APERTURA_DIARIA_COMPLETA` (el
   documento habla de `PEDIDO_CREADO`, que no existe). No se emite evento al
   anular una fila, cambiar un comentario, aplicar o quitar un descuento, cambiar
   el tipo de entrega, **cobrar un pedido** ni al cambiar promociones, tápers o
   la carta. Pedimos agregarlos (el cobro es el más importante: de él depende
   la franja "Mesas por liberar"). Mientras tanto esos cambios se ven con la
   consulta de respaldo.
6. **Promociones: no se pueden vaciar campos.** `PUT /api/promociones/:id`
   interpreta un campo ausente como "no cambiar", así que no hay forma de quitar
   una fecha de inicio o fin, ni el porcentaje de descuento, una vez guardados.
   Pedimos aceptar `null` explícito para vaciarlos.
7. **Promociones: orden.** El detalle (`GET /api/promociones`) no ordena
   componentes ni opciones (sin `ORDER BY` ni columna `orden`), así que pueden
   cambiar de lugar entre consultas. Pedimos ordenarlos (por `created_at` o con
   una columna `orden`). Hoy el producto incluido se reconoce por `es_fijo`.
8. **Promociones: borrar.** `DELETE /api/promociones/:id` borra primero los
   componentes y las opciones (ignorando errores) y después la promoción. Si la
   promoción ya está en pedidos, el último paso falla por llave foránea y queda
   la promoción sin componentes. Conviene hacerlo en una transacción, o
   rechazar el borrado de una promoción usada (y dejar solo "desactivar").
9. **Promociones en pedidos: cambiar un producto ya pedido.** No hay endpoint
   para cambiar la opción elegida de un componente después de crear el pedido;
   hoy se anula la línea y se agrega de nuevo.
10. **Edición del pedido ya creado.** No hay endpoint para cambiar el nombre del
   cliente, el teléfono o la dirección después de crearlo.

11. **Foto del plato.** El frontend ya sube la foto del plato (ícono de cámara
   en la carta, solo administrador) y guarda la dirección en `carta.url_imagen`.
   Como no existe una subida propia para la carta, usa
   `POST /api/v1/uploads/evidencias`: sirve, pero las fotos de platos quedan
   mezcladas con las evidencias de anulaciones y mermas. Conviene un
   `POST /api/v1/uploads/carta` (o una carpeta aparte) con el mismo contrato.
   También confirmar que `PUT /api/carta/:id` conserva `url_imagen` cuando no
   viene en el cuerpo (el frontend la envía siempre que la conoce).
12. **Plato inhabilitado → mozos.** El administrador inhabilita un plato con
   `PUT /api/carta/:id` (`estado`). Los mozos dejan de verlo cuando recargan la
   carta (al abrir Carta o un pedido nuevo), pero no hay un evento SSE que lo
   avise al instante. Ideal: un evento `CARTA_ACTUALIZADA`; y que `GET
   /api/carta` no devuelva los inhabilitados a quien no sea administrador.
13. **Unidades de medida.** `PUT /api/unidades-producto/:id` existe y ahora se
   usa (antes la pantalla solo podía crear y borrar). Sin pendiente; se anota
   por si cambia el contrato.

## 3. Caja, pagos y cocina (informativo)

El frontend no usará estos endpoints hasta que se definan. El análisis estático
de `internal/repositories/caja_repository.go` encontró consultas a columnas que
no existen en la base (lo tomamos como "aún no definido"). Cuando se retomen,
hay que contrastarlas con `BD-1.txt`.

## 4. Migraciones y modelo

1. **No editar una migración ya aplicada.** La `00017` cambió después de
   aplicarse en la base del frontend; Goose no la ejecutó de nuevo y la `00018`
   falló. Los cambios deben ir en un número nuevo.
2. **Bloque no repetible en la 17:** el `DO $$` compara con un nombre de
   restricción de más de 63 caracteres (se guarda truncado), así que la
   comprobación "ya existe" nunca coincide. Conviene acortar el nombre.
3. **Diferencias entre `BD.txt` y las migraciones** (revisar con `BD-1.txt`):
   `pedidos_detalle_componente` y `promocion_carta` sobreviven en migraciones;
   `carta.subcategoria_id` y `promocion_componente.subcategoria_id` son
   `NOT NULL` en el modelo y aceptan nulos en la base;
   `permiso_usuario.rol_id`; `utensilio_roto.is_respuesto` vs `is_repuesto`.

## 5. Estados del plato y borrado lógico (`carta`)

Estados: `disponible`, `agotado`, `inhabilitado`, `eliminado`.

Hoy `DELETE /api/carta/:id` es un borrado real y falla por llave foránea si el
plato ya se usó. Pedimos: borrado lógico (`estado = 'eliminado'`), que
`GET /api/carta` omita los eliminados salvo `?incluir_eliminados=true`, validar
los cuatro valores y migrar los antiguos (`inactivo` → `inhabilitado`,
`activo`/`libre` → `disponible`). Mientras tanto el frontend elimina con
`PUT estado='eliminado'` y oculta esos platos.

¿`carta.estado = 'agotado'` (fijo) convive con `carta_disponibilidad.agotado`
(diario)? ¿Cuál manda al vender?

## 6. Tamaños (pescado por tamaño) y otros pendientes del frontend

- Tamaños: hay catálogo `tamano` en la base. El frontend aún los registra por
  plato (Inventario > Tamaños); falta usar `/api/tamanos` y `tamano_id` en la
  variante.
- Compras: faltan endpoints para agregar o editar líneas después de crear la
  compra.
- Promociones: faltan `PUT` de componentes y opciones, y que
  `GET /api/promociones` devuelva el detalle.
- `GET /api/carta` no trae la disponibilidad de hoy; el frontend cruza
  `GET /api/carta-disponibilidad`. ¿Se hará una consulta combinada
  (`con_disponibilidad=true`)?
- Módulos sin tablas (cierre de caja, notas de crédito y vales, incidencias,
  horarios): ¿quedan fuera o faltan?

## 7. Lista de pruebas

Datos: dos mozos de la misma sede, un administrador, un mozo de otra sede, una
mesa libre, plato A con 3 porciones hoy, plato B libre, plato C agotado, un
táper con stock.

1. **Crear pedido** (A×2 y B×1): devuelve detalle, mesa ocupada, A pasa de 3 a 1
   con movimiento `venta` −2, `version` 1.
2. **Plato con táper:** dos filas, baja el stock del táper.
3. **Plato libre** con `precio_unitario_libre`; variante y presentación toman
   su precio de su tabla.
4. **Delivery:** crear con `delivery` y verificar `costo_delivery` y la fila en
   la tabla `delivery`.
5. **Plato agotado / stock insuficiente / apertura diaria sin fila:** 409 con
   `codigo` y `carta_id`; nada guardado.
6. **Carrera:** dos mozos piden la última porción; uno es rechazado.
7. **Cambiar cantidad:** sube y baja el stock; con `version` vieja, 409 sin
   `codigo`.
8. **Servido** (fila y componente) y **estado** pendiente/servido.
9. **Anular fila parcial:** divide la fila, repone stock, exige comentario.
10. **Anular pedido:** libera la mesa y repone stock (incluido el táper); con
    pagos parciales se rechaza.
11. **Descuento:** mozo sin `OTORGAR.DESCUENTO` → 403; con PIN de supervisor
    (`usuario_autorizo_id`) se aplica; quitar funciona; la cantidad recalcula.
12. **Cambiar mesa** (a una libre y a una ocupada) y **cambiar tipo de
    entrega** (pedido y fila, con `aplica_taper`).
13. **Seguridad:** un mozo no ve ni modifica pedidos de otro (404); otra sede
    tampoco; un pedido pagado no aparece en la lista.
14. **Lista:** solo pedidos propios; `updated_since` devuelve los cambiados; el
    total coincide con el del detalle.
15. En cada error, comprobar que no quedó nada guardado. Al crear un pedido debe
    haber un `outbox_events` y un `print_jobs` de comanda.

---

### Uso desde el frontend

La API nueva de pedidos está activa por defecto (`AppConfig.usarApiPedidosMozo`).
Para volver al servicio anterior:
`flutter run -d windows --dart-define=USAR_API_MOZO=false`.

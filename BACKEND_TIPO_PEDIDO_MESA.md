# Backend: el pedido de mesa pasa a "Sin mesa" después de cobrarse

## El síntoma

Se hace un pedido en una mesa y se cobra. En **Historial de ventas** el pedido
se ve como **Mesa N**. Después, al crear otro pedido en esa mesa (o al cerrar
caja, o al liberar la mesa), el mismo pedido ya cobrado pasa a verse como
**Sin mesa**.

## Por qué pasa

1. **La mesa de un pedido vive en `mesa_pedido`, no en `pedidos`.** Mientras el
   pedido ocupa la mesa, `mesa_pedido.hora_fin` está vacío. Al liberar la mesa se
   le pone `hora_fin`:
   - al crear otro pedido en la misma mesa
     (`pedido_mozo_repository.go`, auto-liberación de pedidos pagados),
   - al cerrar caja (`caja_repository.go`, "auto-liberar todas las mesas"),
   - al liberar la mesa a mano,
   - al anular el pedido.
2. **Las listas de pedidos solo miran el vínculo activo**
   (`LEFT JOIN mesa_pedido mp ON mp.pedidos_id = p.id AND mp.hora_fin IS NULL`,
   en `GetPedidos`, `GetPedidoByID` y `GetPedidoMozoDetalle`). Cuando el vínculo
   se cierra, devuelven `mesa_numero = null` y ya no pueden decir "mesa".
3. **Como último recurso devuelven la columna `pedidos.tipo`** (`ELSE p.tipo`), y
   para un pedido de salón eso es `normal`.
4. **El frontend no tiene etiqueta para `normal`.** Su regla es: delivery →
   "Delivery", llevar → "Para llevar"; cualquier otro tipo sin número de mesa →
   **"Sin mesa"**.

Además, las consultas de caja y pagos (`caja_repository.go`) buscan **cualquier**
vínculo pasado (sin `hora_fin IS NULL`) y sí siguen diciendo "mesa" con su
número. Por eso la misma venta se ve distinta según qué endpoint la leyó último.

## Qué es el tipo `normal`

`pedidos.tipo` se creó como `varchar(20) NOT NULL DEFAULT 'normal'`
(`migrations/00001_initial_schema.sql`). `normal` es solo el valor por defecto:
"pedido sin nada especial". Después se agregaron los valores especiales
`llevar`, `delivery` y `empleado`; lo que no es ninguno de esos queda `normal`.

- **`normal` no significa "mesa".** Un pedido de mesa casi siempre es `normal`,
  pero `normal` no garantiza que tenga mesa.
- Que un pedido sea de mesa se deduce de `mesa_pedido`. Al cerrarse ese vínculo,
  de `normal` ya no se puede saber si fue mesa, de salón o sin mesa.
- Al crear un pedido, el backend parte de `normal` y solo lo cambia a `llevar` o
  `delivery` si la petición lo pide (`pedido_mozo_repository.go`).
- Al pasar un pedido a mesa (`CambiarTipoEntregaPedido`) se marca `normal`; al
  pasarlo a llevar o delivery se marca `llevar` o `delivery`.

La información "este pedido fue de mesa" está en dos lugares (la columna `tipo`
y el vínculo activo) y ninguno sobrevive a la liberación de la mesa.

## Qué se pide

Regla propuesta: **un pedido que tuvo mesa sigue siendo de mesa y conserva el
último número de mesa**, mientras no sea para llevar, delivery ni de empleado.

1. En `GetPedidos` y `GetPedidoByID` (`pedido_repository.go`):
   - agregar al `CASE` del tipo, antes del `ELSE p.tipo`, una rama que devuelva
     `mesa` si el pedido tiene **algún** registro en `mesa_pedido`;
   - devolver `mesa_numero` con el número de la mesa activa o, si no hay, el de
     la última mesa del pedido (`ORDER BY hora_inicio DESC LIMIT 1`). Debe ser
     `NULL` si el pedido es `llevar`, `delivery` o `empleado`, o tiene delivery.
2. En `GetPedidoMozoDetalle` (`pedido_mozo_repository.go`):
   - el mismo cálculo para `mesa_numero`;
   - que `tipo_entrega` sea `mesa` si hay mesa activa **o** número de mesa
     conservado. Hoy, sin mesa activa, devuelve `llevar` aun para un pedido de
     mesa ya cobrado.
3. No cambiar `mesa_id`: debe seguir significando "mesa ocupada ahora". Pasar un
   pedido a llevar debe seguir funcionando (`tipo = 'llevar'` se evalúa antes y no
   conserva el número).


## Recomendaciones

- **Una sola regla para todas las consultas** que arman el tipo de pedido. Hoy
  existe en cinco o seis `CASE` casi iguales (`pedido_repository`,
  `pedido_mozo_repository`, `caja_repository`, `traspaso_repository`,
  `printer_service`, `facturacion_service`), y por eso se desalinean.
- **Opcional, más grande:** guardar `mesa` como valor explícito de `pedidos.tipo`
  (migración que convierta los `normal` con historial en `mesa`). Así el tipo no
  depende de un vínculo que se cierra.
- **Aparte, pendiente:** cambiar el tipo del pedido o de un plato no envía el
  evento `PEDIDO_ACTUALIZADO`, y la respuesta debería traer siempre
  `tipo_entrega`.

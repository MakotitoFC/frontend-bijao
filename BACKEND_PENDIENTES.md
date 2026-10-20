# Pendientes del backend

Solo lo que hay que corregir, revisado contra el código del backend (commit
`147bdb7`) y el esquema `BD_BIJAO` con la migración 31. Lo ya resuelto y las
mejoras futuras se quitaron de esta lista.

## Facturación electrónica (`T0005`)

1. **Emitir un comprobante falla.** `ObtenerItemsPedidoParaFacturacion`
   (`internal/repositories/facturacion_repository.go`, líneas 360-361) lee
   `pd.precio_unitario` y `pd.subtotal`, y `pedidos_detalle` no tiene esas
   columnas (tiene `precio_base`, `precio` y `precio_taper`). Emitir y
   reimprimir un comprobante responden "column does not exist". Hay que usar el
   mismo cálculo que ya usan caja y el mozo.

2. **El total del comprobante no es lo que paga el cliente.** El total es la
   suma de los ítems: no resta los descuentos (`descuento_aplicado`), ni suma el
   cargo de delivery, el táper (`precio_taper`) ni el recargo por tarjeta (el
   4 % que ya cobra `POST /api/pagos`). El total a facturar debe usar el mismo
   cálculo del total del pedido, y hay que definir si el recargo va dentro del
   comprobante (decisión contable).

3. **Se pueden emitir varias boletas del mismo pedido.** No se valida que ya
   exista un comprobante activo para el pedido, ni que el pedido esté pagado,
   ni que `pago_id` sea de ese pedido. Pedimos "un comprobante activo por
   pedido".

4. **Roles y sedes.** `T0005` dice que anular es solo de CAJERO, ADMIN y
   SUPERVISOR, pero el grupo de rutas incluye MOZO y `anular` no lo restringe:
   un mozo puede anular una boleta. Además `GET /comprobantes/:id`,
   `consultar-status`, `anular` e `imprimir` buscan por id sin comprobar la
   sede del usuario.

5. **El correlativo no es atómico.** `GetSiguienteCorrelativo` hace
   `MAX(numero) + 1`: dos cajas emitiendo a la vez chocan con la restricción
   única y una falla. Pedimos hacerlo atómico (por ejemplo con una secuencia o
   un bloqueo por sede y serie).

6. **Configuración de producción.** Las variables se llaman `SANDBOX_*` y los
   PDF vienen de `sandbox.apisunat.pe`. Antes de emitir comprobantes reales hay
   que confirmar el token y las URLs de producción, que las series (`B001`,
   `F001`) estén registradas en el PSE, que el RUC de la sede coincida con el
   de la cuenta, y activar la impresora de caja (`caja_habilitada` viene en
   `false`; para USB, `PRINTER_CAJA_USB_NAME`).

## Devoluciones (`T0006`)

7. **El reembolso en efectivo no valida que la línea esté cobrada.**
   `DevolverItemPedidoTx` (`caja_repository.go`, ~línea 1790), con
   `tipo_devolucion: "efectivo"`, siempre inserta un pago negativo por el monto,
   sin comprobar cuánto se pagó de esa línea ni del pedido. Se puede "devolver"
   dinero que nunca se cobró. Pedimos validar que el monto no supere lo pagado
   (igual que ya hace `POST /api/pagos` con los reembolsos).

## Caja (`T0006`)

8. **El arqueo de tarjeta y digital ignora los ingresos y salidas.**
   `RegistrarCierre` (`caja_repository.go`, líneas 1360-1361) calcula la
   diferencia de tarjeta y de digital contra las ventas (`totales.Tarjeta`,
   `Yape + Plin`), no contra el neto por medio (ventas + ingresos − salidas),
   que sí usa para el efectivo. Un ingreso o una salida registrado con tarjeta,
   Yape o Plin descuadra el cierre.

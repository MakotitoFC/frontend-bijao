# Observaciones de la marcha blanca (restaurante en físico)

**Fecha de redacción:** 24 de octubre de 2026
**Origen:** observaciones tomadas en el restaurante durante la marcha blanca, redactadas y ordenadas por prioridad para que el equipo las levante.
**Relación con otros documentos:** lo que depende del servidor ya está o se enlaza con `BACKEND_PENDIENTES.md` (se cita el ítem).

## Cómo leer este documento

| Campo | Valores |
|---|---|
| **Prioridad** | **Alta**: frena la operación, afecta dinero o comprobantes. **Media**: mejora clara del trabajo diario. **Baja**: mejora deseable o a largo plazo. |
| **Área** | **F** frontend · **B** backend · **D** datos por cargar (carta, precios) · **N** negocio (decisión de los dueños) |
| **Estado** | Nuevo · En revisión · Por definir (no se puede empezar sin una respuesta) |

Cada punto lleva **qué se observó**, **qué se espera** (criterio de aceptación) y, cuando aplica, **qué falta definir**. Lo que no se entendió del todo está al final, en *Dudas abiertas*. No se asumió nada que no se haya confirmado.

## Resumen por prioridad

- **Alta (9):** MB-01, MB-02, MB-03, MB-04, MB-05, MB-12, MB-16, MB-22, MB-27
- **Media (25):** MB-06, MB-07, MB-08, MB-09, MB-10, MB-13, MB-14, MB-15, MB-17, MB-18, MB-19, MB-20, MB-21, MB-23, MB-24, MB-25, MB-26, MB-28, MB-29, MB-30, MB-31, MB-34, MB-39, MB-40, MB-41
- **Baja (6):** MB-32, MB-33, MB-35, MB-36, MB-37, MB-38

---

## A. Caja, pagos y descuentos

### MB-01 · Los ingresos de Yape no se actualizan en las tarjetas de Caja — **Alta · F+B**
- **Observado:** las tarjetas de Caja y la tabla "Por medio de pago" aparecen en blanco o no suman los ingresos de Yape.
- **Esperado:** un cobro con Yape (u otro medio) aparece al instante en su tarjeta y en su fila de "Por medio de pago", y los totales cuadran con los pagos del turno.
- **Cómo se verifica:** pruebas con datos reales de cobros en cada medio (efectivo, tarjeta, Yape/Plin), comparando tarjetas, tabla y pagos registrados.

### MB-02 · Cuadre completo de la caja con la caja abierta — **Alta · F+B**
- **Observado:** hace falta cuadrar la caja completa sin tener que cerrarla.
- **Esperado:** con la caja abierta se ve el cuadre del turno (lo esperado contra lo contado) y el detalle por medio de pago.
- **Decidido:** lo "contado" es **el conteo del efectivo que hace el cajero**.

### MB-03 · Caja por turno: dos cajas/cierres al día — **Alta · F+B**
- **Observado:** el restaurante trabaja con dos turnos: **mañana-tarde** y **tarde-noche**.
- **Esperado:** cada turno abre y cierra su propia caja, con su apertura, cuadre, cierre y reporte. La vista de Caja identifica a qué turno pertenece cada cierre.
- **Relación:** distinto de los turnos de los mozos (`BACKEND_PENDIENTES.md`, ítem 11). Se vincula con las series por caja (MB-18).

### MB-04 · Las fechas deben seguir al pago, no al pedido — **Alta · F+B**
- **Observado:** las fechas y el orden de los listados y reportes no cuadran.
- **Esperado:** los reportes, la caja y los listados de ventas se ordenan y filtran por la **fecha del pago**. Un pedido hecho un día y cobrado otro cuenta en el día del cobro.

### MB-05 · Regla de descuentos por rol — **Alta · F+B**
- **Observado:** hoy solo el mozo que atiende la mesa puede modificar descuentos, y no el administrador.
- **Decisión (24-oct-2026):** **administrador y cajero siempre pueden; el mozo nunca.** Aplica en mesa, para llevar y delivery.
- **Esperado:** el backend aplica la regla por rol (no por dueño del pedido) y la app oculta o desactiva el descuento para el mozo.

### MB-06 · Descuento extra: verificar que se guarda y que sale en el ticket — **Media · F+B**
- **Revisado en el código:** el descuento extra **sí se guarda en el servidor** (tabla `descuento_aplicado`, por pedido o por línea) y la facturación lo resta del total. No se queda solo en la app.
- **Falta:** confirmar que aparece en el ticket de venta y en el comprobante; si no, agregarlo.

### MB-07 · El descuento de empleado se reemplaza por el precio de empleado — **Media · F+B**
- **Observado:** la opción "descuento de empleado" de Configuración (habilitado y porcentaje) no corresponde, porque el beneficio al personal no es un porcentaje fijo.
- **Esperado:** se **elimina** de Configuración y no queda ningún descuento de empleado. En su lugar se usa el **precio de empleado por plato** (ver MB-39).
- **No cambia:** el descuento extra normal (MB-05 y MB-06) sigue existiendo para los roles autorizados.

### MB-08 · Cuenta cero para consumo de los dueños y sus hijos — **Media · F+B**
- **Esperado:** un pedido de consumo de los dueños y sus hijos con cuenta en S/ 0, que no genere cobro pero quede registrado.
- **Decidido:** lo **autoriza el administrador** y se reporta como **consumo interno**.

### MB-09 · Pedido rápido y delivery con repartidor propio del cliente — **Media · F+B**
- **Observado:** el cliente a veces manda su propio delivery y **paga antes por Yape** al restaurante.
- **Esperado:** un acceso directo a "Pedido rápido", sin mesa. Con delivery del cliente: **sin costo de envío y sin repartidor asignado** (ambos), y el pago queda registrado como Yape.

### MB-10 · Con cuánto paga el cliente y el vuelto — **Media · F (+B si se guarda)**
- **Esperado:** en pedidos **para llevar y delivery** se registra "con cuánto paga", se calcula el vuelto y se muestra tanto en el **mensaje de WhatsApp** como en el **mensaje del pedido**.

### MB-11 · Pedido doble — **DESCARTADO**
- **Observado:** al pedir más después de que el pedido ya se pidió, el estado debía volver a pendiente.
- **Decisión (24-oct-2026):** **no se llevará a cabo.** El pedido conserva su estado al agregar productos.

### MB-12 · Si el mozo de la mesa se fue, el administrador puede agregar productos — **Alta · B+F**
- **Observado:** si el mozo que atendía la mesa se va, otro mozo o el administrador no pueden agregar más productos.
- **Decidido:** **solo el administrador** puede agregar productos a una mesa cuyo mozo se fue. Otro mozo no.
- **Esperado:** el backend permite al administrador agregar productos a pedidos de otros mozos, y la app le muestra la opción.

### MB-13 · Mostrar el nombre del mozo en los pedidos — **Media · F**
- **Esperado:** el nombre del mozo es visible en los pedidos y en la comanda del cajero. (Para el cajero depende de `BACKEND_PENDIENTES.md`, ítem 18.)

---

## B. Comprobantes, tickets y mensajes

### MB-14 · Imprimir la cuenta antes y después de cobrar — **Media · F**
- **Observado:** no hay botón para imprimir la cuenta ("boleta en cuenta").
- **Esperado:** el **cajero y el administrador** pueden imprimir la cuenta antes y después de cobrar, todas las veces que haga falta.

### MB-15 · Medio de pago en comprobantes y ticket de venta — **Media · F+B**
- **Esperado:** el comprobante y el **ticket de venta** muestran el medio de pago utilizado.

### MB-16 · Series de boleta, factura y ticket — **Alta · F+B**
- **Esperado:** series por sede y por caja, con el formato de `BACKEND_PENDIENTES.md`, ítem 12. El backend ya tiene series por caja; falta mostrarlas en la app (columna Serie en Caja, código de sede en Configuración y serie al emitir).

### MB-17 · Ticket de venta: delivery, RUC y dirección — **Media · F+B**
- **Esperado:** el ticket de venta indica si el pedido es por **delivery** y muestra el **RUC y la dirección del negocio**, que salen de **Configuración** y no del código.
- **Reimpresión:** tanto el cliente como la caja pueden pedir ticket, boleta o factura **tantas veces como se desee**.

### MB-18 · Nombre real de las líneas en el comprobante — **Media · B+F**
- **Observado:** en el preview aparece "Consumo" para productos como el táper y otros, y no se ven bien el cliente, la dirección ni el RUC.
- **Revisado en el código:** "Consumo" es el nombre por defecto que arma el backend (`facturacion_repository.go`) cuando la línea no tiene plato.
- **Esperado:** cada línea muestra su nombre real (por ejemplo "Táper grande") y el preview muestra el cliente, la dirección y el RUC.

### MB-19 · Presentación y variante en la factura o boleta — **Media · B+F**
- **Esperado:** en bebidas y platos con variante, el comprobante muestra la presentación o variante elegida (jarra, vaso, tamaño). Verificar que salga en el preview y en el papel.

### MB-20 · Estado de pago en el mensaje de WhatsApp — **Media · F**
- **Esperado:** el mensaje de WhatsApp indica el estado del pago (pagado, pendiente o parcial).

---

## C. Carta, platos y datos por cargar

### MB-21 · Pescados por tamaño y peso, registrados por los mozos — **Media · F · Backend ya registrado**
- **Observado:** los pescados se venden por tamaño. Los mozos registran los **pesos y tamaños**, que define cocina, **cada 20 a 30 días** al ingresar el pescado. Los **precios los definen los dueños** y varían.
- **Backend (ya registrado):** existen la tabla `tamano` (peso mínimo y máximo), `carta_variante` con peso y precio propio, y `unidad_inventario` con el peso de cada pieza.
- **Falta:** revisar que la app permita a los mozos registrar los pesos y tamaños al ingreso y que cada tamaño use su precio.

### MB-22 · Carga de platos y precios — **Alta · D**
- **Falta en la carta:** **venado, sajino, lagarto y picudo**, los cuatro a **S/ 45**. Hay que **crearlos**.
- **Faltan precios en:** **patarashca** y **chilcanos**. Los precios los define el negocio.
- **Paiche:** se vende en plato **por trozos**; crearlo con esa modalidad (variante o presentación).

### MB-23 · Aviso de precio faltante — **Media · F**
- **Esperado:** si un plato no tiene precio (con o sin variantes o presentaciones), al administrador le sale un aviso claro y un acceso directo para colocarlo desde ahí.

### MB-24 · Platos estrella al inicio de la carta — **Media · F+B**
- **Esperado:** el administrador marca platos como destacados y aparecen primero en la carta.

### MB-25 · Orden alfabético de la carta y buscador por palabras — **Media · F**
- **Orden alfabético (decidido):** se aplica **en toda la carta y también dentro de cada categoría**. Cuando varios platos empiezan igual, va primero el nombre más corto. Ejemplo: **JUANE**, luego **JUANE CON…**, y así sucesivamente.
- **Buscador (decidido):**
  - No distingue mayúsculas de minúsculas **ni tildes** ("limon" encuentra "limón").
  - Reconoce las palabras del plato aunque no se escriba el nombre completo, y **en cualquier orden** ("selvatico chaufa" encuentra "1/2 CHAUFA SELVATICO").
  - Los resultados siguen un orden de relevancia: buscar "tacacho" muestra primero el **tacacho simple**.
- **Con los platos estrella (MB-24):** los destacados van primero y, dentro de cada grupo, el orden es alfabético.

### MB-26 · "Motivo de cambio de precio" — **Media · Por definir**
- **Observado:** la nota original pedía eliminar el "motivo de cambio de precio" y simplificar la consulta. Se vio en pantalla, pero no se recuerda dónde.
- **Revisado en el código:** no existe un campo con ese nombre. El candidato más probable es el **descuento extra**, que pide un nombre o motivo del descuento. Los demás "motivo" son de anulación, devolución y rotura de utensilios.
- **"Más categorías":** se descartó por ser un error de la nota.
- **Por definir:** D-01 (confirmar la pantalla).

### MB-27 · Tamaños de letra de las comandas — **Alta · F+B**
- **Observado:** en las comandas de cocina el nombre del plato es **muy grande** y la descripción (notas, táper, variantes, presentaciones) es **muy pequeña**, casi no se lee. Se pidió **aumentar la descripción** y **reducir el tamaño** general.
- **Esperado:** nombre del plato más chico y descripción más grande, en **ambas comandas: la impresa y la de pantalla** (decidido).

### MB-28 · Tarjetas con imágenes más grandes — **Media · F**
- **Esperado:** aumentar el tamaño de las tarjetas con imagen (carta y registro de pedido).

### MB-29 · Controles muy pequeños en el celular — **Media · F**
- **Observado:** el ícono de **desunir mesas** es muy pequeño para tocarlo; el **buscador** también. Pasa en la carta, el registro de pedido y el buscador.
- **Esperado:** controles táctiles de tamaño cómodo para tocar y buscadores legibles.

### MB-30 · Textos largos en la APK — **Media · F**
- **Esperado:** los textos largos bajan de línea y respetan el límite de su contenedor, sin cortarse ni desbordarse.

### MB-31 · Toasts solo en procesos relevantes — **Media · F**
- **Esperado (decidido):** solo estos procesos muestran toast; **ninguna otra acción lo hace**:
  1. **Creación y desactivación de usuarios.**
  2. **Actualización y eliminación de registros** (platos, categorías, mesas, medios de pago, tápers, etc.). **La creación de registros no lleva toast.**
  3. **Alertas de confirmación** del tipo "¿estás seguro de…?".
  4. **Errores:** también se muestran como toast.
  5. **Estados del pedido** (pendiente, servido, pagado, anulado…) y los **avisos informativos** sobre ellos: se mantienen.
- Ya se quitaron los del checklist por plato. El toast de éxito al pasar el pedido a servido se mantiene (punto 5).
- **Historial de la campana:** solo guarda lo que muestra toast; las acciones sin toast no quedan en ella.
- **Pendiente de revisión técnica:** auditar todos los avisos actuales de la app y quitar los que no estén en esta lista.

### MB-41 · Los toast llevan una "x" para cerrarlos — **Media · F**
- **Observado:** un toast se queda en pantalla hasta que se cierra solo y estorba mientras se trabaja.
- **Esperado:** **todos los toast** tienen un botón **"x"** para quitarlos de inmediato, en celular y en pantalla grande. Cerrarlo a mano no borra el aviso de la campana del header.
- **Relación:** MB-31 reduce cuántos toast salen; este punto da control sobre los que sí salen.

---

## E. Configuración y administración

### MB-32 · Botón "Guardar cambios" en Configuración > Restaurante — **Baja · F**

### MB-33 · Mayor notoriedad en las barras de Ventas, Inventario y Configuración — **Baja · F**

### MB-34 · Varios números de Yape — **Media · F+B**
- **Observado:** el negocio tiene varios números de Yape.
- **Esperado:** cada medio de pago tiene una **descripción** (por ejemplo, de quién es el número) para distinguirlos al cobrar y en el cuadre.

---

### MB-39 · Precio de empleado por plato, variante y presentación — **Media · F+B · Por definir (parcial)**
- **Observado:** el precio de empleado debe figurar **no solo en el frontend, sino también en el backend**. No se maneja como descuento: lo que existe es un **precio de empleado**.
- **Alcance (decidido):** aplica al **plato, a sus variantes y a sus presentaciones** (tamaños, jarra, vaso).
- **Revisado en el backend:** ya existe el campo **`precio_personal`** en la carta, en las variantes y en las presentaciones. La app solo lo modela en el plato; faltan variantes y presentaciones, el aviso de precio faltante y el uso en el pedido de empleado.
- **Quién registra (decidido):** el pedido de **consumo de un mozo** lo registran **solo el administrador o el cajero**. El mozo no crea pedidos de empleado.
- **Esperado:**
  1. El servidor guarda el precio de empleado de cada plato, variante y presentación. El administrador lo edita en la carta.
  2. Un pedido de empleado se cobra con ese precio. El ticket, el comprobante y los reportes muestran lo realmente cobrado, sin descuento de por medio.
  3. **Si falta el precio de empleado**, al administrador **y al cajero** se les avisa en el momento ("este plato no tiene precio de empleado") con un **tooltip o modal pequeño** donde lo escribe ahí mismo. Se guarda y la pantalla se actualiza sin ir a la tarjeta de la carta. Pueden escribirlo ambos (decidido).
  4. **Selector de tipo de precio** (ver MB-40).

### MB-40 · Selector "Cliente / Empleado" que muestra los precios que corresponden — **Media · F+B**
- **Problema que resuelve:** evitar errores al mostrar el precio de cliente o el de empleado, y que nunca se mezclen en un mismo pedido.
- **Regla (decidido):** un pedido es **de cliente o de empleado, nunca de los dos**. El tipo se elige **al crear el pedido** y no cambia después; no existe un pedido mixto.
- **Esperado:**
  - Un **tag selector** (Cliente | Empleado) al crear el pedido. Al elegirlo, la pantalla **muestra** los precios de ese tipo (carta, líneas y totales). No se "activa" ni se cambia ningún precio: solo se **muestra** el que corresponde.
  - Cambia **por evento** (al tocar el tag) con los datos que ya están cargados. **Sin polling, ni refrescos periódicos, ni consultas repetidas**.
  - Solo el administrador y el cajero ven la opción Empleado. El mozo trabaja siempre con precios de cliente.
  - **También en el backend:** el pedido guarda en el servidor el **tipo de precio** (cliente o empleado) y el precio aplicado a cada línea. El servidor valida que el pedido de empleado lo cree solo el administrador o el cajero. Así ticket, comprobante y reportes saben cuál se aplicó y no dependen de la app.

## F. Transversal y mejoras a futuro

### MB-35 · Low-code para el administrador — **Baja · F+B**
El administrador debe poder cambiar sin tocar código:
- **Datos del negocio:** sede, RUC, dirección y logo del ticket.
- **Textos y formatos** de tickets y comandas (tamaños de letra, campos y orden).
- **Tarjetas y vistas**, por ejemplo qué se muestra en **Ventas > Caja**.
- **Medios de pago** y sus descripciones.

### MB-36 · Control total para los desarrolladores — **Baja · F**
- **Esperado:** **un solo archivo de configuración de marca** dentro del código (tipografía, colores, logos e íconos). Se cambia ahí y se recompila.

### MB-37 · "Show stopper": avisos que impiden continuar hasta resolver — **Baja · F+B · Por definir (parcial)**
- **Qué es:** avisos bloqueantes que no dejan seguir hasta resolver el problema. Un toast informa y desaparece; el show stopper obliga a resolver antes de seguir.
- **Ámbito (decidido):** **Caja** y **Pedido**.
- **Primer caso (decidido):** no se abrió la caja y ya están registrando pedidos.
- **Por definir (QA):** los demás casos, a qué roles bloquean y si se pueden saltar con autorización del administrador (D-07).

### MB-38 · Alertas de stock en tiempo real — **Baja · F+B**
- **Estado:** se había descartado y **se reactiva como mejora pendiente** (decisión del 24-oct-2026).
- **Esperado:** alertas de stock en la campana del header y eventos del servidor en tiempo real. Al priorizarlo, reabrir el ítem correspondiente de `BACKEND_PENDIENTES.md`.

---

## Dudas abiertas (hay que responderlas antes de empezar)

| Id | Punto | Pregunta |
|---|---|---|
| D-01 | MB-26 | ¿En qué pantalla se vio el "motivo de cambio de precio"? Se vio en pantalla pero no se recuerda dónde; el candidato es el nombre/motivo del descuento extra. Confirmar al verlo. |
| D-07 | MB-37 | Show stopper: además del caso "caja sin abrir con pedidos en curso", ¿qué otros casos hay en Caja y Pedido, a qué roles bloquean y se pueden saltar con autorización del administrador? (lo responde QA) |

## Ya cubierto en otros documentos

- Turnos de los mozos (acceso limitado por turno): `BACKEND_PENDIENTES.md`, ítem 11.
- Series por sede y caja: ítem 12. DNI en boletas: ítem 13.
- Rutas de Reportes y plato más vendido: ítem 14.
- Comprobante distinto por pagador y errores de total en pagos compartidos: ítems 15 y 17.
- Número de orden y detalle del pedido para el cajero: ítem 18.

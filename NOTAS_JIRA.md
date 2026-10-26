# Notas para Jira — Marcha blanca (24-oct-2026)

Las 41 observaciones se agruparon en **18 tickets**. Cada ticket indica qué notas originales (MB-xx) cubre.
Formato: **Tipo de actividad · Título · Descripción · Subtareas**.
Tipos: **Error** (algo falla), **Mejora** (cambio o función nueva), **Tarea** (carga de datos o revisión).
Subtareas con su área: **[Frontend]**, **[Backend]**, **[Datos]**, **[QA]**.
El detalle de cada nota original está en `NOTAS_JIRA_DETALLE.md` y `OBSERVACIONES_MARCHA_BLANCA.md`.

| Ticket | Tema | Notas | Prioridad |
|---|---|---|---|
| T-01 | Caja: ingresos de Yape y fechas por pago | MB-01, 04 | Alta |
| T-02 | Caja por turno y cuadre con caja abierta | MB-02, 03 | Alta |
| T-03 | Descuentos: regla por rol y fin del descuento de empleado | MB-05, 06, 07 | Alta |
| T-04 | Precio de empleado y selector Cliente/Empleado | MB-39, 40 | Media |
| T-05 | Pedidos especiales: cuenta cero, pedido rápido, delivery propio y vuelto | MB-08, 09, 10 | Media |
| T-06 | Pedidos: administrador agrega productos y nombre del mozo | MB-12, 13 | Alta |
| T-07 | Ticket de venta y cuenta | MB-14, 15, 17, 20 | Media |
| T-08 | Comprobantes: series, nombres reales y presentación o variante | MB-16, 18, 19 | Alta |
| T-09 | Carta: carga de datos, pescados y precio faltante | MB-21, 22, 23 | Alta |
| T-10 | Carta: orden, buscador, platos estrella e imágenes | MB-24, 25, 28 | Media |
| T-11 | Comandas: tamaños de letra | MB-27 | Alta |
| T-12 | Interfaz móvil y APK | MB-29, 30, 33 | Media |
| T-13 | Configuración: guardar y medios de pago | MB-32, 34 | Media |
| T-14 | Low-code del administrador y archivo de marca | MB-35, 36 | Baja |
| T-15 | Toast: solo relevantes y botón "x" | MB-31, 41 | Media |
| T-16 | Show stopper | MB-37 | Baja |
| T-17 | Alertas de stock en tiempo real | MB-38 | Baja |
| T-18 | Ubicar el "motivo de cambio de precio" | MB-26 | Media |
| T-19 | Mesas unidas: el pedido solo toma la primera mesa | Nueva | Alta |
| T-20 | Pago único y compartido: quitar "Ninguno" y ticket de venta por defecto | Nueva | Alta |
| T-21 | Historial de ventas: filtro de fecha por día | Nueva | Alta |
| T-22 | Pedidos e Historial: tag de pagado y medio de pago visible | Nueva | Alta |
| T-23 | Tickets: nombre del mozo, medios de pago y monto de delivery | Nueva | Alta |
| T-24 | Buscador de tamaño medio en celular, tablet y escritorio | Nueva | Alta |
| T-25 | Sidebar: Pedidos, Ventas y Caja como módulos independientes | Nueva | Alta |
| T-26 | Reimprimir cuenta y comanda desde el Historial de pedidos | Nueva | Alta |

---

## T-01
> Estado: el grupo del medio de pago ya está en el backend y el frontend lo usa (falta la fecha del pago).
**Tipo de actividad:** Error
**Título:** Caja: los ingresos de Yape no se actualizan y las fechas deben seguir la fecha del pago
**Descripción:**
Prioridad: Alta · Cubre: MB-01, MB-04
- Las tarjetas de Caja y la tabla "Por medio de pago" aparecen en blanco o no suman los ingresos de Yape.
- Causa: el backend y la app clasifican el medio **por nombre exacto** ("yape", "plin"); con varios números de Yape ("Yape Joel", "Yape local") esos cobros caen en tarjeta.
- Solución aprobada: cada medio de pago tiene un **grupo** (Efectivo, Tarjeta o Digital) que elige el administrador al crearlo, y los totales se calculan por ese grupo.
- Las fechas, la hora y el orden de listados y reportes deben tomarse de la **fecha y hora del pago**; hoy toman las del pedido.
**Subtareas:**
- [Backend] Agregar la columna `grupo` al medio de pago (`efectivo`, `tarjeta` o `digital`), obligatoria, con lectura y edición para el administrador; asignar el grupo a los medios que ya existen.
- [Backend] Calcular los totales de caja, el efectivo esperado y el cierre por el grupo del medio y no por su nombre.
- [Backend] Filtrar y ordenar el listado de pedidos y los reportes por la fecha del pago.
- [Frontend] Mostrar y editar el grupo al crear o editar un medio de pago, para el administrador y también para el cajero (ver duda D-08).
- [Frontend] Usar el grupo del medio en las tarjetas de Caja, la tabla "Por medio de pago" y el efectivo esperado.
- [Frontend] Mostrar y ordenar con la fecha y hora reales del pago (no las del pedido) en Historial de pedidos, Caja y Reportes.
- [QA] Probar cobros con varios medios Yape en cada grupo, y un pedido hecho un día y cobrado otro.

## T-02
**Tipo de actividad:** Mejora
**Título:** Caja por turno (mañana-tarde y tarde-noche) y cuadre con la caja abierta
**Descripción:**
Prioridad: Alta · Cubre: MB-02, MB-03
- El restaurante trabaja con dos turnos. Cada turno abre y cierra su propia caja, con apertura, cuadre, cierre y reporte. La vista de Caja identifica el turno de cada cierre.
- Con la caja abierta se ve el cuadre del turno (lo esperado contra lo contado) y el detalle por medio de pago. Lo "contado" es el conteo del efectivo que hace el cajero.
- Distinto de los turnos de los mozos (ítem 11 de BACKEND_PENDIENTES.md). Ligado a las series por caja (T-08).
**Subtareas:**
- [Backend] Guardar el turno de cada caja y permitir dos aperturas y cierres por día; reporte de cierre por turno.
- [Backend] Servicio de cuadre parcial sin cerrar la caja, que guarde el conteo del efectivo.
- [Frontend] Elegir o mostrar el turno al abrir y cerrar caja, y filtrar los cierres por turno.
- [Frontend] Vista de cuadre con la caja abierta (esperado, contado y diferencia) con el campo del conteo del efectivo.
- [QA] Probar dos turnos en un día y el cuadre con varios cobros, ingresos y salidas.

## T-03
**Tipo de actividad:** Mejora
**Título:** Descuentos: administrador y cajero siempre, mozo nunca; fin del descuento de empleado fijo
**Descripción:**
Prioridad: Alta · Cubre: MB-05, MB-06, MB-07
- Hoy solo el mozo que atiende la mesa puede modificar descuentos y el administrador no. Decisión: **administrador y cajero siempre pueden; el mozo nunca**, en mesa, para llevar y delivery.
- El descuento extra se guarda en el servidor (`descuento_aplicado`); falta confirmar que sale en el ticket y el comprobante.
- Se elimina de Configuración el "descuento de empleado" fijo (habilitado y porcentaje); lo reemplaza el precio de empleado (T-04).
**Subtareas:**
- [Backend] Validar el descuento por rol y no por dueño del pedido; ajustar permisos del mozo en el seed.
- [Backend] Confirmar que el ticket y el comprobante impresos muestran el descuento; retirar la configuración de descuento de empleado si existe en el servidor.
- [Frontend] Ocultar o desactivar el descuento para el mozo y habilitarlo para administrador y cajero.
- [Frontend] Mostrar el descuento en el ticket de pantalla y en WhatsApp; quitar la opción de Configuración.
- [QA] Probar descuentos con cada rol en mesa, para llevar y delivery.

## T-04
**Tipo de actividad:** Mejora
**Título:** Precio de empleado por plato, variante y presentación, y selector Cliente / Empleado
**Descripción:**
Prioridad: Media · Cubre: MB-39, MB-40
- No es un descuento: es un **precio de empleado**. El backend ya tiene el campo `precio_personal` en la carta, variantes y presentaciones; la app solo lo modela en el plato.
- Un pedido es **de cliente o de empleado, nunca de los dos**; el tipo se elige al crear el pedido y no cambia.
- Un tag selector (Cliente | Empleado) al crear el pedido **muestra** los precios que corresponden (no activa ni cambia ningún precio), por evento, con datos ya cargados y sin polling. Solo el administrador y el cajero ven la opción Empleado; el consumo de un mozo lo registran ellos.
- Si falta el precio de empleado, al administrador y al cajero se les avisa con un modal pequeño donde lo escriben ahí mismo, sin ir a la tarjeta de la carta.
- El backend guarda el tipo de precio del pedido y el precio de cada línea; ticket, comprobante y reportes muestran lo cobrado.
**Subtareas:**
- [Frontend] Modelar y editar el precio de empleado en variantes y presentaciones.
- [Frontend] Tag selector Cliente / Empleado al crear el pedido, visible solo para administrador y cajero, mostrando carta, líneas y totales con ese tipo.
- [Frontend] Aviso de precio de empleado faltante con edición rápida.
- [Backend] Guardar el tipo de precio del pedido y el precio aplicado por línea; validar que el pedido de empleado lo cree solo administrador o cajero.
- [Backend] Ruta de actualización rápida del precio de empleado con validación de permisos; cobrar y facturar con ese precio.
- [QA] Probar pedidos de cliente y de empleado, y el precio faltante.

## T-05
**Tipo de actividad:** Mejora
**Título:** Pedidos especiales: cuenta cero, pedido rápido, delivery propio del cliente y vuelto
**Descripción:**
Prioridad: Media · Cubre: MB-08, MB-09, MB-10
- **Cuenta cero:** pedido de consumo de los dueños y sus hijos con cuenta en S/ 0, sin cobro pero registrado. Lo autoriza el administrador y se reporta como **consumo interno**.
- **Pedido rápido:** acceso directo, sin mesa, para cuando el cliente manda su propio delivery y pagó antes por Yape al restaurante: sin costo de envío y sin repartidor asignado; el pago queda como Yape.
- **Vuelto:** en pedidos para llevar y delivery se registra "con cuánto paga", se calcula el vuelto y se muestra en el mensaje de WhatsApp y en el mensaje del pedido.
**Subtareas:**
- [Backend] Tipo de pedido "consumo interno" con total S/ 0 y sin cobro, autorizado por el administrador; reporte del consumo interno.
- [Backend] Permitir pedidos sin mesa, sin costo de envío y sin repartidor, con el pago de Yape registrado; guardar el monto con el que paga el cliente.
- [Frontend] Flujo de cuenta cero con autorización del administrador y etiqueta "consumo interno".
- [Frontend] Acceso directo a "Pedido rápido" y opción de delivery del cliente.
- [Frontend] Campo "paga con", cálculo del vuelto y mostrarlo en WhatsApp y en el mensaje del pedido.

## T-06
**Tipo de actividad:** Error
**Título:** Pedidos: el administrador no puede agregar productos y falta el nombre del mozo
**Descripción:**
Prioridad: Alta · Cubre: MB-12, MB-13
- **Mozo que se fue:** solo el **administrador** puede agregar productos a una mesa cuyo mozo se fue; otro mozo no.
- **Nombre del mozo:** visible en los pedidos y en la comanda del cajero.
- **Descartado:** "pedido doble" (MB-11), que el pedido volviera a pendiente al agregar productos. No se hará.
**Subtareas:**
- [Backend] Permitir al administrador agregar productos a pedidos de otros mozos; confirmar que el cajero recibe el nombre del mozo.
- [Frontend] Mostrar la opción de agregar producto al administrador y el nombre del mozo en la lista, el detalle y la comanda del cajero.
- [QA] Probar agregar productos con otro mozo y con el administrador.

## T-07
**Tipo de actividad:** Mejora
**Título:** Ticket de venta y cuenta: imprimir antes y después de cobrar, medio de pago, delivery, RUC y WhatsApp
**Descripción:**
Prioridad: Media · Cubre: MB-14, MB-15, MB-17, MB-20
- El **cajero y el administrador** pueden imprimir la cuenta antes y después de cobrar, todas las veces que haga falta.
- El ticket de venta y el comprobante muestran el **medio de pago** y si el pedido es por **delivery**.
- El ticket muestra el **RUC y la dirección del negocio**, tomados de Configuración y no del código.
- Cliente y caja pueden pedir ticket, boleta o factura **tantas veces como se desee**.
- El mensaje de WhatsApp indica el **estado del pago** (pagado, pendiente o parcial).
**Subtareas:**
- [Backend] Incluir medio de pago, tipo delivery y datos de la sede (RUC y dirección) en el ticket y comprobante impresos.
- [Backend] Reimpresión sin límite de cuenta, ticket, boleta y factura, también en pedidos pagados.
- [Frontend] Botón de imprimir cuenta antes y después de cobrar, para cajero y administrador.
- [Frontend] Mostrar esos datos en el ticket de pantalla y agregar el estado de pago al mensaje de WhatsApp.

## T-08
**Tipo de actividad:** Mejora
**Título:** Comprobantes: series por caja, nombres reales de las líneas y presentación o variante
**Descripción:**
Prioridad: Alta · Cubre: MB-16, MB-18, MB-19
- **Series:** de 4 caracteres: tipo (B o F) + código de sede (letra o número) + caja de 2 dígitos (ej. BA01, F101). El backend ya tiene series por caja y código de sede; falta mostrarlas en la app. Referencia: ítem 12 de BACKEND_PENDIENTES.md.
- **Nombres reales:** el preview muestra "Consumo" para el táper y otros porque el backend usa ese nombre cuando la línea no tiene plato. Debe mostrar el nombre real ("Táper grande") y, en el preview, cliente, dirección y RUC.
- **Presentación y variante:** en bebidas y platos con variante, el comprobante muestra jarra, vaso o tamaño, en el preview y en el papel.
**Subtareas:**
- [Backend] Validar el formato de la serie y exponer la serie por caja y sede.
- [Backend] Usar el nombre real en las líneas de táper y otras; entregar cliente, dirección y RUC; confirmar que el nombre incluye presentación o variante.
- [Frontend] Columna Serie por caja en Caja, código de sede en Configuración > Negocio y la serie que se usará al emitir.
- [Frontend] Mostrar nombre real, cliente, dirección, RUC, presentación y variante en el preview.
- [QA] Verificar el papel impreso y el preview.

## T-09
**Tipo de actividad:** Tarea
**Título:** Carta: cargar platos y precios, pescados por tamaño y aviso de precio faltante
**Descripción:**
Prioridad: Alta · Cubre: MB-21, MB-22, MB-23
- **Datos:** crear venado, sajino, lagarto y picudo (los cuatro a S/ 45); poner precio a patarashca y chilcanos (los define el negocio); crear paiche como plato que se vende por trozos.
- **Pescados:** se venden por tamaño; los mozos registran pesos y tamaños (los define cocina) cada 20 a 30 días y los precios los definen los dueños. El backend ya tiene `tamano`, `carta_variante` con peso y precio, y `unidad_inventario` con peso.
- **Aviso de precio faltante:** si un plato (con o sin variantes o presentaciones) no tiene precio, al administrador le sale un aviso con un modal pequeño para escribirlo ahí mismo.
**Subtareas:**
- [Datos] Crear venado, sajino, lagarto y picudo a S/ 45; precios de patarashca y chilcanos; paiche por trozos.
- [Frontend] Permitir a los mozos registrar pesos y tamaños y que cada tamaño use su precio.
- [Frontend] Detectar platos, variantes y presentaciones sin precio y mostrar el aviso con edición rápida.
- [Backend] Confirmar rutas y permisos para que el mozo registre pesos y tamaños.

## T-10
**Tipo de actividad:** Mejora
**Título:** Carta: orden alfabético, buscador por palabras, platos estrella e imágenes más grandes
**Descripción:**
Prioridad: Media · Cubre: MB-24, MB-25, MB-28
- **Orden alfabético** en toda la carta y dentro de cada categoría; el nombre más corto primero (JUANE antes de JUANE CON…).
- **Buscador** sin mayúsculas ni tildes, que encuentra el plato con palabras sueltas y en cualquier orden ("selvatico chaufa"); orden de relevancia ("tacacho" muestra primero el tacacho simple).
- **Platos estrella:** el administrador marca destacados y van primero; dentro de cada grupo, alfabético.
- **Tarjetas con imagen** más grandes en la carta y el registro de pedido.
**Subtareas:**
- [Frontend] Orden alfabético global y por categoría.
- [Frontend] Buscador por palabras sin mayúsculas ni tildes, con relevancia.
- [Frontend] Marcar platos como destacados, mostrarlos primero y agrandar las tarjetas con imagen.
- [Backend] Campo "destacado" en la carta.

## T-11
**Tipo de actividad:** Mejora
**Título:** Comandas: nombre del plato más chico y descripción más grande
**Descripción:**
Prioridad: Alta · Cubre: MB-27
En las comandas el nombre del plato es muy grande y la descripción (notas, táper, variantes, presentaciones) es muy pequeña y casi no se lee. Ajustarlo en **ambas comandas: la impresa y la de pantalla**.
**Subtareas:**
- [Frontend] Ajustar los tamaños en la comanda de pantalla.
- [Backend] Ajustar los tamaños en la comanda impresa.
- [QA] Verificar legibilidad en papel y en pantalla.

## T-12
**Tipo de actividad:** Error
**Título:** Interfaz móvil y APK: controles pequeños, textos largos y barras poco visibles
**Descripción:**
Prioridad: Media · Cubre: MB-29, MB-30, MB-33
- El ícono de desunir mesas y los buscadores son muy pequeños para tocarlos (carta, registro de pedido y buscador).
- En la APK, los textos largos deben bajar de línea y respetar el límite de su contenedor, sin cortarse ni desbordarse.
- Barras de subvistas (Ventas, Inventario y Configuración): pestaña activa en verde con letras oscuras; las secciones con varias opciones se abren en un desplegable en vez de poner todo en la barra.
**Subtareas:**
- [Frontend] Agrandar el ícono de desunir mesas y los buscadores a un tamaño cómodo para tocar.
- [Frontend] Corregir los textos que se cortan o desbordan en la APK.
- [Frontend] Resaltar más las barras de subvistas.
- [QA] Probar en celulares de distinto tamaño.

## T-13
**Tipo de actividad:** Mejora
**Título:** Configuración: botón "Guardar cambios" y descripción de los medios de pago
**Descripción:**
Prioridad: Media · Cubre: MB-32, MB-34
- Agregar el botón "Guardar cambios" en Configuración > Restaurante.
- El negocio tiene varios números de Yape: cada medio de pago tiene una **descripción** (por ejemplo, de quién es el número) para distinguirlos al cobrar y en el cuadre.
**Subtareas:**
- [Frontend] Botón de guardar cambios en Configuración > Restaurante.
- [Frontend] Editar y mostrar la descripción del medio de pago en Configuración, en el cobro y en el cuadre.
- [Backend] Confirmar que el medio de pago guarda y devuelve la descripción.

## T-14
**Tipo de actividad:** Mejora
**Título:** Low-code para el administrador y archivo único de marca para los desarrolladores
**Descripción:**
Prioridad: Baja · Cubre: MB-35, MB-36
- **Administrador, sin tocar código:** datos del negocio (sede, RUC, dirección, logo del ticket); textos y formatos de tickets y comandas (tamaños de letra, campos y orden); tarjetas y vistas (por ejemplo qué se muestra en Ventas > Caja); medios de pago y sus descripciones.
- **Desarrolladores:** un solo archivo de configuración de marca dentro del código (tipografía, colores, logos e íconos); se cambia ahí y se recompila.
**Subtareas:**
- [Backend] Guardar y entregar la configuración de datos del negocio y de formatos de tickets y comandas.
- [Frontend] Pantallas de Configuración para datos del negocio y formatos, y para elegir las tarjetas de Ventas > Caja.
- [Frontend] Reunir tipografía, colores, logos e íconos en un archivo de marca y hacer que toda la app lo lea.

## T-15
**Tipo de actividad:** Mejora
**Título:** Toast: solo en procesos relevantes y con botón "x" para cerrarlos
**Descripción:**
Prioridad: Media · Cubre: MB-31, MB-41
- Solo estos procesos muestran toast; ninguna otra acción lo hace: (1) creación y desactivación de usuarios, (2) actualización y eliminación de registros (la creación no lleva toast), (3) alertas de confirmación "¿estás seguro de…?", (4) errores, (5) estados del pedido y sus avisos informativos.
- El historial de la campana solo guarda lo que muestra toast.
- Todos los toast tienen un botón **"x"** para quitarlos de inmediato, en celular y en pantalla grande; cerrarlo a mano no borra el aviso de la campana.
**Subtareas:**
- [Frontend] Auditar todos los avisos actuales y quitar los que no estén en la lista.
- [Frontend] Agregar el botón "x" a todos los toast.

## T-16
**Tipo de actividad:** Mejora
**Título:** "Show stopper": avisos que impiden continuar hasta resolver
**Descripción:**
Prioridad: Baja · Por definir (parcial) · Cubre: MB-37
Avisos bloqueantes: un toast informa y desaparece; el show stopper obliga a resolver antes de seguir. Ámbito: **Caja y Pedido**.
Primer caso definido: no se abrió la caja y ya están registrando pedidos. Los demás casos, los roles a los que bloquea y si se puede saltar con autorización del administrador los define QA (D-07).
**Subtareas:**
- [QA] Listar los casos concretos de Caja y Pedido, los roles que bloquean y si hay salto con autorización.
- [Frontend] Componente de aviso bloqueante con acceso para resolver (por ejemplo, ir a abrir la caja).
- [Frontend] Caso 1: bloquear el registro de pedidos si la caja no está abierta.
- [Backend] Rechazar en el servidor los pedidos cuando no hay caja abierta, con un error claro.

## T-17
**Tipo de actividad:** Mejora
**Título:** Alertas de stock en tiempo real
**Descripción:**
Prioridad: Baja · Cubre: MB-38
Se había descartado y se reactiva como mejora pendiente (decisión del 24-oct-2026). Alertas de stock en la campana del header y eventos del servidor en tiempo real.
**Subtareas:**
- [Backend] Eventos en tiempo real cuando un producto de inventario o táper queda en o por debajo de su mínimo, y cuando se agota, solo para el administrador; mínimo configurable en los tápers.
- [Frontend] Mostrar las alertas en la campana del header.

## T-18
**Tipo de actividad:** Tarea
**Título:** Ubicar el "motivo de cambio de precio" que se pidió eliminar
**Descripción:**
Prioridad: Media · Cubre: MB-26
La nota pedía eliminar el "motivo de cambio de precio" y simplificar la consulta. Se vio en pantalla pero no se recuerda dónde; en el código no existe con ese nombre, y el candidato más probable es el nombre o motivo del **descuento extra**. "Más categorías" se descartó por ser un error de la nota.
**Subtareas:**
- [QA] Indicar en qué pantalla se vio el motivo de cambio de precio (D-01).
- [Frontend] Una vez ubicado, eliminar el campo y simplificar la consulta.

## T-19
**Tipo de actividad:** Error
**Título:** Mesas unidas: el pedido solo toma la primera mesa
**Descripción:**
Prioridad: Alta · Nueva (encontrada en la prueba)
Al unir mesas (por ejemplo T-1 y T-3) y crear el pedido, el servidor solo registra la primera. La unión existe solo en la memoria de la app: se pierde al recargar y los demás dispositivos no la ven.
Causa: la tabla `mesa_pedido` admite varias mesas por pedido, pero la creación del pedido recibe un solo `mesa_id`. Es un error de **ambos**: el backend solo guarda una mesa y el frontend solo envía una.
**Subtareas:**
- [Backend] Crear el pedido con una lista de mesas (`mesas_ids`), una fila en `mesa_pedido` por mesa, y marcar todas como ocupadas.
- [Backend] Devolver la lista de mesas del pedido en el listado y el detalle.
- [Backend] Liberar todas las mesas al cobrar o anular el pedido.
- [Frontend] Enviar todas las mesas de la unión al crear el pedido.
- [Frontend] Mostrar la unión que devuelve el servidor y dejar de depender de la lista local.
- [QA] Unir dos mesas, crear el pedido, recargar y verificar en otro dispositivo; cobrar y verificar que ambas se liberan.

## T-20
**Tipo de actividad:** Mejora
**Título:** Pago único y compartido: quitar la opción "Ninguno" del comprobante y dejar el ticket de venta por defecto
**Descripción:**
Prioridad: Alta · Segunda tanda de la marcha blanca
El selector de comprobante tiene la opción "Ninguno". Se elimina tanto en **Pago único** como en **Pago compartido** (el selector de cada pagador): siempre se emite un comprobante, con el **ticket de venta elegido por defecto** y la posibilidad de cambiar a boleta o factura.
**Subtareas:**
- [Frontend] Quitar "Ninguno" del selector de comprobante en Pago único y en Pago compartido, y dejar el ticket de venta preseleccionado.
- [QA] Probar el cobro único y el compartido (con un comprobante distinto por pagador) con ticket, boleta y factura.

## T-21
**Tipo de actividad:** Mejora
**Título:** Historial de ventas: filtro de fecha por día
**Descripción:**
Prioridad: Alta
El filtro de fechas muestra toda la semana; debe ser **por día**. Un solo día, **por defecto hoy**, con flechas para ir al día anterior o siguiente y selector para elegir cualquier fecha.
**Subtareas:**
- [Frontend] Selector de un solo día con flechas anterior y siguiente, por defecto hoy, en el Historial.
- [Frontend] Que la tabla y las tarjetas usen el día elegido (con la fecha y hora del pago, ver T-01).
- [QA] Probar cambio de día y pedidos que cruzan medianoche.

## T-22
**Tipo de actividad:** Mejora
**Título:** Pedidos e Historial: tag de pagado, medio de pago por nombre y filtro por medio de pago
**Descripción:**
Prioridad: Alta
- **Tag "Pagado":** un pedido que ya se cobró pero todavía no sale (no está servido) muestra un tag que lo indica, en la vista **Pedidos** y en el **Historial** (solo en ese caso).
- **Medio de pago con nombre:** se muestra el **nombre del medio** ("Yape Joel", no solo "Digital") en **Pedidos, Historial y Caja**. Si se pagó con varios medios, figuran **todos**.
- **Filtro por medio de pago** en **Pedidos e Historial**: elegir, por ejemplo, "Yape Joel" y ver solo los pedidos cobrados con ese medio, para saber en qué Yape se está pagando. Un pedido pagado con varios medios aparece en el filtro de cada uno. En Caja ya existe la tabla "Por medio de pago" con los totales.
**Subtareas:**
- [Frontend] Tag "Pagado" en las tarjetas de Pedidos y en el Historial para pedidos cobrados que aún no están servidos.
- [Frontend] Mostrar los nombres de todos los medios de pago de cada pedido en Pedidos, Historial y Caja.
- [Frontend] Selector "Medio de pago" para filtrar en Pedidos y en Historial.
- [Backend] Confirmar que el listado de pedidos devuelve los pagos (medio y monto) de cada pedido.
- [QA] Probar pedidos con un medio y con varios medios, y el filtro por cada Yape.

## T-23
**Tipo de actividad:** Mejora
**Título:** Tickets: nombre del mozo, medios de pago por nombre y monto de delivery variable
**Descripción:**
Prioridad: Alta · Relacionado con T-07
- Mostrar el **nombre del mozo**.
- Mostrar el **nombre de cada medio de pago** (varios Yape), con todos los usados y su monto.
- El **monto de delivery** no es fijo: lo registra **caja o administración**, al cobrar o al editar el pedido; el mozo no. Sale en el ticket.
**Subtareas:**
- [Backend] Incluir el nombre del mozo y los medios de pago (nombre y monto) en el ticket impreso.
- [Backend] Permitir a caja y administración registrar o cambiar el costo de envío de un pedido de delivery, y que el mozo no pueda; incluirlo en el ticket.
- [Frontend] Mostrar mozo, medios de pago y monto de delivery en el ticket de pantalla.
- [Frontend] Campo para registrar el costo de envío al cobrar o al editar el pedido, solo para caja y administración.
- [QA] Probar con pagos con varios medios y con delivery de monto distinto.

## T-24
**Tipo de actividad:** Mejora
**Título:** Buscador de tamaño medio en celular, tablet y escritorio
**Descripción:**
Prioridad: Alta
Los buscadores deben tener un **tamaño medio** (ni muy pequeños ni muy grandes) en los **tres dispositivos**: celular, tablet y escritorio. Propuesta: alto de 42 px y texto de 14 en todos, con el ancho adaptado a cada pantalla.
**Subtareas:**
- [Frontend] Unificar el tamaño del buscador común en los tres dispositivos y revisar las pantallas donde se usa.
- [QA] Probar en celular, tablet y escritorio.

## T-25
**Tipo de actividad:** Mejora
**Título:** Sidebar: Pedidos, Ventas y Caja como módulos independientes
**Descripción:**
Prioridad: Alta
Ventas y Caja pasan a ser **dos vistas distintas** para evitar confusión. El menú lateral muestra **Pedidos, Ventas (historial) y Caja**, cada uno como módulo propio y sin subbarra; **Reportes** queda aparte.
**Subtareas:**
- [Frontend] Separar Ventas y Caja en módulos independientes del menú lateral y quitar el grupo "Ventas" con su subbarra.
- [Frontend] Revisar el acceso por rol: cajero con Pedidos, Ventas y Caja; Reportes solo para administración.
- [QA] Probar la navegación en celular y escritorio con cada rol.

## T-26
**Tipo de actividad:** Mejora
**Título:** Reimprimir la cuenta y la comanda desde el Historial de pedidos
**Descripción:**
Prioridad: Alta
En el **Historial de pedidos**, el **administrador y el cajero** pueden reimprimir la cuenta y la comanda **cuantas veces quieran**.
**Subtareas:**
- [Frontend] Botones de reimprimir cuenta y comanda en el Historial de pedidos, para administrador y cajero.
- [Backend] Reimpresión sin límite de cuenta y comanda, también en pedidos ya pagados, con el rótulo de reimpresión.
- [QA] Probar varias reimpresiones seguidas con ambos roles.

---

# Tickets del domingo 25 de octubre (prioridad)

Los puntos 1 a 5 de esa lista ya están cubiertos por T-20 (sin "Ninguno"), T-22 (tag de pagado y filtro por medio), T-25 (módulos independientes) y T-26 (reimprimir). Los nuevos:

## T-27
**Tipo de actividad:** Mejora
**Título:** Buscador en Pedidos para buscar por mesa y por mozo
**Descripción:**
Prioridad: Alta · Estado: hecho en el frontend
En la vista Pedidos hay un buscador que filtra por **mesa**, **mozo**, número de pedido y cliente, sin distinguir mayúsculas ni tildes.
**Subtareas:**
- [Frontend] Buscador en Pedidos (hecho).
- [QA] Probar con mesa, mozo y número de pedido.

## T-28
**Tipo de actividad:** Mejora
**Título:** Delivery: monto obligatorio con alerta "NO INGRESASTE EL MONTO"; lo registran caja y administración
**Descripción:**
Prioridad: Alta · Estado: hecho en el frontend (falta el backend)
- El monto del delivery es **obligatorio**: el campo lleva "* Obligatorio" y, si falta, antes de confirmar sale la alerta "NO INGRESASTE EL MONTO". Ya no viene sugerido; se escribe en cada pedido (se acepta 0).
- Los pedidos de delivery los registran **caja y administración**; el **mozo no** (la app le oculta la opción Delivery). El cajero tiene un botón "Nuevo delivery" en sus comandas.
- Otros campos obligatorios se marcarán más adelante.
**Subtareas:**
- [Frontend] Campo obligatorio con alerta, sin monto sugerido (hecho).
- [Frontend] Ocultar Delivery al mozo y "Nuevo delivery" para el cajero (hecho).
- [Backend] Permitir al cajero crear pedidos de delivery, exigir el monto y rechazar delivery creados por un mozo (ítem 21 de BACKEND_PENDIENTES.md).
- [QA] Probar delivery sin monto, con 0 y con monto, como cajero, administrador y mozo.

## T-29
**Tipo de actividad:** Mejora
**Título:** Pedidos: filtros por tipo (Mesa, Delivery, Para llevar) en lugar de por estado
**Descripción:**
Prioridad: Alta · Estado: hecho en el frontend
Los tags de Pedidos dejan de ser por estado (Pendiente, Servido) y pasan a ser por **tipo de pedido**: Todos, Mesa, Delivery y Para llevar, cada uno con su cantidad.
**Subtareas:**
- [Frontend] Tabs por tipo (hecho).

## T-30
**Tipo de actividad:** Mejora
**Título:** Pago único con varios medios y montos distintos (misma persona)
**Descripción:**
Prioridad: Alta · Estado: hecho en el frontend
En Pago único, una persona puede dividir el pago en varios medios y montos (por ejemplo, una parte en efectivo y el resto en Yape). Un interruptor "Pagar con varios medios", filas de medio y monto, "Agregar otro medio", y el pago solo se habilita cuando lo asignado cubre la cuenta. Cada medio se registra como un pago aparte.
**Subtareas:**
- [Frontend] Pago con varios medios en Pago único (hecho).
- [QA] Probar efectivo + Yape, con recargo por tarjeta y con un fallo a la mitad.

## T-31
**Tipo de actividad:** Error
**Título:** Cambio de mesa: solo funciona con mesa libre y solo para el mozo dueño
**Descripción:**
Prioridad: Alta
Revisado: el cambio de mesa existe en la app, pero tiene dos limitaciones. (1) La pantalla ofrece traspasar el pedido a una mesa ocupada, pero el backend la **rechaza** ("la mesa destino ya tiene un pedido en curso"). (2) El botón solo aparece para el mozo dueño del pedido; el administrador no puede, y el cajero tampoco (la ruta es solo para mozo y administrador).
**Subtareas:**
- [Backend] Decidir si se permite traspasar a una mesa ocupada o solo a mesas libres.
- [Backend] Permitir al administrador cambiar la mesa de pedidos de otros mozos.
- [Frontend] Mostrar el cambio de mesa al administrador, y ajustar el texto de la pantalla según lo que el backend permita.

## T-32
**Tipo de actividad:** Mejora
**Título:** Aviso de caja cerrada al entrar y bloqueo de nuevos pedidos
**Descripción:**
Prioridad: Alta · Estado: hecho en el frontend (parcial)
Al entrar al sistema, si la caja está cerrada se muestra una alerta. **Cajero y administrador** ven "Ir a abrir", que los lleva a la vista de Caja. El **mozo** ve el aviso sin botón. Con la caja cerrada no se puede crear un pedido.
Limitación: el estado de la caja solo se puede leer con el permiso `LEER.CIERRE_CAJA`; si el rol del mozo no lo tiene, la app no sabe que está cerrada y no bloquea.
**Subtareas:**
- [Frontend] Aviso al entrar y bloqueo en "Nuevo pedido" (hecho).
- [Backend] Ruta de "caja abierta o cerrada" que puedan leer todos los roles.
- [Backend] Rechazar la creación de pedidos con la caja cerrada, con un error claro.

## T-33
**Tipo de actividad:** Mejora
**Título:** "¿Cómo pagará?": registrar el pago previsto en el pedido y mostrarlo a caja antes de cobrar
**Descripción:**
Prioridad: Alta · Estado: hecho en el frontend (falta el backend)
Un botón **"¿Cómo pagará?"** abre un modal donde mozo, caja o administración anotan cómo dice el cliente que pagará. Se puede usar **antes de confirmar el pedido** (en Nuevo pedido) y **después** (en el detalle del pedido y en la comanda de caja), en mesa, para llevar y delivery:
- Uno o varios **medios de pago** (por ejemplo, Yape Joel y efectivo).
- Si paga en **partes**, cuánto con cada medio.
- **Con cuánto paga** y el **vuelto** (se calcula solo).
- Una **nota** de pago.
Caja y administración lo ven como una **etiqueta** en la comanda del pedido y en Pedidos ("Paga con Yape Joel S/ 30 + Efectivo S/ 50 · con S/ 100, vuelto S/ 20"). Al pulsar Pagar, el cobro **viene prellenado** con esos medios y montos y caja puede cambiarlo. Es una indicación: manda lo que caja cobra.
**Subtareas:**
- [Frontend] Botón "¿Cómo pagará?" con modal en Nuevo pedido, en el detalle del pedido y en la comanda de caja; etiqueta en la comanda y en Pedidos; cobro prellenado (hecho).
- [Backend] Guardar y devolver `pago_previsto` en el pedido (ítem 22 de BACKEND_PENDIENTES.md).
- [Backend] Ruta `PATCH /:id/pago-previsto` para cambiarlo después de crear el pedido (la app ya la llama; mientras no exista, queda solo en este dispositivo).
- [QA] Probar un medio, varios medios en partes, efectivo con vuelto y la nota, y el cobro prellenado.

## T-34
**Tipo de actividad:** Mejora
**Título:** Mostrar en las tarjetas de Pedidos el mozo que atiende ese pedido o mesa
**Descripción:**
Prioridad: Alta · Estado: hecho en el frontend
Cada tarjeta de Pedidos muestra "Mozo: nombre" con el mozo asignado a esa mesa o pedido.
**Subtareas:**
- [Frontend] Mostrar el nombre del mozo en las tarjetas de Pedidos (hecho).
- [Backend] Que el listado entregue el nombre del mozo de cada pedido (el detalle ya lo trae).


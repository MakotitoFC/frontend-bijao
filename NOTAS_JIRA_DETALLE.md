# Detalle de las 41 notas de la marcha blanca (24-oct-2026)

Formato de cada nota: **Tipo de actividad · Título · Descripción · Subtareas**.
Tipos de actividad: **Error** (algo falla), **Mejora** (cambio o función nueva), **Tarea** (carga de datos o revisión).
Subtareas: cada una lleva su área entre corchetes: **[Frontend]**, **[Backend]**, **[Datos]** o **[QA]**.
El detalle completo y las dudas abiertas están en `OBSERVACIONES_MARCHA_BLANCA.md` (mismo número MB).

---

## MB-01
**Tipo de actividad:** Error
**Título:** Los ingresos de Yape no se actualizan en las tarjetas de Caja
**Descripción:**
Prioridad: Alta
Las tarjetas de Caja y la tabla "Por medio de pago" aparecen en blanco o no suman los ingresos de Yape.
Criterio de aceptación:
- Un cobro con cualquier medio (efectivo, tarjeta, Yape/Plin) aparece al instante en su tarjeta y en su fila de "Por medio de pago".
- Los totales cuadran con los pagos del turno.
**Subtareas:**
- [Frontend] Revisar cómo se agrupan y suman los medios de pago en las tarjetas y la tabla, y reproducir el caso de Yape.
- [Frontend] Actualizar tarjetas y tabla al registrar un cobro.
- [Backend] Verificar que el resumen de caja del servidor incluya los cobros de Yape y que el nombre del medio coincida con el de la app.
- [QA] Probar con cobros reales en cada medio y comparar tarjetas, tabla y pagos registrados.

## MB-02
**Tipo de actividad:** Mejora
**Título:** Cuadre completo de la caja con la caja abierta
**Descripción:**
Prioridad: Alta
Hace falta cuadrar la caja completa sin cerrarla.
Criterio de aceptación:
- Con la caja abierta se ve el cuadre del turno (lo esperado contra lo contado) y el detalle por medio de pago.
- Lo "contado" es el conteo del efectivo que hace el cajero.
**Subtareas:**
- [Frontend] Vista de cuadre con la caja abierta: esperado, contado y diferencia, con el detalle por medio de pago.
- [Frontend] Campo para que el cajero registre el conteo del efectivo.
- [Backend] Servicio que devuelva el cuadre parcial sin cerrar la caja y guarde el conteo.
- [QA] Probar el cuadre con varios cobros e ingresos y salidas.

## MB-03
**Tipo de actividad:** Mejora
**Título:** Caja por turno: dos cajas/cierres al día (mañana-tarde y tarde-noche)
**Descripción:**
Prioridad: Alta
El restaurante trabaja con dos turnos: mañana-tarde y tarde-noche.
Criterio de aceptación:
- Cada turno abre y cierra su propia caja, con apertura, cuadre, cierre y reporte.
- La vista de Caja identifica a qué turno pertenece cada cierre.
Relación: distinto de los turnos de los mozos (ítem 11 de BACKEND_PENDIENTES.md) y ligado a las series por caja (MB-16).
**Subtareas:**
- [Backend] Guardar el turno de cada caja y permitir dos aperturas y cierres por día.
- [Backend] Reporte de cierre por turno.
- [Frontend] Elegir o mostrar el turno al abrir y cerrar caja.
- [Frontend] Mostrar y filtrar los cierres por turno.

## MB-04
**Tipo de actividad:** Error
**Título:** Las fechas y el orden de listados y reportes deben seguir la fecha del pago, no la del pedido
**Descripción:**
Prioridad: Alta
Las fechas y el orden no cuadran.
Criterio de aceptación:
- Reportes, caja y listados de ventas se ordenan y filtran por la fecha del pago.
- Un pedido hecho un día y cobrado otro cuenta en el día del cobro.
**Subtareas:**
- [Backend] Que las consultas de pagos, caja y reportes filtren y ordenen por la fecha del pago.
- [Frontend] Usar la fecha del pago en Historial de pedidos, Caja y Reportes.
- [QA] Probar con un pedido hecho un día y cobrado otro.

## MB-05
**Tipo de actividad:** Mejora
**Título:** Regla de descuentos por rol: administrador y cajero siempre, mozo nunca
**Descripción:**
Prioridad: Alta
Hoy solo el mozo que atiende la mesa puede modificar descuentos y el administrador no.
Decisión: administrador y cajero siempre pueden; el mozo nunca. Aplica en mesa, para llevar y delivery.
**Subtareas:**
- [Backend] Validar el descuento por rol y no por dueño del pedido; quitar la restricción al mozo dueño.
- [Backend] Ajustar los permisos del rol mozo en el seed.
- [Frontend] Ocultar o desactivar el descuento para el mozo y habilitarlo para el administrador y el cajero.
- [QA] Probar descuentos con cada rol en mesa, para llevar y delivery.

## MB-06
**Tipo de actividad:** Tarea
**Título:** Verificar que el descuento extra sale en el ticket y el comprobante
**Descripción:**
Prioridad: Media
Revisado en el código: el descuento extra sí se guarda en el servidor (tabla descuento_aplicado, por pedido o por línea) y la facturación lo resta del total.
**Subtareas:**
- [Backend] Confirmar que el ticket y el comprobante impresos muestran el descuento.
- [Frontend] Mostrar el descuento en el ticket de pantalla y en el mensaje de WhatsApp.

## MB-07
**Tipo de actividad:** Mejora
**Título:** Eliminar el "descuento de empleado" fijo de Configuración
**Descripción:**
Prioridad: Media
La opción (habilitado y porcentaje) no corresponde, porque el beneficio al personal no es un porcentaje fijo. En su lugar se usa el precio de empleado por plato (MB-39). El descuento extra normal sigue existiendo (MB-05, MB-06).
**Subtareas:**
- [Frontend] Quitar la opción de Configuración y su lógica.
- [Backend] Verificar si el servidor guarda esa configuración y retirarla si existe.

## MB-08
**Tipo de actividad:** Mejora
**Título:** Cuenta cero para consumo de los dueños y sus hijos
**Descripción:**
Prioridad: Media
Criterio de aceptación:
- Un pedido de consumo de los dueños y sus hijos con cuenta en S/ 0, que no genere cobro pero quede registrado.
- Lo autoriza el administrador.
- Se reporta como consumo interno.
**Subtareas:**
- [Backend] Tipo de pedido "consumo interno" con total en S/ 0 y sin cobro, autorizado solo por el administrador.
- [Backend] Reporte del consumo interno.
- [Frontend] Flujo para crear el pedido con autorización del administrador y etiqueta "consumo interno".

## MB-09
**Tipo de actividad:** Mejora
**Título:** Pedido rápido y delivery con repartidor propio del cliente
**Descripción:**
Prioridad: Media
A veces el cliente manda su propio delivery y paga antes por Yape al restaurante.
Criterio de aceptación:
- Acceso directo a "Pedido rápido", sin mesa.
- Con delivery del cliente: sin costo de envío y sin repartidor asignado.
- El pago queda registrado como Yape.
**Subtareas:**
- [Frontend] Acceso directo a "Pedido rápido" y opción de delivery del cliente (sin costo de envío ni repartidor).
- [Backend] Permitir pedidos sin mesa, sin costo de envío y sin repartidor, con el pago de Yape registrado.

## MB-10
**Tipo de actividad:** Mejora
**Título:** Registrar con cuánto paga el cliente y mostrar el vuelto (para llevar y delivery)
**Descripción:**
Prioridad: Media
Criterio de aceptación:
- En pedidos para llevar y delivery se registra "con cuánto paga" y se calcula el vuelto.
- El vuelto se muestra en el mensaje de WhatsApp y en el mensaje del pedido.
**Subtareas:**
- [Frontend] Campo "paga con", cálculo del vuelto y mostrarlo en WhatsApp y en el mensaje del pedido.
- [Backend] Guardar el monto con el que paga, si se quiere conservar.

## MB-11
**Tipo de actividad:** Error
**Título:** Pedido doble: al agregar productos a un pedido ya servido debe volver a pendiente
**Descripción:**
**DESCARTADO:** no se llevará a cabo (decisión del 24-oct-2026).

## MB-12
**Tipo de actividad:** Error
**Título:** El administrador no puede agregar productos si el mozo de la mesa se fue
**Descripción:**
Prioridad: Alta
Si el mozo que atendía la mesa se va, no se pueden agregar más productos a su pedido.
Decisión: solo el administrador puede agregar productos en ese caso; otro mozo no.
**Subtareas:**
- [Backend] Permitir al administrador agregar productos a pedidos de otros mozos.
- [Frontend] Mostrarle la opción de agregar producto.
- [QA] Probar con un mozo distinto y con el administrador.

## MB-13
**Tipo de actividad:** Mejora
**Título:** Mostrar el nombre del mozo en los pedidos
**Descripción:**
Prioridad: Media
Criterio de aceptación:
- El nombre del mozo es visible en los pedidos y en la comanda del cajero.
**Subtareas:**
- [Frontend] Mostrar el nombre del mozo en la lista de pedidos, el detalle y la comanda del cajero.
- [Backend] Confirmar que el cajero recibe el nombre del mozo en el detalle.

## MB-14
**Tipo de actividad:** Mejora
**Título:** Imprimir la cuenta antes y después de cobrar (cajero y administrador)
**Descripción:**
Prioridad: Media
No hay botón para imprimir la cuenta ("boleta en cuenta").
Criterio de aceptación:
- El cajero y el administrador pueden imprimir la cuenta antes y después de cobrar, todas las veces que haga falta.
**Subtareas:**
- [Frontend] Botón de imprimir cuenta disponible antes y después de cobrar, para el cajero y el administrador.
- [Backend] Reimpresión de la cuenta sin límite, también en pedidos pagados.

## MB-15
**Tipo de actividad:** Mejora
**Título:** Mostrar el medio de pago en los comprobantes y en el ticket de venta
**Descripción:**
Prioridad: Media
**Subtareas:**
- [Backend] Incluir el medio de pago en los datos del comprobante y del ticket impresos.
- [Frontend] Mostrar el medio de pago en el ticket y el preview.

## MB-16
**Tipo de actividad:** Mejora
**Título:** Series de boleta, factura y ticket por sede y por caja
**Descripción:**
Prioridad: Alta
Formato de la serie (4 caracteres): tipo (B o F) + código de sede (letra o número) + caja de 2 dígitos. Ejemplos: BA01, F101.
El backend ya tiene series por caja y código de sede.
Referencia: BACKEND_PENDIENTES.md ítem 12.
**Subtareas:**
- [Frontend] Columna Serie por caja en la vista de Caja.
- [Frontend] Código de sede editable en Configuración > Negocio.
- [Frontend] Mostrar la serie que se usará al emitir el comprobante.
- [Backend] Validar el formato de la serie y exponer la serie por caja y sede.

## MB-17
**Tipo de actividad:** Mejora
**Título:** Ticket de venta: indicar delivery, mostrar RUC y dirección del negocio y permitir reimpresiones
**Descripción:**
Prioridad: Media
Criterio de aceptación:
- El ticket indica si el pedido es por delivery.
- Muestra el RUC y la dirección del negocio, que salen de Configuración y no del código.
- El cliente y la caja pueden pedir ticket, boleta o factura tantas veces como se desee.
**Subtareas:**
- [Backend] Datos de la sede (RUC y dirección) y tipo delivery en el ticket impreso.
- [Backend] Reimpresión sin límite de ticket, boleta y factura.
- [Frontend] Mostrar esos datos en el ticket de pantalla y botones de reimprimir.

## MB-18
**Tipo de actividad:** Error
**Título:** El preview del comprobante muestra "Consumo" en lugar del nombre real de las líneas
**Descripción:**
Prioridad: Media
En el preview aparece "Consumo" para productos como el táper y otros, y no se ven bien el cliente, la dirección ni el RUC.
Causa: "Consumo" es el nombre por defecto que arma el backend cuando la línea no tiene plato.
Criterio de aceptación:
- Cada línea muestra su nombre real (por ejemplo "Táper grande").
- El preview muestra el cliente, la dirección y el RUC.
**Subtareas:**
- [Backend] Usar el nombre real de las líneas de táper y otras en el comprobante.
- [Backend] Entregar cliente, dirección y RUC en los datos del comprobante.
- [Frontend] Mostrar esos datos en el preview.

## MB-19
**Tipo de actividad:** Mejora
**Título:** Mostrar la presentación y la variante en la factura o boleta
**Descripción:**
Prioridad: Media
Criterio de aceptación:
- En bebidas y platos con variante, el comprobante muestra la presentación o variante elegida (jarra, vaso, tamaño), en el preview y en el papel.
**Subtareas:**
- [Backend] Confirmar que el nombre de la línea del comprobante incluye la presentación o variante.
- [Frontend] Mostrarla en el preview.
- [QA] Verificar en el papel impreso.

## MB-20
**Tipo de actividad:** Mejora
**Título:** Incluir el estado de pago en el mensaje de WhatsApp
**Descripción:**
Prioridad: Media
Criterio de aceptación:
- El mensaje de WhatsApp indica el estado del pago (pagado, pendiente o parcial).
**Subtareas:**
- [Frontend] Agregar el estado de pago al mensaje de WhatsApp.

## MB-21
**Tipo de actividad:** Mejora
**Título:** Pescados por tamaño y peso, registrados por los mozos
**Descripción:**
Prioridad: Media
Los pescados se venden por tamaño. Los mozos registran los pesos y tamaños (los define cocina) cada 20 a 30 días al ingresar el pescado. Los precios los definen los dueños y varían.
Backend ya registrado: tabla tamano (peso mínimo y máximo), carta_variante con peso y precio propio, y unidad_inventario con el peso de cada pieza.
**Subtareas:**
- [Frontend] Permitir a los mozos registrar los pesos y tamaños al ingreso del pescado.
- [Frontend] Que cada tamaño use su precio en la carta y el pedido.
- [Backend] Confirmar rutas y permisos para que el mozo registre pesos y tamaños.

## MB-22
**Tipo de actividad:** Tarea
**Título:** Cargar platos y precios que faltan en la carta
**Descripción:**
Prioridad: Alta
**Subtareas:**
- [Datos] Crear venado, sajino, lagarto y picudo, los cuatro a S/ 45.
- [Datos] Poner precio a patarashca y a los chilcanos (los define el negocio).
- [Datos] Crear paiche como plato que se vende por trozos (variante o presentación).

## MB-23
**Tipo de actividad:** Mejora
**Título:** Avisar al administrador cuando a un plato le falta el precio
**Descripción:**
Prioridad: Media
Criterio de aceptación:
- Si un plato no tiene precio (con o sin variantes o presentaciones), al administrador le sale un aviso claro con un acceso directo para colocarlo desde ahí.
**Subtareas:**
- [Frontend] Detectar platos, variantes y presentaciones sin precio.
- [Frontend] Aviso con un modal pequeño para escribir el precio y guardar sin ir a la carta.

## MB-24
**Tipo de actividad:** Mejora
**Título:** Platos estrella al inicio de la carta
**Descripción:**
Prioridad: Media
Criterio de aceptación:
- El administrador marca platos como destacados y aparecen primero en la carta.
**Subtareas:**
- [Backend] Campo "destacado" en la carta.
- [Frontend] Marcar platos como destacados y ordenarlos primero.

## MB-25
**Tipo de actividad:** Mejora
**Título:** Orden alfabético de la carta y buscador por palabras
**Descripción:**
Prioridad: Media
Criterio de aceptación:
- Orden alfabético en toda la carta y también dentro de cada categoría; el nombre más corto va primero (JUANE antes de JUANE CON…).
- El buscador ignora mayúsculas, minúsculas y tildes, y encuentra el plato con palabras sueltas y en cualquier orden ("selvatico chaufa" encuentra "1/2 CHAUFA SELVATICO").
- Orden de relevancia: buscar "tacacho" muestra primero el tacacho simple.
- Los platos estrella (MB-24) van primero y, dentro de cada grupo, en orden alfabético.
**Subtareas:**
- [Frontend] Orden alfabético global y por categoría.
- [Frontend] Buscador sin mayúsculas ni tildes, por palabras sueltas y en cualquier orden, con orden de relevancia.

## MB-26
**Tipo de actividad:** Tarea
**Título:** Ubicar el "motivo de cambio de precio" que se pidió eliminar
**Descripción:**
Prioridad: Media
La nota original pedía eliminar el "motivo de cambio de precio" y simplificar la consulta. Se vio en pantalla, pero no se recuerda dónde. En el código no existe un campo con ese nombre; el candidato más probable es el descuento extra, que pide un nombre o motivo del descuento. "Más categorías" se descartó por ser un error de la nota.
**Subtareas:**
- [QA] Indicar en qué pantalla se vio el motivo de cambio de precio (D-01).
- [Frontend] Una vez ubicado, eliminar el campo y simplificar la consulta.

## MB-27
**Tipo de actividad:** Mejora
**Título:** Ajustar tamaños de letra de las comandas (nombre más chico, descripción más grande)
**Descripción:**
Prioridad: Alta
En las comandas el nombre del plato es muy grande y la descripción (notas, táper, variantes, presentaciones) es muy pequeña y casi no se lee.
Criterio de aceptación:
- Nombre del plato más chico y descripción más grande, en ambas comandas: la impresa y la de pantalla.
**Subtareas:**
- [Frontend] Ajustar los tamaños en la comanda de pantalla.
- [Backend] Ajustar los tamaños en la comanda impresa.
- [QA] Verificar legibilidad en papel y en pantalla.

## MB-28
**Tipo de actividad:** Mejora
**Título:** Aumentar el tamaño de las tarjetas con imágenes
**Descripción:**
Prioridad: Media
**Subtareas:**
- [Frontend] Tarjetas con imagen más grandes en la carta y en el registro de pedido.

## MB-29
**Tipo de actividad:** Error
**Título:** Controles muy pequeños en el celular (desunir mesas, buscadores)
**Descripción:**
Prioridad: Media
El ícono de desunir mesas es muy pequeño para tocarlo y el buscador también. Pasa en la carta, el registro de pedido y el buscador.
**Subtareas:**
- [Frontend] Agrandar el ícono de desunir mesas y los buscadores a un tamaño cómodo para tocar.
- [QA] Probar en celular.

## MB-30
**Tipo de actividad:** Error
**Título:** Textos largos en la APK no respetan el contenedor
**Descripción:**
Prioridad: Media
Criterio de aceptación:
- Los textos largos bajan de línea y respetan el límite de su contenedor, sin cortarse ni desbordarse.
**Subtareas:**
- [Frontend] Revisar y corregir los textos que se cortan o desbordan en la APK.
- [QA] Probar en celulares de distinto tamaño.

## MB-31
**Tipo de actividad:** Mejora
**Título:** Mostrar toast solo en procesos relevantes
**Descripción:**
Prioridad: Media
Solo estos procesos muestran toast; ninguna otra acción lo hace:
1. Creación y desactivación de usuarios.
2. Actualización y eliminación de registros (platos, categorías, mesas, medios de pago, tápers, etc.). La creación de registros no lleva toast.
3. Alertas de confirmación del tipo "¿estás seguro de…?".
4. Errores.
5. Estados del pedido (pendiente, servido, pagado, anulado…) y sus avisos informativos.
El historial de la campana del header solo guarda lo que muestra toast.
**Subtareas:**
- [Frontend] Auditar todos los avisos actuales de la app.
- [Frontend] Quitar los que no estén en la lista.

## MB-32
**Tipo de actividad:** Mejora
**Título:** Botón "Guardar cambios" en Configuración > Restaurante
**Descripción:**
Prioridad: Baja
**Subtareas:**
- [Frontend] Agregar el botón de guardar cambios.

## MB-33
**Tipo de actividad:** Mejora
**Título:** Mayor notoriedad en las barras de Ventas, Inventario y Configuración
**Descripción:**
Prioridad: Baja
**Subtareas:**
- [Frontend] Resaltar más las barras de subvistas.

## MB-34
**Tipo de actividad:** Mejora
**Título:** Descripción para cada medio de pago (varios números de Yape)
**Descripción:**
Prioridad: Media
El negocio tiene varios números de Yape.
Criterio de aceptación:
- Cada medio de pago tiene una descripción (por ejemplo, de quién es el número) para distinguirlos al cobrar y en el cuadre.
**Subtareas:**
- [Backend] Confirmar que el medio de pago guarda y devuelve la descripción.
- [Frontend] Editar y mostrar la descripción en Configuración, en el cobro y en el cuadre.

## MB-35
**Tipo de actividad:** Mejora
**Título:** Low-code para el administrador
**Descripción:**
Prioridad: Baja
El administrador debe poder cambiar sin tocar código:
- Datos del negocio: sede, RUC, dirección y logo del ticket.
- Textos y formatos de tickets y comandas (tamaños de letra, campos y orden).
- Tarjetas y vistas, por ejemplo qué se muestra en Ventas > Caja.
- Medios de pago y sus descripciones.
**Subtareas:**
- [Backend] Guardar y entregar la configuración de datos del negocio y de formatos de tickets y comandas.
- [Frontend] Pantallas de Configuración para datos del negocio y formatos.
- [Frontend] Configurar qué tarjetas se muestran en Ventas > Caja.
- [Frontend] Medios de pago con descripción (ver MB-34).

## MB-36
**Tipo de actividad:** Mejora
**Título:** Archivo único de marca para los desarrolladores (tipografía, colores, logos e íconos)
**Descripción:**
Prioridad: Baja
Criterio de aceptación:
- Un solo archivo de configuración de marca dentro del código; se cambia ahí y se recompila.
**Subtareas:**
- [Frontend] Reunir tipografía, colores, logos e íconos en un archivo de marca.
- [Frontend] Hacer que toda la app lea la marca de ese archivo.

## MB-37
**Tipo de actividad:** Mejora
**Título:** "Show stopper": avisos que impiden continuar hasta resolver
**Descripción:**
Prioridad: Baja · Por definir (parcial)
Avisos bloqueantes que no dejan seguir hasta resolver el problema (un toast informa y desaparece; el show stopper obliga a resolver antes de seguir).
Ámbito: Caja y Pedido.
Primer caso definido: no se abrió la caja y ya están registrando pedidos.
Otros casos: por definir por QA (D-07), junto con a qué roles bloquea y si se puede saltar con autorización del administrador.
**Subtareas:**
- [QA] Listar los casos concretos de Caja y Pedido, los roles que bloquean y si hay salto con autorización.
- [Frontend] Componente de aviso bloqueante con acceso para resolver (por ejemplo, ir a abrir la caja).
- [Frontend] Caso 1: bloquear el registro de pedidos si la caja no está abierta.
- [Backend] Rechazar en el servidor los pedidos cuando no hay caja abierta, con un error claro.

## MB-38
**Tipo de actividad:** Mejora
**Título:** Alertas de stock en tiempo real
**Descripción:**
Prioridad: Baja
Se había descartado y se reactiva como mejora pendiente (decisión del 24-oct-2026).
Criterio de aceptación:
- Alertas de stock en la campana del header y eventos del servidor en tiempo real.
**Subtareas:**
- [Backend] Eventos en tiempo real cuando un producto de inventario o táper queda en o por debajo de su mínimo (y cuando se agota), solo para el administrador.
- [Backend] Mínimo configurable en los tápers.
- [Frontend] Mostrar las alertas en la campana del header.

## MB-39
**Tipo de actividad:** Mejora
**Título:** Precio de empleado por plato, variante y presentación, guardado en el servidor
**Descripción:**
Prioridad: Media
No es un descuento: es un precio de empleado.
Backend: ya existe el campo precio_personal en la carta, en las variantes y en las presentaciones. La app solo lo modela en el plato.
Criterio de aceptación:
- El administrador edita el precio de empleado en la carta, para plato, variante y presentación.
- Un pedido de empleado se cobra con ese precio; ticket, comprobante y reportes muestran lo realmente cobrado, sin descuento de por medio.
- Solo el administrador o el cajero registran el consumo de un mozo.
- Si falta el precio de empleado, al administrador y al cajero se les avisa en el momento con un tooltip o modal pequeño donde lo escriben ahí mismo.
**Subtareas:**
- [Frontend] Modelar y editar el precio de empleado en variantes y presentaciones.
- [Frontend] Aviso de precio de empleado faltante con edición rápida (administrador y cajero).
- [Frontend] Usar el precio de empleado en el pedido de empleado.
- [Backend] Ruta de actualización rápida del precio de empleado y su validación de permisos.
- [Backend] Cobrar y facturar los pedidos de empleado con el precio de empleado.

## MB-40
**Tipo de actividad:** Mejora
**Título:** Selector "Cliente / Empleado" que muestra los precios que corresponden
**Descripción:**
Prioridad: Media
Un pedido es de cliente o de empleado, nunca de los dos. El tipo se elige al crear el pedido y no cambia después.
Criterio de aceptación:
- Un tag selector (Cliente | Empleado) al crear el pedido; la pantalla muestra los precios de ese tipo. No se activa ni cambia ningún precio, solo se muestra el que corresponde.
- Cambia por evento, con datos ya cargados; sin polling ni refrescos periódicos.
- Solo el administrador y el cajero ven la opción Empleado.
**Subtareas:**
- [Frontend] Tag selector Cliente / Empleado al crear el pedido, visible solo para administrador y cajero.
- [Frontend] Mostrar carta, líneas y totales con el tipo de precio elegido, por evento y sin polling.
- [Backend] Guardar el tipo de precio del pedido y el precio aplicado a cada línea.
- [Backend] Validar que el pedido de empleado lo cree solo el administrador o el cajero.

## MB-41
**Tipo de actividad:** Mejora
**Título:** Agregar un botón "x" para cerrar los toast
**Descripción:**
Prioridad: Media
Un toast se queda en pantalla hasta que se cierra solo y estorba mientras se trabaja.
Criterio de aceptación:
- Todos los toast tienen un botón "x" para quitarlos de inmediato, en celular y en pantalla grande.
- Cerrarlo a mano no borra el aviso de la campana del header.
**Subtareas:**
- [Frontend] Agregar el botón "x" a todos los toast.

# Backend: permitir que el mozo registre pedidos de personal (empleado)

Documento solo de explicación. No incluye cambios de código; sirve para que quien
mantiene el backend los haga.

## Qué pasa hoy

En la app (frontend) el mozo ya puede elegir "para quién" es el pedido: Cliente,
Familia o Empleado. Al confirmar un pedido de **empleado**, el servidor lo
rechaza con:

> solo administradores y cajeros pueden registrar pedidos de personal (empleado)

La restricción está **en el backend**, no en la app. La app envía el pedido bien
armado (tipo `empleado`, con `precio_personal` en cada producto); el servidor lo
rechaza solo por el rol de quien lo envía.

## Dónde está la restricción

Archivo: `internal/repositories/pedido_mozo_repository.go`.
La función `esAdminOCajeroTx` (línea ~3985) solo deja pasar a los roles
`administrador`, `admin` y `cajero`. Se usa en tres sitios relacionados con
pedidos de personal:

| # | Función | Línea aprox. | Mensaje de error | Qué impide |
|---|---------|--------------|------------------|------------|
| 1 | crear pedido (tipo `empleado`) | ~665 | "solo administradores y cajeros pueden registrar pedidos de personal (empleado)" | **Crear** el pedido |
| 2 | agregar un producto a un pedido existente | ~885 | "solo administradores y cajeros pueden agregar productos a un pedido de personal" | Agregarle productos después |
| 3 | `UpdatePrecioPersonalFila` | ~3872 | "solo administración y caja pueden modificar precios en pedidos" | Corregir el precio de empleado de una fila |

## Qué habría que habilitar

1. **Crear (1) y agregar productos (2):** permitir también el rol `mesero`
   (mozo), por ejemplo ampliando la lista de roles de la consulta de
   `esAdminOCajeroTx` o con una función nueva que incluya a `mesero`. Las
   validaciones que siguen (que cada producto traiga `precio_personal`, que el
   pedido no esté pagado ni anulado) pueden quedar igual.
2. **Cambiar el precio (3):** decidir si el mozo también puede corregir el precio
   de empleado de una fila. Si no, la app lo deja en solo lectura para el mozo y
   lo hace caja o administración. Es una decisión de negocio.
3. **Sin cambios de base de datos.** Es solo una regla de permisos.

## Pedidos de familia (cuenta cero)

No tienen restricción de rol al crearse. La app crea el pedido y luego le aplica
un descuento del 100 %. Ese descuento exige el permiso `OTORGAR.DESCUENTO` (o la
autorización de un supervisor con PIN). Para el mozo, la app ya pide el PIN de un
supervisor antes de crear el pedido, así que **no hace falta cambiar nada en el
backend para familia**.

## Cómo comprobarlo

1. Entrar a la app con un usuario de rol mozo.
2. Pedidos > Nuevo > Empleado > elegir tipo > agregar productos > "Precio
   empleado" para cada uno > Confirmar.
3. Antes del cambio: sale el error de arriba. Después: el pedido se crea y aparece
   en la vista "Empleados" de Pedidos.

## Lo que no cambia

- El cobro de pedidos de empleado sigue siendo de caja o administración.
- La app no requiere cambios para esto: ya envía lo que el servidor espera.

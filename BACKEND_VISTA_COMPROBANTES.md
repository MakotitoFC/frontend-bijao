# Backend: vista "Comprobantes" (historial de boletas y facturas)

## Qué se hizo en el frontend

Nueva vista **Comprobantes** en el menú (administrador y cajero, mismo permiso
que Caja: `LEER.PAGO`). Es un registro de **todas las boletas y facturas**, sin
depender del turno ni del cierre de caja:

- Selector de fechas (por defecto, hoy; admite un día o un rango).
- Filtro Todos / Boletas / Facturas.
- Buscador por número, cliente o documento.
- Tabla paginada (10 por página), con estado ante SUNAT, PDF, reimprimir y
  consultar estado de los pendientes.

Hoy usa el endpoint que ya existe, sin cambios en backend:

```
GET /api/v1/facturacion/comprobantes?desde=YYYY-MM-DD&hasta=YYYY-MM-DD&tipo_documento=boleta|factura
```

Funciona, pero con las limitaciones de abajo. Lo que sigue es lo que
necesitamos para que escale y sea fiable como registro.

## 1. Confirmar (sin esto la vista no cumple su propósito)

1. **Que el listado no dependa de la caja.** `GET /comprobantes` debe devolver los
   comprobantes de cualquier fecha pedida, hayan salido en el turno actual,
   en uno cerrado o en un día sin caja abierta. Hoy el frontend filtra por turno
   solo en el panel de Caja; esta vista no filtra nada por turno.
2. **`hasta` inclusivo por día completo**, en hora de Lima (`America/Lima`).
   Pedir `desde=2026-11-03&hasta=2026-11-03` debe traer todo el 3 de noviembre.
3. **Permisos:** que el rol CAJERO y ADMINISTRADOR (con `LEER.PAGO`) puedan
   leer el listado. Un cajero debe ver también los comprobantes de días y turnos
   anteriores (es un registro, no solo del turno).

## 2. Cambios pedidos al listado

| # | Cambio | Para qué |
|---|--------|----------|
| 1 | **Paginación en servidor:** parámetros `pagina` (desde 1) y `limite` (por defecto 20, máximo 100). Devolver el total de filas, por ejemplo con el encabezado `X-Total-Count`, para no romper a quien ya lee un arreglo. | Hoy devuelve todo el rango. Con meses de datos la respuesta crece sin límite. |
| 2 | **Solo fiscales:** aceptar `tipo_documento=boleta,factura` (lista separada por comas) o un parámetro `solo_fiscales=true`. | El frontend hoy trae también los tickets de venta y los descarta. |
| 3 | **Búsqueda:** parámetro `q` que busque por número de comprobante (`B001-00000104`), nombre del cliente y número de documento (DNI/RUC), sin distinguir mayúsculas. | La búsqueda hoy es solo sobre la página cargada. |
| 4 | **Filtro por estado:** confirmar que `estado_sunat` acepta lista (`ACEPTADO,PENDIENTE`). | Permitirá filtrar rechazados/pendientes más adelante. |
| 5 | **Totales del rango:** devolver la suma de `total` excluyendo `ANULADO` y `RECHAZADO` (por ejemplo `X-Suma-Total`) y la cantidad. | El frontend muestra "N comprobantes · S/ X" y hoy lo calcula solo con lo que trae. |
| 6 | **Orden:** más reciente primero (`fecha_emision` + `hora_emision` desc, desempate por número), de forma estable entre páginas. | Evitar filas repetidas o salteadas al paginar. |

Si prefieren no tocar el endpoint actual, también sirve uno nuevo
(`GET /facturacion/comprobantes/historial`) con estos parámetros, dejando el
actual como está.

## 3. Datos de cada fila

Confirmar que cada comprobante del listado trae, como ya lo lee el frontend
(`Comprobante.fromJson`): `id`, `pedidos_id`, `tipo_documento`,
`numero_comprobante`, `fecha_emision`, `hora_emision`, `cliente_tipo_doc`,
`cliente_num_doc`, `cliente_denominacion`, `total`, `total_igv`, `estado_sunat`,
`pse_mensaje`, `usuario_nombre`, `pdf_ticket_url` y `pdf_a4_url`.

**Importante para un registro histórico:** los enlaces de PDF que devuelve
Lucode pueden caducar con el tiempo. Para comprobantes antiguos conviene que
`pdf_a4_url` / `pdf_ticket_url` apunten al respaldo propio (R2 o disco local, ya
existe `/comprobantes/:id/descargar/:archivo`), o que indiquen qué campo debe
usar el frontend para abrir el PDF de un comprobante viejo. Dígannos cuál y lo
ajustamos.

## 4. Rendimiento

Índice sugerido para el listado por fecha y tipo, por sede:
`comprobante_pago (sede_id, fecha_emision DESC, tipo_documento)`.

## 5. Pruebas pedidas

1. Emitir una boleta, cerrar caja y abrir una nueva: la boleta sigue apareciendo
   en la vista al elegir su fecha.
2. Rango de varios días con más de 20 comprobantes: la paginación devuelve cada
   fila una sola vez y el total coincide.
3. Filtro por boleta y por factura: no aparecen tickets de venta.
4. Búsqueda por número, por nombre y por DNI/RUC.
5. Un comprobante `RECHAZADO` y uno `ANULADO` salen en la lista pero no suman al
   total.
6. Un cajero puede leer comprobantes de fechas anteriores a su turno.

## Pendientes relacionados (ya enviados aparte)

- La **reimpresión** de un comprobante debe usar el detalle realmente emitido,
  no el del pedido original (se ve en esta misma vista, botón de impresora).
- Que el error de **PSE 404** no devuelva HTML crudo ni quede guardado como
  `RECHAZADO`.

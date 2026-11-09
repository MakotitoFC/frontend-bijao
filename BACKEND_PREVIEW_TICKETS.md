# Backend: preview de la cuenta de consumo y de los comprobantes (lo mismo que se imprime)

Documento solo de explicación. No incluye cambios aplicados; sirve para que quien
mantiene el backend los implemente.

## Para qué

En la app, antes de imprimir, hay un preview de la **cuenta de consumo** y de los
**comprobantes** (boleta, factura, ticket de venta). Hoy ese preview lo arma la app con
su propio texto (`lib/utils/ticket_texto.dart`), y **no coincide** con lo que imprime
el servidor: el servidor usa `FormatPrecuenta` y `FormatTicketComprobante`, con las
plantillas configurables, el logo, la hora de impresión, las notas, el IGV, los
medios de pago, etc.

Para que el preview sea **exactamente** lo que se imprime, debe salir del mismo código
que imprime. Hace falta que el servidor ofrezca el ticket **sin imprimirlo**.

## Qué existe hoy (y se puede reutilizar)

- Cuenta de consumo: `PrinterService.BuildPrecuentaPayloadFromDB(ctx, pedidoID, orden)`
  arma los datos y `PrinterService.FormatPrecuenta(payload, cfg, plantilla)` devuelve los
  bytes ESC/POS.
- Comprobantes: `FacturacionService.ReimprimirComprobante` arma un
  `dto.PrintComprobantePayload` (línea ~1029 de `facturacion_service.go`) y
  `PrinterService.FormatTicketComprobante(payload, cfg, plantilla)` devuelve los bytes.
- Configuración y plantilla: `PrinterService.GetConfig(ctx, sedeID)` y
  `PrinterService.GetPlantilla(ctx, sedeID, tipoDoc)`.
- Lectura de los bytes ESC/POS: `EscposParser` (`escpos_pdf_renderer.go`) los convierte
  en tokens (`EscposToken`): texto, imagen, QR y corte, con alineación (izquierda,
  centro, derecha), negrita y tamaño doble.

Lo único que falta es **una ruta que arme y formatee el ticket sin crear un trabajo de
impresión**, y lo devuelva en un formato que la app pueda dibujar.

## Qué agregar

Dos rutas de solo lectura, dentro del grupo `/v1/impresion` (mismos roles que el resto:
MOZO, CAJERO, ADMINISTRADOR):

| Ruta | Qué devuelve |
|------|--------------|
| `GET /api/v1/impresion/preview/cuenta/:pedido_id` | El ticket de la cuenta de consumo del pedido, tal como se imprimiría ahora |
| `GET /api/v1/impresion/preview/comprobante/:comprobante_id` | El ticket del comprobante ya emitido (boleta, factura o ticket de venta) |

Ambas reutilizan las funciones de arriba:
`payload -> Format* -> EscposParser.Parse() -> JSON`.

### Importante

- **No crear filas en `print_jobs`** ni mandar nada a la impresora.
- **No consumir correlativos** ni emitir nada.
- Para el comprobante, la ruta solo lee uno **ya emitido**. Antes de emitirlo no hay
  serie ni número, y la app seguirá mostrando sus marcas.
- Para el comprobante, no hace falta repetir las validaciones de
  `ReimprimirComprobante` (RECHAZADO, ANULADO): el preview puede mostrarse igual.

## Formato de respuesta (texto estructurado)

JSON ligero, una entrada por línea del ticket. Es suficiente para dibujar el ticket con
letra monoespaciada:

```json
{
  "ancho": 42,
  "lineas": [
    { "texto": "CUENTA DE CONSUMO", "alineacion": "centro", "negrita": true, "doble": true },
    { "texto": "RUC: 20540005371", "alineacion": "centro" },
    { "texto": "Mozo:            Ana", "alineacion": "izquierda" },
    { "texto": "TOTAL: S/    32.00", "alineacion": "derecha", "negrita": true, "doble": true }
  ],
  "logo_url": "/api/v1/impresion/config/logo",
  "qr": "https://..."
}
```

Notas del formato:

- `alineacion`: `izquierda`, `centro` o `derecha` (el campo `Align` 0, 1, 2 del token).
- `negrita` y `doble` (ancho o alto doble) salen de los mismos campos del token. Si el
  campo no aplica, se omite.
- `ancho`: caracteres por línea del ticket (el `LineWidth` que ya usa el servidor), para
  que la app pueda dibujar la misma anchura.
- `logo_url`: solo si la plantilla imprime logo. **No** mandar la imagen convertida
  en el JSON; la app la pide de la ruta que ya existe `GET /v1/impresion/config/logo`.
- `qr`: el texto del QR si el comprobante lo lleva, para que la app lo dibuje.
- Los tokens de imagen y de corte no se envían como líneas.

## Rendimiento

- Es una lectura puntual al abrir el preview. Son pocas consultas para un pedido y el
  resto es armar texto: milisegundos en una red local.
- El logo es lo más costoso (se convierte a imagen de impresora); por eso va como
  dirección y no en el JSON. Si hiciera falta, guardar la conversión del logo en memoria.

## Qué hará la app (para tu información)

- Al abrir el preview pedirá la ruta, mostrará un indicador de carga y dibujará las
  líneas con el mismo visor que ya tiene.
- Si el servidor no responde, mostrará un aviso en vez de un preview distinto del que se
  imprimiría. No cambia nada del flujo de "Imprimir".
- Cuando estas rutas existan, la app quitará su propio armado del texto de estos tickets.

## Cómo comprobarlo

1. Abrir un pedido con productos, una nota, descuento y propina, y pedir el preview de la
   cuenta. Debe verse igual que el ticket impreso: encabezado de la plantilla, ORDEN,
   Mozo, hora de impresión, totales, mensaje fiscal y pie.
2. Cambiar algo en "Plantillas de impresión" (por ejemplo, apagar el logo o el monto en
   letras) y volver a pedir el preview: debe reflejar el cambio sin tocar la app.
3. Pedir el preview de un comprobante emitido: debe mostrar su serie y número reales.
4. Verificar que, tras los previews, no aparecen trabajos nuevos en `print_jobs` ni
   cambian los correlativos.

# Backend: diseño del reporte de caja en HTML/PDF

## Qué se pide

Los reportes **"Detalle del día completo"**, **"Detalle del turno"** y **"Reportes
de otra fecha"** (PDF/HTML) deben verse con el mismo diseño de la vista de Caja
de la app: sin cajas con relleno gris, fondo blanco, la misma fuente y los mismos
colores.

## Dónde está hoy

`GetReporteDiaDetalladoHTML` en `internal/handlers/caja_handler.go`
(`GET /api/v1/caja/reportes/dia-detallado/html`). La app solo abre esa URL en el
navegador (`caja_service.dart`, `urlReporteDiaDetallado`), así que el diseño se
cambia en esa plantilla HTML (el bloque `<style>` y el cuerpo). La app no manda
estilos.

Hoy el reporte usa: fuente del sistema, tarjetas con fondo gris `#f8f9fa` y borde
izquierdo de color, tablas con todas las líneas, botón azul `#228be6`.

## Diseño que debe tener

**Base**
- Fuente **Poppins** (`<link>` de Google Fonts; con respaldo `Arial, sans-serif`
  para cuando no haya internet en la red local).
- Fondo blanco, texto `#111827`, secundario `#6B7280`.
- Margen lateral de 24 px; ancho máximo 1100 px, centrado.
- Colores de la app: verde `#0CAB7B` (principal), oscuro `#1F1F1F`, error
  `#C24444`.

**Encabezado**
- Nombre de la sede (18 px, peso 700) y debajo el título del reporte y el día
  operativo en gris (13 px). Una línea fina `#E5E7EB` debajo. Sin barra gruesa.
- El botón "Descargar en PDF / Imprimir" pasa a ser el verde `#0CAB7B` con texto
  blanco, esquinas de 8 px, 36 px de alto (oculto al imprimir).

**Tarjetas de totales** (Apertura, Ingresos, Egresos, Neto, Efectivo, Tarjetas /
POS, Yape / Plin) — igual que en Caja:
- Fondo **blanco**, borde `1px #E5E7EB`, esquinas de 16 px, sin borde de color a
  la izquierda ni sombra pesada.
- A la izquierda un cuadro de 36 px con el ícono en su color y borde del color
  suave (no relleno); título en 13 px, peso 600, gris `#6B7280`.
- Monto en 26 px, peso 700; los decimales más pequeños y en gris.
- Colores por tarjeta (solo el ícono): apertura `#0EA5E9`, ingresos `#10B981`,
  egresos `#C24444`, neto `#8B5CF6`, efectivo `#16A34A`, tarjetas `#3B82F6`,
  Yape/Plin `#D946EF`.
- Cuadrícula de 4 columnas en pantalla ancha, 2 en celular.

**Secciones** (por medio de pago, ventas, ingresos y salidas, traspasos…)
- Título de sección en 15 px, peso 700, sin subrayado grueso.
- **Sin contenedor**: la tabla va directamente sobre el fondo blanco.

**Tablas**
- Solo líneas horizontales finas `#E5E7EB` (sin bordes verticales).
- Encabezado sin relleno de color: texto en mayúsculas pequeñas (11 px), gris,
  con una línea inferior un poco más marcada.
- Filas con 10 px de alto de relleno vertical; montos alineados a la derecha.
- Etiquetas (mesa, delivery, para llevar, anulado…): píldoras de 6 px de radio
  con fondo del color al 12 % y texto del color (mismo estilo de las etiquetas de
  la app); sin los colores fuertes actuales.

**Impresión**
- Al imprimir: sin márgenes grandes, tablas de 10 px, saltos de página sin cortar
  una fila, y las tarjetas en 4 columnas.

## Pruebas pedidas

1. Abrir el reporte del día completo, el del turno y el de otra fecha: los tres se
   ven con el mismo diseño.
2. Imprimir / guardar como PDF: cabe en hoja A4 y no se cortan filas.
3. Sin internet (red local): se ve con la fuente de respaldo, sin errores.

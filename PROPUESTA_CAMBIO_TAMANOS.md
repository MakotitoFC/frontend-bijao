# Propuesta de cambio sobre el tamaño

Documento para el desarrollador del backend. Describe cómo se registran hoy los
tamaños de un plato, cómo se propone
que sea y qué se necesita del backend.

## Qué es un tamaño

Un mismo plato que se vende en varios tamaños, cada uno con su precio. Por
ejemplo, el Ceviche: Pequeño S/ 18 y Grande S/ 28.

En el backend un tamaño es una variante del plato (`carta_variante`): pertenece
a un plato (`carta_id`), tiene `nombre`, `precio_cliente` y `precio_personal`, y
opcionalmente `tamano_id` (catálogo `tamano`) y un rango de peso.

## Cómo se hace hoy (muchos pasos)

Para crear "Ceviche Pequeño":

1. Ir a Inventario.
2. Abrir la pestaña Tamaños.
3. Pulsar "Tamaño".
4. Elegir el plato "Ceviche".
5. Escribir el nombre "Pequeño".
6. Escribir el precio de cliente.
7. Escribir el precio personal.
8. Guardar.

Para el tamaño Grande se repite todo desde el paso 3. QA indica que son demasiados
clics. Además, los tamaños son de la carta (lo que se vende) y hoy se crean en
Inventario (lo que se compra y se guarda), lo que confunde.

## Cómo se propone que sea (pocos pasos)

Todo se hace al crear o editar el plato en la Carta, sin entrar a Inventario.
Solo el administrador registra tamaños.

1. Abrir "Nuevo plato", o editar "Ceviche".
2. Activar el interruptor **"Tiene tamaños"**.
3. Aparecen filas en la misma pantalla: escribir "Pequeño" y 18, pulsar
   "+ Agregar tamaño", escribir "Grande" y 28.
4. Guardar el plato. Quedan creados los dos tamaños a la vez.

Si después se quiere agregar un tamaño a un plato que ya existe, la tarjeta del
plato tendrá un botón **"+ Tamaño"** (solo administrador) que abre un cuadro con
solo nombre y precio.

Detalles de la propuesta:

- Con el interruptor activo, el precio base del plato pasa a ser opcional y la
  carta muestra "Desde S/ …" (ya existe para platos sin precio base).
- El peso mínimo y máximo (para el pescado) quedan en una sección "Avanzado",
  plegada por defecto.
- El precio personal se completa solo con el de cliente, y se puede editar.
- Si un plato ya tiene tamaños y se apaga el interruptor, no se borran sin
  avisar: se desactivan y se muestra un aviso.
- La pestaña Inventario > Tamaños se oculta del menú, porque ya no hace falta.

## Lo que se necesita del backend

Dos ajustes que hacen el proceso más rápido y seguro:

1. **`precio_personal` opcional.** Hoy `CreateCartaVarianteRequest` lo exige
   (`binding:"required"`), igual que `precio_cliente`. Pedimos que sea opcional
   y que, si no se envía, se guarde el mismo valor que `precio_cliente`.

2. **Enviar los tamaños junto con el plato, en una sola operación.** Hoy
   `POST /api/carta` y `PUT /api/carta/:id` solo reciben los datos del plato, y
   cada tamaño se crea aparte (`/api/carta-variantes`). Pedimos que ambas rutas
   acepten una lista `variantes` y las guarden **en la misma transacción**, para
   que no quede un plato guardado sin sus tamaños si algo falla. Forma sugerida:

   ```json
   {
     "nombre_plato": "Ceviche",
     "subcategoria_id": "...",
     "variantes": [
       { "nombre": "Pequeño", "precio_cliente": 18 },
       { "nombre": "Grande",  "precio_cliente": 28 }
     ]
   }
   ```

   En `PUT`, definir qué ocurre con los tamaños existentes que no vienen en la
   lista (sugerencia: no borrarlos; se actualizan por `id` los que vengan, y se
   desactivan solo si se pide expresamente).

3. **Permisos.** Confirmar que crear, editar y desactivar tamaños requiera
   rol `ADMINISTRADOR` (o el permiso de carta que corresponda), para que no
   dependa solo de ocultar el botón en el frontend.

Sin estos ajustes el frontend puede igualmente implementar el interruptor y las
filas: crea el plato y después cada tamaño por separado. La diferencia es que,
si falla un tamaño, el plato queda guardado a medias.

## Impacto en el frontend

- Formulario del plato: interruptor "Tiene tamaños" y filas de nombre y precio.
- Tarjeta del plato en la Carta: botón "+ Tamaño" (solo administrador).
- Se oculta Inventario > Tamaños (sin borrar el código).
- Estimación: de unos 10 clics por tamaño a unos 3. Es una estimación, no una
  medición.

# Pendientes del backend — posibles chequeos

Solo lo que sigue sin resolver. Ya corregido y comprobado en el código del
backend: el conflicto de rutas `/uploads` (commit 436ecc2), `por-liberar` ya no
lista mesas con otro pedido abierto, `CreatePedidoMozo` rechaza una mesa que no
está disponible, y `PUT /api/carta/:id` conserva `url_imagen`.

## Usuarios (nuevo `POST` y `DELETE /api/usuarios`)

1. **Rol desconocido = el primer rol de la tabla (puede ser ADMINISTRADOR).** En
   `CreateUsuario` (`rbac_repository.go`, ~línea 283), si el nombre del rol no
   se encuentra, se hace `SELECT id, rol FROM rol ORDER BY id ASC LIMIT 1` y se
   usa ese rol sin avisar. En la semilla ese primer rol es `ADMINISTRADOR`
   (`...221`). Un nombre mal escrito, `COCINERO`, `TRABAJADOR` o un texto como
   "Mozo / Mesero" crea un administrador sin error. Pedimos responder `400`
   ("rol no encontrado") en vez de asignar otro rol. El frontend enviará
   `rol_id` (UUID de la lista de roles) para no depender del nombre.

2. **Los roles `COCINERO` y `TRABAJADOR` no existen.** La semilla
   (`00002_seed_initial_data.sql`) solo crea `ADMINISTRADOR`, `CAJERO` y
   `MOZO`. La guía menciona `COCINERO` y el frontend usa `TRABAJADOR` para
   cocina. Confirmar cómo se llama el rol de cocina y crearlo (con migración
   nueva).

3. **Longitudes sin validar.** `usuario` es `VARCHAR(30)` e `identificacion`
   máximo 9 caracteres, pero el backend no lo comprueba antes del `INSERT`: el
   error llega como texto de la base ("error insertando usuario: ..."). Pedimos
   validar y responder un mensaje claro. Además `apellidos` vacío se guarda como
   `"."`.

4. **`DELETE /api/usuarios/:id`.** Es un borrado real. No impide que un
   administrador se elimine a sí mismo ni que se elimine al último
   administrador, ignora los errores de las dos primeras sentencias
   (`permiso_usuario` y `profile`) y, si el usuario tiene pedidos o pagos,
   falla por llave foránea con un texto técnico. Pedimos: bloquear esos dos
   casos, responder un mensaje claro cuando tenga registros vinculados y
   confirmar si habrá borrado lógico (el frontend ya puede desactivar con
   `PUT /usuarios/:id/estado`).

5. **Quién puede crear administradores.** Quien tenga `CREAR.USUARIO` puede
   crear un usuario con rol `ADMINISTRADOR`. Confirmar si es lo deseado o si
   solo un administrador debe poder asignar ese rol.

## Imágenes: nube (R2) y subida

6. **En la nube hay que definir `R2_PUBLIC_URL`.** `StorageService.Upload` sube
   el archivo a R2 y, si `R2_PUBLIC_URL` no está configurada, devuelve
   `/uploads/<carpeta>/<archivo>` (no la dirección del bucket). Esa ruta solo
   existe en el disco del servidor, que en la nube es temporal: tras un reinicio
   o un nuevo despliegue la foto desaparece aunque esté en R2. Pedimos: (a)
   configurar `R2_PUBLIC_URL` en la nube para devolver siempre la dirección
   completa, o (b) que el servidor sirva `/uploads/...` leyendo desde R2.
   El frontend acepta las dos formas: `http...` tal cual y `/uploads/...`
   anteponiendo el servidor.

7. **Fallo de subida a R2 sin aviso.** En `handleUpload`, si falla la subida a
   la nube se guarda la copia en el disco local y la respuesta es 200 igual
   (solo queda un `[UPLOAD-WARN]` en el log). Al mozo o administrador le parece
   que todo salió bien, pero la foto queda en un lugar que se puede perder.
   Pedimos al menos devolver `storage: "local"` con una advertencia visible
   (ya se devuelve `storage`; el frontend puede mostrarla) o responder error.

## Caché de imágenes, fuentes e íconos

(El frontend aún no implementa su parte: `cached_network_image` para APK y
Windows e incluir las fuentes en la app.)

8. **`/assets/*` con `immutable` de un año.** En `main.go` (~líneas 501 y 525)
   los archivos de `build/web/assets` (íconos, fuentes e imágenes de la app) se
   sirven con `Cache-Control: public, max-age=31536000, immutable`. Flutter no
   cambia el nombre de esos archivos entre versiones y su contenido sí cambia:
   `lucide.ttf` pesó 35 112 bytes en un build y 30 780 en el siguiente, y
   `MaterialIcons-Regular.otf` cambia en cada build (se recorta a los íconos
   usados). Con `immutable`, un navegador que ya los tiene no los vuelve a
   pedir en un año: tras publicar una versión nueva pueden verse íconos
   faltantes o imágenes viejas (por ejemplo si se reemplaza el logo). Pedimos
   usar `no-cache` o un `max-age` corto con revalidación (`ETag` o
   `Last-Modified`, que responde 304) en `/assets/*`. `immutable` sí es
   correcto en `/uploads/carta`, porque cada foto tiene un UUID nuevo.

9. **Fotos en la nube sin `Cache-Control`.** Las cabeceras de caché de
   `/uploads/carta` (un año, `immutable`) solo aplican cuando la foto se sirve
   desde el servidor. En modo nube la foto sale de R2 o Supabase, y
   `storage_service.go` sube sin `CacheControl` (`PutObjectInput` sin ese campo
   en R2; `FileOptions` sin `CacheControl` en Supabase, que usa 1 hora por
   defecto). Pedimos agregar `CacheControl: "public, max-age=31536000,
   immutable"` al subir a R2 y a Supabase. Sin eso, en la nube las fotos no se
   guardan en caché del navegador ni de la app.

10. **CORS del bucket para la PWA.** Cuando la PWA muestre fotos desde R2 (otro
    dominio), el bucket necesita una política CORS que permita el dominio de la
    PWA: Flutter web descarga la imagen con una petición, no con una etiqueta
    `<img>`. Confirmarlo probando la PWA contra R2.

11. **`.js`, `.wasm`, `.json` y `.html` con `no-store`.** Se descargan completos
    en cada carga (`main.dart.js` pesa unos 3,3 MB). `no-cache` con `ETag` evita
    quedarse con una versión vieja sin volver a descargar si no cambió.

12. **`CacheStaticMiddleware` sin usar.** `internal/middleware/cache_assets.go`
    define un middleware de caché (7 días, `immutable`) que no se usa en ninguna
    ruta. Quitarlo o decidir dónde aplicarlo (no en `/assets/*`, por lo del
    punto 8).

## Realtime

13. **Plato inhabilitado → mozos.** El administrador inhabilita un plato con
   `PUT /api/carta/:id` (`estado`). Los mozos dejan de verlo cuando recargan la
   carta (al abrir Carta o un pedido nuevo), pero no hay un evento SSE que lo
   avise al instante. Ideal: un evento `CARTA_ACTUALIZADA`; y que
   `GET /api/carta` no devuelva los inhabilitados a quien no sea administrador.

## Tickets (impresión)

14. **Imprimir la boleta de caja.** La comanda de cocina sí se imprime
   (`/api/v1/impresion/pedidos/:id/reimprimir`), pero no hay endpoint para
   imprimir la cuenta o la boleta (existe `FormatPrecuenta` en el servidor, sin
   ruta). El frontend ya muestra la boleta como ticket (48 columnas, blanco y
   negro, con logo, sede, número, resumen del pago, "SON", QR y pie) pero no
   puede imprimirla. Hace falta un endpoint que reciba o arme esos datos.

15. **Número de orden diario.** `ORDEN #0001` solo está en `print_jobs` y en
    `/impresion/cola`: pedimos que el detalle del pedido
    (`GET /api/v1/mozo/pedidos/:id`) incluya `orden` o `codigo_orden` para
    mostrar en pantalla el mismo número que sale en la comanda.

16. **Logo de los tickets.** `GET /api/v1/impresion/config` devuelve solo la ruta
    del logo y no entrega la imagen; el frontend guarda una copia local para
    mostrarlo. Si se puede, servir el logo (por ejemplo
    `GET /api/v1/impresion/config/logo`).

## Carta

17. **`POST` y `PUT /api/carta` no devuelven la categoría.** El `RETURNING` de
    `CreateCarta` y `UpdateCarta` (`catalog_repository.go`, ~líneas 958 y 1029)
    trae solo las columnas de `carta`, sin `categoria_comida_id`,
    `categoria_nombre` ni `subcategoria_nombre`; `GET /api/carta` y
    `GET /api/carta/:id` sí los traen por el JOIN. El frontend ya conserva la
    categoría que elige el usuario, pero conviene que la respuesta sea igual a
    la del `GET`. Además la carta guarda **una sola** `subcategoria_id` por
    plato: si el formulario permite elegir varias subcategorías, solo se
    guarda la primera (al recargar desde el servidor las demás desaparecen).

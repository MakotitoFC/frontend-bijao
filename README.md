# El El Bijao (frontend)

Sistema POS para el restaurante El Bijao: pedidos (mesa y delivery), mesas, cocina,
productos, caja, reportes, inventario y configuración.

Paquetes: `google_fonts`, `lucide_icons_flutter`, `fl_chart`, `file_picker`.

## Ejecutar

```bash
flutter pub get
flutter run -d chrome
```

Un hot reload no siempre recoge los cambios de estructura. Si algo no aparece,
reinicia la app con `R` (hot restart) o vuelve a lanzarla.

## Credenciales de prueba

Están en `lib/data/usuarios_store.dart` y son lo único con lo que se puede entrar hoy.

| Rol | Correo | Contraseña | Qué ve |
|---|---|---|---|
| Administrador | `admin@bijao.com` | `admin123` | Todo |
| Mesero | `mesero@bijao.com` | `mesero123` | Inicio, Pedidos, Productos |
| Trabajador (cocina) | `cocina@bijao.com` | `cocina123` | Inicio, Cocina |

El rol **Cajero** existe (`usuarios.rol`) pero no hay usuario de prueba. Se puede crear
desde Configuración → Usuarios y roles. Un cajero ve Inicio, Pedidos y Ventas
(Historial de pedidos y Caja).

El login valida contra la lista `usuarios` (correo + contraseña) y rechaza usuarios
inactivos. Tiene "Recordarme" (guarda el correo solo en memoria) y "¿Olvidaste tu
contraseña?" (solo muestra un aviso: contactar al administrador).

### Menú por rol

`lib/data/nav_items.dart` define el menú y los roles permitidos:

| Vista | Administrador | Mesero | Cajero | Trabajador |
|---|:-:|:-:|:-:|:-:|
| Inicio | ✔ | ✔ | ✔ | ✔ |
| Pedidos | ✔ | ✔ | ✔ | |
| Productos | ✔ | ✔ | | |
| Cocina | ✔ | | | ✔ |
| Ventas → Historial de pedidos, Caja | ✔ | | ✔ | |
| Ventas → Reportes | ✔ | | | |
| Finanzas (placeholder) | ✔ | | | |
| Inventario | ✔ | | | |
| Configuración | ✔ | | | |

En escritorio el menú es lateral (contraíble). En móvil (< breakpoint de
`AppBreakpoints`) pasa a una barra inferior con "Más". Quien no es administrador no
puede editar productos ni categorías.

## Estructura

```
lib/
  main.dart            Arranque (MaterialApp → LoginScreen)
  theme/               Colores, tamaños, radios y tema (app_theme.dart)
  models/              Clases de datos (reflejan tablas de la BD)
  data/                Stores en memoria  ← AQUÍ se conecta el backend
  screens/             Una pantalla por vista del menú
  widgets/             Diálogos y componentes reutilizables
  utils/               blur_dialog.dart (modal/hoja), agregados_utils.dart
```

## Cómo conectar el backend

Cada store es una lista o mapa global con funciones que la modifican (agregar,
actualizar, registrar…). Las pantallas leen esas listas y llaman esas funciones. La
idea es **mantener las firmas** y que las funciones hablen con la API (o que la API
cargue las listas al iniciar sesión y las funciones sigan escribiendo y sincronizando).
Los comentarios `TODO` de cada archivo marcan lo pendiente.

**Importante:** casi todos los stores arrancan **vacíos** (no hay datos de ejemplo).
Mientras no se carguen desde el backend, no habrá mesas, productos ni categorías, y no
se podrá armar un pedido. Los únicos datos fijos son: usuarios de prueba, una sede,
el horario (11:00–22:00 todos los días) y los medios de pago base (ver más abajo).

| Store (`lib/data`) | Tabla / concepto | Qué contiene |
|---|---|---|
| `usuarios_store.dart` | `usuarios` | Usuarios, rol, activo, sede. El login valida aquí. |
| `categorias_store.dart` | `categorias` | Categorías de la carta, con `orden`. |
| `cartas_store.dart` | `productos` | Platos y bebidas (`cartasNotifier`). |
| `presentaciones_store.dart` | `carta_presentacion` | Tamaños o envases por plato (vaso, botella…). |
| `subcategorias_store.dart` | `subcategoria` | Subcategorías de cada categoría (Segundo, Bebida, Snack…). Aún sin endpoint: en memoria. |
| `variantes_store.dart` | `carta_variante` | Tamaños con precio propio de un plato. Aún sin endpoint: en memoria. |
| `promociones_store.dart` | `promocion`, `promocion_componente`, `promocion_componente_opcion` | Promociones, sus componentes (por subcategoría) y opciones. Aún sin endpoint: en memoria. |
| `insumos_store.dart` | `carta_insumo`, `pedidos_detalle_insumo` | Receta por plato y consumo de insumos por línea. |
| `mesas_store.dart` | `mesa` | Mesas, zonas y mesas unidas (ver "Pendientes"). |
| `pedidos_store.dart` | `pedidos`, `pedidos_detalle` | Pedidos y sus líneas. |
| `pagos_store.dart` | `pago`, `pago_detalle` | Cobros, reparto por línea y reembolsos. |
| `incidencias_store.dart` | `pedidos_detalle_incidencia` (nueva) | Reclamos y devoluciones. |
| `creditos_store.dart` | `nota_credito`, `vale_consumo` (nuevas) | Documentos emitidos por devoluciones. |
| `cierres_store.dart` | `cierres_caja` | Cierres de caja y totales de la caja actual. |
| `inventario_store.dart` | `producto_inventario`, `inventario_movimiento` | Stock y movimientos. |
| `compras_store.dart` | `compra`, `compra_detalle` | Compras (reponen stock). |
| `utensilios_store.dart` | `utensilio_roto` | Menaje roto (descuenta stock como merma). |
| `catalogos_store.dart` | `unidad_producto`, `tipo_producto`, `tipo_seguimiento`, `tipo_movimiento` | Catálogos fijos. |
| `configuracion_store.dart` | `restaurantes`, `horarios`, `medio_pago` y ajustes | Configuración del negocio (ver abajo). |

### Configuración del negocio (`configuracion_store.dart`)

- `config`: servicios activos (local, delivery), `propinaSugerida` (%), precios de
  `tupperGrande` (2.00) y `tupperMediano` (1.50), descuento de empleado (habilitado y
  %), cargo por delivery (habilitado y monto).
- `negocio`: nombre, teléfono, correo, dirección, moneda, idioma, país, zona horaria.
- `sedes`: restaurantes (RUC, dirección, celular, activo).
- `horarios`: horario de atención por día.
- `mediosPago`: medios de pago editables. Si no hay ninguno activo, se usan los **base**:
  Efectivo (`mp1`), Yape (`mp2`), Tarjeta (`mp3`), Transferencia (`mp4`) y Puntos
  (`mp5`). Cada medio puede aplicar una comisión (%).

## Flujos de las vistas

### Login
Correo + contraseña → valida contra `usuarios` → entra al `HomeScreen` con la sede del
usuario.

### Inicio
Placeholder ("dashboard en construcción"). Finanzas es igual.

### Pedidos
Dos secciones: **cola de pedidos activos** a la izquierda y **detalle del pedido
elegido** a la derecha (en móvil, el detalle ocupa toda la pantalla con flecha para
volver). La cola se filtra por estado: Todos, Pendiente, Preparando, Listo, Entregado.
Los pedidos pagados, cancelados o anulados salen de la cola.

**Nuevo pedido:** botón "Nuevo Pedido" → elegir tipo (**Mesa** o **Delivery**).
- *Mesa:* se elige la mesa en el croquis (ver Mesas) y luego se arman los productos.
- *Delivery:* se capturan cliente, celular, dirección y notas, y se arman los productos.
- Productos: buscador, pestañas por categoría y tarjetas. Al tocar una abre las opciones
  (presentación, agregados, nota, cantidad). El carrito vive en el resumen de la derecha.
- Botones bajo el total: **Plato del día** (naranja), **Propina** (naranja) y **Tupper**
  (gris). Se puede activar el descuento de empleado si está habilitado.
- "Imprimir" solo muestra un aviso (no hay impresión real); "Confirmar pedido"
  registra el pedido (estado `pendiente`), ocupa la mesa y descuenta insumos según la
  receta de cada plato.

**Detalle del pedido** (panel derecho):
- Cabecera: número, mesa/delivery, hora, mesero, cliente y estado. Lápiz para editar
  cliente, celular, dirección y notas.
- Cada línea: casilla de "entregado" (la controla el mesero), quitar producto, cantidad
  (−/+), nota por producto e imprimir comanda del producto. Un producto con pagos
  registrados ya no se puede editar ni quitar.
- "Agregar producto" (desde la carta). Si el pedido estaba `listo` o `entregado`, vuelve
  a `pendiente` para que cocina lo prepare.
- Totales: subtotal, cargo por delivery, descuento de productos, **Descuento extra**,
  ajustes por devolución, propina, tupper, pagado, saldo pendiente y total.
- **Descuento extra** (lápiz): abre tickets de descuento: Cliente frecuente (10 %),
  Cortesía de la casa (15 %), Empleado (si está habilitado), S/ 5, S/ 10 y uno
  personalizado. Un ticket aplicado se puede quitar. No puede superar el saldo.
- **Plato del día:** elige entre los productos marcados con estrella naranja
  (`CartaItem.platoDelDia`) y lo agrega al pedido.
- **Promoción** (botón naranja, en Nuevo pedido y en el detalle): lista las promociones
  disponibles. La promoción llega armada con el producto incluido de cada hueco; el mozo
  no agrega nada. Si el cliente lo pide, usa **Cambiar** para reemplazar un producto por
  otra opción que el admin registró (queda con `es_cambio`). El precio es la suma de los
  componentes; con `se_mantiene` en falso, el producto cambiado se cobra a su precio normal.
  En una línea ya agregada, **Cambiar productos** reajusta el stock (devuelve lo del
  producto que sale y descuenta el nuevo).
- **Propina:** porcentajes sugeridos (5, 10, 15 y el sugerido de configuración) o monto
  libre. **Tupper:** grande o mediano, con cantidad y precio por unidad editable.
  Ninguno se puede editar si ya tiene pagos.
- Botones: **Imprimir** (boleta), **Devolución**, **Pagar** y **Pago compartido**.
  En *delivery* no hay Devolución ni Pago compartido.
- **Devolución ("Reportar problema")**: categoría, detalle, evidencia y resolución
  (ver "Reglas de negocio").
- **Pagar:** elige un medio de pago y cobra todo el saldo.
- **Pago compartido:** escenarios partes iguales, cada uno su plato, por categoría o
  por grupo; cada pagador puede usar varios métodos; puede generar una boleta por
  pagador.
- Cancelar el pedido lo marca `cancelado`, libera sus mesas y lo saca de cocina.

### Mesas (croquis)
Se ve dentro de "Nuevo pedido → Mesa". Cada **zona** es una sala; se cambia de zona con
el select. Tiene buscador (por número de mesa o cliente) y filtro por estado. Las mesas
libres/ocupadas se dibujan como en un croquis, con hora, monto y mesero si están
ocupadas.
- Crear, editar y eliminar **zonas** y **mesas** (nombre, sillas, zona).
- **Unir mesas:** botón naranja → elegir 2 o más mesas libres → "Unir". Las mesas unidas
  comparten la cuenta. Se pueden separar.

### Productos
Carta en tarjetas con pestañas por categoría. El administrador puede crear, editar,
activar/desactivar y eliminar productos y categorías (la edición de categoría es en
línea). Formulario del producto: nombre, descripción, imagen, categoría, precio, costo,
stock, SKU, límite de agregados, **extras sueltos y grupos de extras** y la marca
**Plato del día** (estrella naranja en la tarjeta), **subcategoría** (se elige tras la
categoría) y **tamaños con precio propio** (`carta_variante`: nombre, precio público y
personal, peso mín./máx. opcional). Las subcategorías se administran desde el diálogo de
categorías (botón de cada fila). El mesero solo consulta.

### Cocina
Una tarjeta (ticket) por pedido, con filtro por estado. El color de la cabecera indica
el estado: oscuro (pendiente), naranja (preparando), verde (listo). Botón de avance:
**Iniciar → Marcar listo → Entregado**. Muestra productos por categoría con opciones y
notas en rojo, e incidencias resaltadas. Si un plato lleva insumos porcionados, permite
registrar la cantidad usada.

### Ventas → Historial de pedidos
Tabla de pedidos con búsqueda y filtro (Todos, Pagados, Por cobrar). El estado de pago
es: Pagado, Parcial, Por cobrar o Cancelado. "Cobrar" abre el **mismo detalle de
Pedidos** en un modal y se cierra solo cuando el pedido queda pagado o cancelado.

### Ventas → Caja
Muestra la caja actual: pagos desde el último cierre, por medio de pago. "Cerrar caja"
pide monto inicial y lo declarado en efectivo, tarjeta y digital, y guarda el cierre
con las diferencias. Lista los cierres anteriores.

### Ventas → Reportes
Progreso de pedidos por tipo de servicio (En mesa y A domicilio), rendimiento de
meseros, horas y días con más ventas y métodos de pago, con comparación contra el
periodo anterior. Solo administrador.

### Inventario
Tres pestañas: **Productos** (resumen de total, stock bajo y sin stock, y movimientos), **Compras** (registrar una
compra repone el stock) y **Utensilios rotos** (descuenta stock como merma).

### Configuración
Pestañas: **Servicio** (servicios activos, propina sugerida, descuento de empleado y
cargo por delivery), **Restaurantes**, **Métodos de pago** (activar y comisión; siempre
debe quedar al menos uno activo), **Usuarios y roles** (crear, cambiar rol, activar) y
**Negocio**, y **Promociones** (solo administrador):

- Cada **promoción** es un acordeón con nombre, descripción, descuento % opcional
  (`porcentaje_descuento`), vigencia, activa y `se_mantiene` (si al hacer un cambio se
  conserva el precio de promoción o el producto cambiado se cobra a su precio normal).
- Sus **componentes** son los huecos del combo, definidos por una subcategoría y una
  cantidad (ej. 1 Segundo, 1 Bebida).
- Cada componente tiene **opciones**: los productos permitidos (con su presentación si es
  bebida) y su precio de promoción (`precio`; vacío = precio normal con el descuento de la
  promoción). El producto **incluido** es la primera opción activa (el admin puede
  "Hacer incluida" a otra); las demás son los cambios posibles.
- Una promoción solo llega al mozo si está activa, vigente y todos sus componentes tienen
  al menos una opción activa.

## Reglas de negocio que el backend debe respetar

### Estados del pedido (`pedidos.estado`)
`pendiente` → `preparando` → `listo` → `entregado`. Además:
- `pagado`: cuando la suma de pagos cubre el total (lo hace `cerrarSiSaldado`). Libera
  las mesas del pedido y las separa si estaban unidas.
- `cancelado` y `anulado`: salen de la cola y de cocina. `anulado` existe en el modelo
  pero hoy ninguna pantalla lo asigna.
- Agregar un producto a un pedido `listo` o `entregado` lo regresa a `pendiente`.

### Pedido (`Pedido`)
`id`, `numeroPedido` (correlativo), `mesaNumero` (0 = delivery), `mesasUnidas`,
`estado`, `tipoPedido` (`mesa` | `delivery`), `fechaPedido`, `notas`, `clienteNombre`,
`clienteCelular`, `direccionDelivery`, `fechaFinalizacion`, `usuarioId` (mesero).

### Líneas del pedido (`PedidoLine`)
Una línea es un producto **o** un ajuste. El total del pedido es la **suma de
`precioTotalLinea` de todas sus líneas** (los ajustes pueden ser negativos). Las líneas
que no son productos usan un `cartaId` especial y no se muestran en Cocina:

| `cartaId` | Nombre de la línea | Monto |
|---|---|---|
| `cargo-delivery` | "Cargo por delivery" | positivo |
| `ajuste-manual` | `Descuento: <nombre>` | negativo |
| `ajuste-manual` | `Propina: mesero` | positivo |
| `ajuste-manual` | `Tupper: Grande` / `Tupper: Mediano` (cantidad × precio) | positivo |
| `ajuste-manual` | `Reembolso: …`, `Cambio de producto: …`, `Nota de crédito: …` | negativo |

Los prefijos están en `pedidos_store.dart`. Si en BD se modelan distinto (por ejemplo
una tabla de ajustes), hay que conservar el cálculo del total y del saldo.

### Pagos
- `registrarPago` crea un `Pago` (monto abonado, comisión del medio, monto cobrado,
  propina, pagador) y lo **reparte entre las líneas con saldo pendiente**, en orden
  (`pago_detalle`). Soporta pagos parciales y divididos.
- Saldo = suma de (`precioTotalLinea` − pagado de la línea). Si llega a 0, el pedido
  pasa a `pagado`.
- Un **reembolso** es un `Pago` con monto **negativo**, aplicado a la línea de ajuste.
- La comisión de un medio de pago se descuenta del monto cobrado (`aplicaComision`,
  `porcentajeComision`).
- El pago compartido registra un `Pago` por pagador y por método.

### Devoluciones (`Incidencia`)
Se reporta sobre una línea de producto: categoría, detalle, evidencia y resolución.
La línea queda marcada con estado `incidencia`.
- `reembolso`: devuelve dinero por un medio de pago (pago negativo) y agrega un ajuste.
- `cambio`: entrega otro producto; si cambia el precio, ajusta la diferencia.
- `nota_credito`: emite una nota `NC-0001…` (concepto, monto, saldo a favor).
- `vale`: emite un vale de consumo `VC-0001…` con vigencia de 30 días.
- `rechazado`: no cambia nada.

### Mesas
- `estado`: `libre` u `ocupada`. Se ocupa al confirmar un pedido y se libera al pagar o
  cancelar.
- Una mesa unida comparte el pedido con las del grupo (`mesasUnidas`).

### Inventario
- Confirmar un pedido descuenta el stock según la receta del plato (`carta_insumo`).
  Los insumos porcionados los registra cocina a mano.
- Comprar repone stock; un utensilio roto descuenta stock como merma.

### Cierre de caja
Los totales de la caja actual suman los pagos desde el último cierre, por medio
(efectivo, tarjeta, yape, plin) y delivery. Al cerrar se comparan con lo declarado y se
guardan las diferencias.

## Pendientes y cosas a definir con backend

- **Zonas de mesa:** hoy `zonasMesas` es solo una lista en memoria (la zona viaja en
  `Mesa.zona`). Falta definir si es tabla propia o campo de `mesa`.
- **Producto:** falta el campo booleano `plato_del_dia` y las imágenes (`imagen_url`;
  hoy se guardan en memoria como bytes).
- **Tuppers:** los precios (grande y mediano) están en `config`; definir dónde se
  guardan.
- **Incidencias, notas de crédito y vales:** no existen en la BD todavía.
- **Pago:** el campo `pagador` (pago compartido) no existe todavía en `pago`.
- **Boletas:** la boleta y la comanda son vistas en pantalla; no hay impresión real ni
  comprobante electrónico.
- **Autenticación:** el login compara contra una lista local; falta sesión real,
  contraseñas con hash y "Recordarme" persistente.
- **Finanzas e Inicio:** placeholders sin contenido.
- Los pedidos de tipo `llevar` ("para llevar") ya no existen; solo `mesa` y `delivery`.

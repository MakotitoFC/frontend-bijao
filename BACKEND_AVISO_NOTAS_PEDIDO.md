# Backend: avisar a los demás equipos cuando se cambian las notas de un pedido

Documento solo de explicación. No incluye cambios aplicados; sirve para que quien
mantiene el backend haga el cambio.

## Para qué

La app guarda la **propina** de un pedido dentro de sus notas (`pedidos.comentarios`),
en una línea `Propina: 4.00`. Así el mozo la anota en su celular y caja la ve al
cobrar en otro equipo.

Hoy, cuando alguien cambia las notas de un pedido, el servidor **no avisa** al resto
de equipos conectados. Los demás equipos se enteran recién en su siguiente consulta
de respaldo, que con la conexión en vivo activa ocurre cada **~32 segundos** (cada 4
segundos si no hay conexión en vivo). Por eso la propina tarda unos 20 a 30 segundos
en aparecer en la pantalla de otro equipo.

Otras acciones sí avisan al instante (por ejemplo, marcar un plato como servido).
Basta con que cambiar las notas también lo haga.

## Dónde está

Archivo: `internal/services/pedido_mozo_service.go`.
Función: `UpdateComentarioPedido` (ruta `PATCH /api/v1/mozo/pedidos/:id/comentarios`).

Hoy solo valida y devuelve el resultado del repositorio:

```go
func (s *PedidoMozoService) UpdateComentarioPedido(ctx context.Context, sedeID, usuarioID, pedidoID uuid.UUID, req dto.UpdateComentarioPedidoRequest) (*dto.PedidoMozoDetalleDTO, error) {
	if sedeID == uuid.Nil || pedidoID == uuid.Nil {
		return nil, errors.New("identificadores inválidos")
	}
	return s.repo.UpdateComentarioPedido(ctx, sedeID, usuarioID, pedidoID, req.Comentarios, req.Version)
}
```

## Qué agregar

Guardar el resultado y, si no hubo error, emitir el evento `PEDIDO_ACTUALIZADO` a la
sede, igual que hacen otras funciones del mismo archivo (por ejemplo
`UpdateItemFila`, línea ~151):

```go
res, err := s.repo.UpdateComentarioPedido(ctx, sedeID, usuarioID, pedidoID, req.Comentarios, req.Version)
if err == nil && res != nil && s.hub != nil {
	s.hub.BroadcastToSede(sedeID, "PEDIDO_ACTUALIZADO", res)
}
return res, err
```

Con eso, el resto de la función queda igual.

## Por qué ese evento y no otro

- La app ya entiende `PEDIDO_ACTUALIZADO`: al recibirlo vuelve a leer los pedidos
  (ver `traducirEvento` en `lib/services/eventos_service.dart`). **No hace falta
  ningún cambio en la app.**
- No hace falta emitir `STOCK_ACTUALIZADO` ni `CARTA_ACTUALIZADA`: cambiar las notas
  no afecta el stock ni la carta.
- El cuerpo del evento (`res`) es el mismo detalle de pedido que ya emiten las demás
  funciones.

## Cómo comprobarlo

1. Abrir la app en dos equipos con la sesión de la misma sede: el celular del mozo y
   la PC de caja, con la vista Pedidos abierta en caja.
2. En el celular, abrir un pedido propio y poner o cambiar la propina (botón de
   propina del detalle).
3. Antes del cambio: en la PC de caja la propina aparece unos 20 a 30 segundos
   después. Después del cambio: aparece en unos 1 o 2 segundos.

## Lo que no cambia

- Permisos: sigue pudiendo cambiar las notas solo el mozo que creó el pedido o el
  administrador (regla que ya está en el repositorio).
- La app sigue funcionando igual si el servidor no emite el evento: solo se demora
  más en actualizar.

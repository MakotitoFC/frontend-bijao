# Backend: cobro de S/ 0.00 solo para consumo de familia

## Síntoma

En el detalle de un pedido de familia (descuento 100 %, total S/ 0.00), el botón
**Cerrar cuenta** emite el ticket de venta en cero, pero el pedido no queda
cobrado: sigue como `servido` y la app solo lo quita de la cola en ese
dispositivo. En Ventas no figura como pagado.

## Causa (revisado en el backend)

`RegistrarPago` (`internal/services/caja_service.go`) rechaza cualquier cobro en
cero:

```go
if req.MontoAbonado.IsZero() {
    return nil, errors.New("el monto abonado no puede ser 0")
}
```

Por la ruta del mozo (`CambiarEstadoPedidoMozo`) solo se puede pasar a
`pendiente` o `servido`, así que tampoco hay otra forma de cerrar el pedido.

## Qué se pide

**No quitar el bloqueo.** Admitir un pago de S/ 0.00 **solo** en el consumo de
familia. Todo otro cobro en cero se sigue rechazando con el mismo mensaje.

### Cómo reconocer una cuenta de familia

La app, al crear un pedido de familia, le aplica un descuento del 100 % con el
motivo `Cuenta cero`. Queda guardado en `descuento_aplicado.motivo`.

Regla: un cobro con `monto_abonado = 0` se acepta únicamente si se cumplen las
dos condiciones:

1. El total del pedido es cero (detalles activos menos descuentos, más delivery
   y cargos extra; el mismo cálculo de `RegistrarPagoTx`).
2. El pedido tiene al menos un registro en `descuento_aplicado` con
   `lower(motivo) = 'cuenta cero'`.

Si alguna falla, se responde el mismo error de hoy:
`el monto abonado no puede ser 0`.

### Dónde cambiarlo

- `caja_service.go` → `RegistrarPago`: quitar la validación de monto cero de
  esta capa (o dejarla solo para montos que no vengan de este caso).
- `caja_repository.go` → `RegistrarPagoTx`: ya conoce `pedidoTotal` y el pedido.
  Si `req.MontoAbonado.IsZero()`, comprobar las dos condiciones de arriba antes
  de continuar. Con monto cero las validaciones de sobrecobro y reembolso no
  aplican, y el saldo queda en `0`, por lo que el código existente ya marca el
  pedido como `pagado` y sube su versión.

## Qué debe quedar registrado

- **Ventas:** el pedido figura como `pagado`, con un pago de S/ 0.00 (en la app
  se ve como "Consumo de familia").
- **Caja:** el pago se guarda con la apertura de caja activa, así que sale en la
  lista de cobros del turno con S/ 0.00 y en efectivo. No suma ni resta al
  efectivo esperado ni a los totales, porque su monto es cero.
- **Mesa:** al quedar `pagado`, se libera como cualquier pedido cobrado.

## Pruebas pedidas

1. Pedido de familia (descuento "Cuenta cero", total 0): el cobro con monto 0
   se registra y el pedido queda `pagado`.
2. Pedido con total mayor a cero y monto 0: sigue rechazado.
3. Pedido con total cero **sin** descuento "Cuenta cero": sigue rechazado.
4. Con la caja cerrada: sigue rechazado ("la caja se encuentra cerrada").
5. Intentar cobrar otra vez un pedido de familia ya `pagado`: rechazado.
6. Pantalla de Caja y cierre de caja con un cobro en cero en el turno: no se
   rompen y los totales no cambian.
7. Ticket de venta del pedido en cero: se emite sin error (la app lo emite antes
   del cobro).

## Mientras tanto en la app

Si el servidor rechaza el cobro en cero, la app oculta la cuenta cerrada en ese
dispositivo (el ticket sí queda registrado). Cuando el backend acepte el cobro,
ese respaldo deja de usarse y no hay nada que cambiar en el frontend.

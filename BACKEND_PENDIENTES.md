# Pendientes del backend

1. **URGENTE:** no se puede registrar ningún cobro (`POST /api/pagos`).
2. El seed no trae métodos de pago ni categorías de movimiento.

---

# 1. URGENTE: `POST /api/pagos` falla con "unexpected Parse response (D) DataRow"

## Síntoma

Al cobrar un pedido, la app muestra:

> No se pudo registrar el cobro: error auto-guardando pago_detalle: pq: unexpected Parse response "(D) DataRow"

No queda ningún pago registrado, así que tampoco se pueden cerrar pedidos ni emitir comprobantes.

## Causa

En `internal/repositories/caja_repository.go`, función de registrar pago, rama "Auto-repartir entre líneas con saldo pendiente" (líneas ~668 a ~728):

```go
rowsLineas, err := tx.QueryContext(ctx, queryLineas, req.PedidoID)
...
defer rowsLineas.Close()
for rowsLineas.Next() {
    ...
    tx.ExecContext(ctx, queryDet, pagoID, detID, aplicado, 1)   // INSERT INTO pago_detalle
}
```

Se ejecuta un `INSERT` en la misma transacción mientras `rowsLineas` sigue abierto. `lib/pq` no permite otra instrucción sobre la misma conexión con un resultado a medio leer, y responde con ese error de protocolo.

## Qué se pide

Leer primero todas las líneas a una lista, cerrar `rowsLineas` (sin esperar al `defer`) y recién después recorrer la lista haciendo los `INSERT INTO pago_detalle`:

```go
type lineaPago struct {
    id          uuid.UUID
    totalLinea  decimal.Decimal
    pagado      decimal.Decimal
    nombrePlato string
}
var lineas []lineaPago
for rowsLineas.Next() { ...Scan...; lineas = append(lineas, l) }
rowsLineas.Close()
if err := rowsLineas.Err(); err != nil { return err }
for _, l := range lineas { ...cálculo...; tx.ExecContext(...INSERT...) }
```

Conviene revisar si el mismo patrón (un `Exec` o `QueryRow` dentro de un `rows.Next()` de la misma transacción) existe en otros repositorios.

## Cómo probarlo

Cobrar un pedido sin enviar `detalles` (cobro de toda la cuenta) y también un cobro parcial: debe devolver 201 con el pago y sus `pago_detalle`.

---

# 2. El seed no trae `medio_pago` ni `categoria_movimiento`

`migrations/00002_seed_initial_data.sql` no inserta métodos de pago. En una base creada desde cero la app no tiene con qué cobrar: usa métodos locales de respaldo (con ids que no son UUID) y el cobro no llega al servidor. Lo mismo ocurre con las categorías de movimiento de caja.

Se pide incluir en el seed, como mínimo, los métodos Efectivo, Yape y Tarjeta (con su comisión) y las categorías de movimiento básicas, con `ON CONFLICT DO NOTHING`.

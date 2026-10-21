# Pendientes del backend

1. El seed no trae métodos de pago ni categorías de movimiento.

---

# 1. El seed no trae `medio_pago` ni `categoria_movimiento`

`migrations/00002_seed_initial_data.sql` no inserta métodos de pago ni categorías de movimiento de caja. En una base creada desde cero la app no tiene con qué cobrar ni cómo registrar ingresos y salidas: no hay métodos de pago en el servidor y hay que cargarlos a mano.

## Qué se pide

Incluir en el seed, con `ON CONFLICT DO NOTHING`:

- Métodos de pago como mínimo: Efectivo, Yape y Tarjeta (con su porcentaje de comisión).
- Categorías de movimiento básicas de caja (por ejemplo, las de ingreso por venta y las de salidas más comunes).

## Cómo probarlo

Crear una base nueva con `go run ./cmd/migrate`, iniciar sesión en la app y cobrar un pedido sin haber cargado nada a mano.

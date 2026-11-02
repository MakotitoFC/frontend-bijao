# Backend: aviso de actualización del APK

La app Android (APK) pregunta al servidor cuál es la última versión. Si es
mayor que la instalada, avisa al empleado y le deja descargar el APK desde el
mismo servidor, por el Wi‑Fi local. Se instala encima de la versión actual, sin
desinstalar. Solo aplica al APK de Android: la web y los iPhone (PWA) se
actualizan al recargar la página y no usan esto.

El frontend ya está hecho (`lib/services/actualizacion_service.dart`,
`lib/widgets/aviso_actualizacion.dart`). Falta lo siguiente en el backend.

## 1. `GET /api/v1/app/version`

- **Sin autenticación** (la app lo consulta al abrir, y no debe bloquear el
  login si falla).
- Responde `200` con JSON:

```json
{
  "android": {
    "version_code": 3,
    "version_name": "1.0.2",
    "url": "/api/v1/app/apk",
    "obligatoria": false,
    "notas": "Mejoras en el registro de pedidos."
  }
}
```

| Campo | Tipo | Descripción |
|---|---|---|
| `version_code` | entero | El número después del `+` en `pubspec.yaml` (ej. `1.0.2+3` → `3`). La app avisa solo si es **mayor** que el instalado. |
| `version_name` | texto | Lo que va antes del `+` (ej. `1.0.2`). Solo se muestra. |
| `url` | texto | Ruta relativa (`/api/v1/app/apk`) o URL completa donde se descarga el APK. La app la completa con la dirección del servidor. |
| `obligatoria` | booleano | Si es `true`, el aviso no tiene botón "Más tarde". |
| `notas` | texto, opcional | Qué cambió. |

- Si no hay APK publicado, responder `404` (o un JSON sin `android`): la app
  simplemente no avisa.

## 2. `GET /api/v1/app/apk`

- **Sin autenticación**: la descarga la hace el navegador del celular, que no
  lleva el token.
- Responde el archivo `.apk` con:
  - `Content-Type: application/vnd.android.package-archive`
  - `Content-Disposition: attachment; filename="bijao.apk"`
  - `Content-Length` correcto, para que se vea el progreso de descarga.
- Debe servir el archivo en streaming (por ejemplo `http.ServeFile`), sin
  cargarlo entero en memoria.

## 3. De dónde salen los datos

Opción simple, sin base de datos: una carpeta junto al ejecutable, por ejemplo
`apk/`, con dos archivos que se reemplazan al publicar una versión:

```
apk/
  bijao.apk
  version.json     { "version_code": 3, "version_name": "1.0.2",
                     "obligatoria": false, "notas": "..." }
```

- `GET /api/v1/app/version` lee `version.json` y le agrega la `url`.
- `GET /api/v1/app/apk` sirve `apk/bijao.apk`.
- Publicar una versión nueva = copiar el APK y editar `version.json`, sin
  reiniciar el backend (leer el archivo en cada consulta, o recargarlo si
  cambia).

## 4. Seguridad

- Solo exponer estas dos rutas; no servir toda la carpeta.
- Son públicas, pero el servidor corre en red local, no en internet. El APK no
  lleva secretos.
- La firma del APK es la que garantiza que solo se instala una actualización
  legítima: Android rechaza un APK firmado con otra clave.

## 5. Cómo se publica una versión nueva (procedimiento)

1. En el frontend: subir `version` en `pubspec.yaml` (ej. `1.0.2+3`), compilar
   con `flutter build apk --release`.
2. Copiar `app-release.apk` a `apk/bijao.apk` en el servidor.
3. Editar `apk/version.json` con el mismo `version_code` (`3`) y `version_name`.
4. Los celulares con una versión menor verán el aviso al abrir la app.

## 6. Pruebas

- `GET /api/v1/app/version` sin token devuelve `200` y el JSON anterior.
- `GET /api/v1/app/apk` descarga el archivo completo; en el celular, abrir
  `http://IP_DEL_SERVIDOR:6050/api/v1/app/apk` en el navegador debe bajar el
  APK.
- Con `version_code` igual o menor al instalado, la app no muestra nada.
- Sin `apk/bijao.apk` o sin `version.json`, `/version` responde `404` y la app
  sigue funcionando normal.

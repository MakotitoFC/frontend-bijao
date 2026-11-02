# Procedimiento: generar y actualizar el APK

El APK se compila en la **PC de desarrollo** (la que tiene Flutter y el Android
SDK). La laptop del cliente es solo el servidor (backend en Go + carpeta `web\`
para los iPhone). Lo que permite actualizar sin desinstalar es que **todos los
APK se firmen con la misma clave**, sin importar en qué PC se compilen.

> Estado actual del proyecto: el build `release` se firma con la clave de debug
> (`android/app/build.gradle.kts`) y la versión está fija en `1.0.0+1`. Por eso
> hoy hay que desinstalar e instalar. Los pasos 1 y 2 lo corrigen; todavía no
> están aplicados en el código.

---

## 1. Crear la clave de firma (una sola vez)

```bash
keytool -genkey -v -keystore bijao-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias bijao
```

- Guardar `bijao-release.jks` y su contraseña en **al menos dos lugares**
  (USB y nube privada).
- **No subirla a git** (agregar `*.jks` y `key.properties` al `.gitignore`).
- Si se pierde, los celulares ya instalados no podrán actualizarse y habrá que
  desinstalar la app en todos.

## 2. Configurar el proyecto para usarla (pendiente de aplicar)

Crear `android/key.properties` (no se sube a git):

```properties
storePassword=LA_CONTRASEÑA
keyPassword=LA_CONTRASEÑA
keyAlias=bijao
storeFile=C:/ruta/segura/bijao-release.jks
```

Y en `android/app/build.gradle.kts`, reemplazar la firma de debug del bloque
`release` por una `signingConfig` que lea ese archivo.

## 3. Cada versión nueva

1. Subir la versión en `pubspec.yaml`. El número después del `+` debe aumentar
   siempre:
   ```yaml
   version: 1.0.1+2
   ```
2. Compilar:
   ```bash
   flutter build apk --release --dart-define-from-file=.env
   ```
3. El archivo queda en:
   `build/app/outputs/flutter-apk/app-release.apk`

## 4. Entregarlo a los empleados

- **Primera instalación:** pasar el APK por WhatsApp, USB o enlace. El celular
  pedirá permitir "instalar apps desconocidas".
- **Siguientes versiones:** instalar el APK nuevo **encima**, sin desinstalar.
  Funciona solo si tiene la misma firma y un número de versión mayor.
- Más adelante (aún no implementado): el servidor guardará el APK y la app
  avisará de la nueva versión con un botón para actualizar.

## 5. Versión web (iPhone, iPad, PC)

Los iPhone usan la PWA, que se sirve desde el servidor y no se reinstala:

```bash
flutter build web
```

Copiar el resultado de `build/web` a la carpeta `web\` del servidor. Los
dispositivos la reciben al recargar la página.

## 6. En la laptop nueva del cliente

- Instalar solo el backend y la carpeta `web\`, según el manual de instalación.
- El APK encuentra el servidor solo (señal UDP, puerto 8989). Requisitos:
  celulares en el mismo Wi‑Fi y el cortafuegos de Windows permitiendo los
  puertos **6050 (TCP)** y **8989 (UDP)**.
- No hace falta compilar nada en esa laptop.

## 7. Si se cambia de PC de desarrollo

Copiar a la PC nueva `bijao-release.jks` y `android/key.properties`. Con eso las
actualizaciones siguen funcionando.

## Lista para probar la actualización sin desinstalar

1. Compilar e instalar la versión `1.0.1+2` firmada con la clave propia.
2. Cambiar algo visible, subir a `1.0.2+3`, compilar de nuevo.
3. Instalar el APK nuevo encima: debe conservar la sesión y los datos.
4. Repetir la prueba compilando desde otra PC con la misma clave.

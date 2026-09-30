# 8. Publicación en tiendas

Estado de la configuración de plataforma y lo que falta hacer a mano. Complementa
la sección B de [07-auditoria.md](07-auditoria.md).

## Identificadores

| Plataforma | Valor |
|---|---|
| Android `applicationId` / `namespace` | `es.previa.app` |
| iOS bundle id | `es.previa.app` (tests: `es.previa.app.RunnerTests`) |
| Nombre visible | Previa |
| Versión | `version:` de `pubspec.yaml` (`1.0.0+1`; el número tras `+` debe subir en cada subida a tienda) |

> **Decisión antes de publicar:** `es.previa.app` es un valor razonable pero no se
> ha comprobado que esté libre. El id es **definitivo** una vez publicada la app.
> Para cambiarlo: `android/app/build.gradle.kts` (namespace y applicationId), mover
> `android/app/src/main/kotlin/es/previa/app/MainActivity.kt` y su `package`, y las
> entradas `PRODUCT_BUNDLE_IDENTIFIER` de `ios/Runner.xcodeproj/project.pbxproj`.

## Firma de release de Android

`android/app/build.gradle.kts` lee `android/key.properties` (ignorado por git, igual
que `*.jks` y `*.keystore`). Sin ese fichero el build release usa la clave debug:
sirve para probar en local, **pero Google Play lo rechaza**.

1. Genera el keystore de subida (una sola vez, en un sitio fuera del repositorio):

   ```powershell
   keytool -genkey -v -keystore $env:USERPROFILE\upload-keystore.jks `
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   (`keytool` viene con el JDK; con Android Studio está en `jbr\bin`.)
2. Copia `android/key.properties.example` a `android/key.properties` y rellénalo
   (`storeFile` es relativo a `android/app/`, o usa una ruta absoluta).
3. Construye el paquete: `flutter build appbundle --release` →
   `build/app/outputs/bundle/release/app-release.aab`.
4. Activa **Play App Signing** al crear la app en Play Console: Google custodia la
   clave de firma real y tu keystore es solo la clave de *subida* (se puede
   restablecer si la pierdes).
5. **Haz copia del keystore y de sus contraseñas fuera del equipo** (gestor de
   contraseñas + otro disco). Nunca lo subas a git.

## Iconos y splash

- Fuente: `assets/images/icon.png` (1024x1024, círculo `#7C4DFF` sobre `#0B0B12`),
  `icon_foreground.png` (capa adaptativa y monocroma) y `splash.png`. Se regeneran
  con `powershell -ExecutionPolicy Bypass -File tool/generar_icono.ps1`.
- Generadores (config al final de `pubspec.yaml`):
  `dart run flutter_launcher_icons` y `dart run flutter_native_splash:create`.
- Es un icono provisional y sencillo: sustitúyelo por el logo definitivo repitiendo
  esos comandos.

## Permisos

- Android: solo `INTERNET` y `ACCESS_COARSE_LOCATION`. El manifest principal elimina
  explícitamente (`tools:node="remove"`) ubicación precisa, ubicación en segundo plano
  y almacenamiento, por si un plugin los añadiera al fusionar. Las fotos de perfil
  usan el selector del sistema (sin permiso). Los plugins actuales (`geolocator_android`
  4.6.2, `image_picker_android`) no declaran permisos propios. No se pudo generar el
  manifest fusionado en esta máquina (no hay Android SDK): tras el primer build,
  revisa `build/app/intermediates/merged_manifests/release/` y confirma que solo
  aparecen esos dos permisos.
- iOS: `NSLocationWhenInUseUsageDescription` y `NSPhotoLibraryUsageDescription`
  en `Info.plist`; `ITSAppUsesNonExemptEncryption = false` (solo HTTPS estándar).
- Si se añaden notificaciones push (FCM), hará falta `POST_NOTIFICATIONS` en Android
  y la capacidad Push en iOS, y actualizar los cuestionarios de privacidad.

## Privacidad de iOS

`ios/Runner/PrivacyInfo.xcprivacy` declara: sin seguimiento; datos recogidos y
vinculados al usuario para funcionalidad de la app (correo, nombre, ubicación
aproximada, fotos, identificador de usuario, contenido del usuario) y uso de
`UserDefaults` (razón CA92.1). Si añades SDKs de terceros (analítica, FCM...),
revisa el manifiesto y los de cada SDK.

## Páginas legales públicas

`web/privacidad.html` y `web/condiciones.html` se publican junto con la web
(`flutter build web` las copia a `build/web/`). URL para las tiendas, p. ej.
`https://TU-DOMINIO/privacidad.html` y `https://TU-DOMINIO/condiciones.html`.
La sección 7 de la privacidad (`#eliminar-cuenta`) sirve como URL de
"solicitud de eliminación de datos" que pide Google Play:
`https://TU-DOMINIO/privacidad.html#eliminar-cuenta`.

**Antes de publicar, rellena los marcadores amarillos `[...]`** de ambos ficheros
(nombre, NIF, dirección, email de contacto, fecha, región de Supabase, plazos de
conservación, ciudad). Busca con `grep -n "pend" web/*.html`. Si en Vercel la web
reescribe todas las rutas a `index.html`, comprueba que `/privacidad.html` se sirve
como fichero estático (los ficheros existentes tienen prioridad sobre las reescrituras).

## Checklist

### Ya hecho en el repositorio
- [x] Application id / bundle id propios (`es.previa.app`) y nombre visible "Previa"
- [x] Firma de release configurada por `key.properties` + plantilla
- [x] Icono (incluido adaptativo y monocromo de Android; iOS sin alfa) y splash oscuro
- [x] Permisos Android mínimos; textos de permisos iOS; `ITSAppUsesNonExemptEncryption`
- [x] `PrivacyInfo.xcprivacy`
- [x] `web/index.html` y `manifest.json` con nombre, descripción y colores de marca
- [x] Páginas de privacidad y condiciones (con marcadores por rellenar)
- [x] Borrado de cuenta dentro de la app y exportación de datos

### Pendiente en el código (auditoría, fuera de esta tarea)
- [ ] Enlazar privacidad y condiciones desde el registro, la bienvenida y Ajustes (B3)
- [ ] Versión visible en Ajustes leída de `package_info_plus` (B1)
- [ ] `isMinifyEnabled`/`isShrinkResources` y reglas R8, si se quiere reducir tamaño
- [ ] Comprobar que `targetSdk` cumple el requisito vigente de Google Play
- [ ] Decidir el proyecto Supabase dedicado (B5) y empaquetado de `.env` (B4)

### Lo que exige la tienda y solo puedes hacer tú
**Cuentas**
- [ ] Google Play Console: pago único de 25 USD, verificación de identidad. Las cuentas
      personales nuevas deben hacer una prueba cerrada (12 testers durante 14 días)
      antes de producción: comprueba el requisito vigente.
- [ ] Apple Developer Program: 99 USD/año y un Mac con Xcode para compilar y subir iOS
      (o un servicio de CI con macOS).
- [ ] Dominio/hosting donde publicar la web y las páginas legales; email de soporte.

**Ficha (ambas tiendas)**
- [ ] Nombre, descripción corta (80 car.) y larga, categoría (Social), email de contacto
- [ ] URL de política de privacidad (obligatoria) y de soporte
- [ ] Capturas: móvil (mín. 2 en Play; iPhone 6,9" y 6,5" en Apple), y en Play gráfico
      de funciones 1024x500. Icono 512x512 para Play (exporta `assets/images/icon.png`)
- [ ] Clasificación por edad: contenido relacionado con alcohol y usuarios que se
      conocen; se declara 18+ / Apple 17+ o la mayor disponible
- [ ] Declarar público objetivo solo adultos (no "familias")
- [ ] Credenciales de una cuenta de prueba para los revisores (sin ellas, rechazo)

**Google Play: "Seguridad de los datos"** (alinear con la política de privacidad)
- [ ] Datos recogidos: correo, nombre, ubicación aproximada, fotos, ID de usuario,
      mensajes y contenido del usuario, fecha de nacimiento (información personal)
- [ ] Finalidad: funcionalidad de la app y gestión de la cuenta; sin publicidad ni
      análisis; sin venta de datos
- [ ] Cifrado en tránsito: sí. Posibilidad de pedir la eliminación: sí (en app y por URL)
- [ ] Ubicación: aproximada, no compartida con terceros salvo el proveedor del backend
- [ ] Declaración de permisos de ubicación (solo aproximada, primer plano)
- [ ] Declaración de contenido generado por usuarios (reporte, bloqueo y moderación)

**Apple: etiquetas de privacidad (App Privacy) y revisión**
- [ ] Mismas categorías que `PrivacyInfo.xcprivacy`: todas "vinculadas al usuario",
      sin seguimiento, finalidad "funcionalidad de la app"
- [ ] Cumplir la guía 1.2 (contenido generado por usuarios): filtro o reporte,
      bloqueo y contacto publicado (ya hay reporte y bloqueo; añade email de soporte)
- [ ] Guía 5.1.1(v): borrado de cuenta dentro de la app (hecho)
- [ ] Si usas Google Sign-In, cumplir la guía 4.8 (ofrecer también inicio con Apple
      o un servicio equivalente de privacidad) o revisar si aplica
- [ ] Exportación de cumplimiento de cifrado: ya declarado en `Info.plist`
- [ ] Equipo de desarrollo y perfiles de aprovisionamiento configurados en Xcode

**Antes de subir**
- [ ] Rellenar marcadores de `web/privacidad.html` y `web/condiciones.html` y publicarlas
- [ ] Generar keystore, `key.properties` y `flutter build appbundle --release`
- [ ] Probar el `.aab`/`.ipa` en un dispositivo real (ubicación, mapa, fotos, borrado)

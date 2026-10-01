# 7. Auditoría de accesibilidad y preparación para publicar

Auditoría de solo lectura sobre `lib/`, `android/`, `ios/`, `web/` y `supabase/`, más los
advisors de seguridad del proyecto Supabase `bfqzabpgtehncnbxtslg` (consultados el 2026-09-30).
Gravedad: **Crítica** (bloquea la publicación), **Alta**, **Media**, **Baja**.

Nota sobre la precisión: los contrastes son cálculos propios con la fórmula WCAG 2.1; los
números de línea son los del código en la fecha de la auditoría.

---

## A) Accesibilidad (WCAG 2.1 AA y guías de Flutter)

Resumen: la base es buena (tema con contraste alto en el texto principal, botones de 54 dp,
mensajes de error en castellano llano, estados de carga/error/vacío en casi todas las pantallas).
Los fallos graves son dos: **el mapa es invisible para un lector de pantalla** y **no hay ni un
`Semantics` en todo `lib/`** (búsqueda de `Semantics|semanticLabel` sin resultados; solo hay un
`tooltip` en todo el proyecto, `pantalla_perfil.dart:25`).

### A1. Los círculos y marcadores del mapa son inaccesibles — Alta
- `lib/features/map/pantalla_mapa.dart:108-125` — `CircleLayer` con `CircleMarker`: es pintura
  en un canvas, no genera nodos semánticos. TalkBack/VoiceOver no los ven ni los pueden pulsar.
- `pantalla_mapa.dart:143-157` — el `Marker` de cada previa es un `GestureDetector` sobre un
  `Container` con un número suelto ("3"). Sin etiqueta, el lector dice solo "3" o nada, y
  `GestureDetector` no se anuncia como botón.
- `pantalla_mapa.dart:130-141` — el punto "tu posición" (18x18) no tiene etiqueta.

Arreglo:
1. Envolver cada burbuja: `Semantics(button: true, label: '${p.titulo}, ${p.plazasLibres} plazas libres, empieza a las HH:mm, a X m', onTap: ..., child: ExcludeSemantics(child: _BurbujaPlazas(...)))` y cambiar `GestureDetector` por `InkWell` dentro de un `SizedBox(48,48)`.
2. `Semantics(label: 'Tu posición aproximada', child: ...)` en el punto azul.
3. Envolver el `FlutterMap` en `Semantics(label: 'Mapa de previas cercanas. La lista de previas está debajo de la pantalla.')` y evitar que el lector intente navegar el mapa: lo importante es que **la alternativa accesible ya existe** (`_ListaInferior`, línea 234); hay que garantizar que es completa (título, hora, plazas, distancia, zona) y accesible con el foco del lector. Añadir un botón "Ver lista de previas" visible.
4. Añadir `Semantics(liveRegion: true)` a `_PastillaResumen` (`pantalla_mapa.dart:312`) para que se anuncie "3 previas en 5 km" tras buscar.

### A2. Botones con icono sin etiqueta — Alta
- `pantalla_mapa.dart:359-395` `_BotonRedondo` (filtros): `InkWell` + `Icon(Icons.tune)` sin `Semantics`, sin `tooltip`. Un lector dice "botón" sin más. Arreglo: añadir parámetro `etiqueta` y envolver en `Semantics(button: true, label: 'Filtros')` + `Tooltip`.
- `pantalla_mapa.dart:248-254` FAB "Mi posición": añadir `tooltip: 'Centrar en mi posición'`. Además `FloatingActionButton.small` mide 40 dp (<48).
- `pantalla_registro.dart:203-210` botón de mostrar contraseña: añadir `tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña'`. Revisar igual `pantalla_entrar.dart`.
- `pantalla_chat.dart:182-188` botón de enviar: añadir `tooltip: 'Enviar mensaje'`.
- `pantalla_detalle_previa.dart:44` `PopupMenuButton` usa el tooltip por defecto del framework ("Show menu", en inglés según locale; al ser `es_ES` saldrá "Mostrar menú"), mejorar con `tooltip: 'Reportar o bloquear'`.
- `CircleAvatar` de iniciales (`pantalla_perfil.dart:45`, y en tarjetas/chat): envolver en `Semantics(label: 'Foto de ${nombre}')` o `ExcludeSemantics` si es decorativo.
- Iconos decorativos dentro de `ListTile`/chips: marcar con `excludeFromSemantics`/`ExcludeSemantics` para no duplicar lectura.

### A3. Tamaños táctiles por debajo de 48 dp — Media
- `pantalla_mapa.dart:213` botón "Buscar en esta zona" `minimumSize: Size(0, 42)`.
- `pantalla_detalle_previa.dart:620` (44), `pantalla_perfil.dart:240` (44), `pantalla_valorar.dart:238` (46), `pantalla_solicitudes.dart:260,272` (46). Con `materialTapTargetSize` por defecto (`padded`) Material añade área táctil, pero si se cambia el tema o se usa `InkWell` a mano no. Arreglo: subir todos a `Size(0, 48)` y fijar en `tema.dart` `materialTapTargetSize: MaterialTapTargetSize.padded` y `visualDensity: VisualDensity.standard` de forma explícita.
- `pantalla_mapa.dart:143-146` marcador de 46x46 (<48). Subir a 48.
- Fichas y `CheckboxListTile` de `pantalla_registro.dart:219`: el texto legal mide 13 px y no tiene enlaces (ver B3); al añadir el enlace, que ocupe 48 dp de alto.

### A4. Contraste de colores del tema (`lib/app/tema.dart`) — Media
Cálculos sobre `fondo #0B0B12`:
| Par | Ratio | Resultado |
|---|---|---|
| `texto #F2F2F7` / fondo | ~17:1 | OK |
| `textoSuave #A0A0B2` / fondo | ~7.6:1 | OK |
| blanco / `primario #7C4DFF` (botones) | ~4.8:1 | OK (justo) |
| `error #FF5470` / fondo | ~6.3:1 | OK |
| **`textoTenue #6C6C80` / fondo** | **~3.8:1** | **Falla AA (4.5:1)**; sobre `superficie` baja a ~3.5:1 |
| **borde `#2A2A38` / fondo** (campos de texto, tarjetas) | **~1.3:1** | **Falla 1.4.11 (3:1 para componentes de interfaz)** |
| `hintStyle` = `textoTenue` (`tema.dart:~150`) | ~3.5:1 | Falla |

`textoTenue` se usa en 36 sitios (texto pequeño de 12 px incluido: `pantalla_ajustes.dart:~137`, `pantalla_registro.dart:173-177`, versión, hints).
Arreglo: subir `textoTenue` a ~`#8A8AA0` (≥4.5:1 sobre `superficie`); usar `textoSuave` para cualquier texto informativo; para el borde de `InputDecorationTheme` (enabled/border) usar un color ≥3:1 frente al fondo (p. ej. `#6C6C80`) y reservar `borde` actual solo para separadores decorativos. Comprobar además los chips y el texto negro sobre `acento` (correcto en `pantalla_mapa.dart:301`).

### A5. Escalado de texto (`textScaler`) — Media
- No hay `MediaQuery.textScaler` ni limitación global (bien: se respeta el ajuste del sistema), pero hay alturas fijas que recortarán con escala 1.5-2:
  - `_PastillaResumen` `height: 48` con `overflow: ellipsis` (`pantalla_mapa.dart:321,350`): con escala alta se corta el resumen. Usar `constraints: BoxConstraints(minHeight: 48)` y `maxLines: 2`.
  - `Marker` de 46x46 con número de `fontSize: 14`: el número crece dentro de un círculo de 34. Fijar `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)` solo en la burbuja.
  - Tarjetas (`tarjeta_previa.dart`) y `_ListaInferior`: probar con `textScaleFactor 2.0` (Ajustes del sistema) y evitar `SizedBox(height:)` fijo.
- `android:configChanges` incluye `fontScale` (AndroidManifest:19): correcto, Flutter reacciona sin recrear la actividad.
- Arreglo global: añadir un test de widget que monte las pantallas clave con `textScaler: TextScaler.linear(2.0)` y falle si hay overflow.

### A6. Foco y teclado — Media
- No hay gestión de foco (`Focus`, `FocusTraversalGroup`, `autofocus`): el orden por defecto sirve para formularios, pero:
  - Los `InkWell`/`GestureDetector` propios (`_BotonRedondo`, marcador, campo de fecha en `pantalla_registro.dart:148`) no son focusables por teclado o switch access salvo que se les dé `focusNode`/`Semantics`. Preferir `IconButton`/`ListTile`/`InkWell` con `canRequestFocus` y un `Semantics` con `onTap`.
  - Los formularios no declaran `textInputAction`/`onFieldSubmitted` (Enter/"Siguiente" en teclado físico). Añadir `textInputAction: TextInputAction.next` y `done` en el último campo.
  - `focusedBorder` del tema ya marca el foco con 2 px violeta: bien, pero el borde normal no se ve (ver A4).
- Los diálogos `AlertDialog` y hojas inferiores: Flutter gestiona el foco; probar con TalkBack que el título se anuncia.

### A7. Estados de carga, error y vacío — Media
Lo bueno: hay `loading`/`error`/`data` en mapa, perfil, detalle, chat y solicitudes, y estado vacío en chat (`pantalla_chat.dart:299`) y mapa.
Fallos:
- Los `CircularProgressIndicator` no tienen `semanticsLabel` (`pantalla_mapa.dart:334`, `pantalla_detalle_previa.dart:55`, `pantalla_perfil.dart:40`, `pantalla_registro.dart:269`). Añadir `semanticsLabel: 'Cargando'`.
- Los errores son texto plano sin botón "Reintentar" ni `liveRegion`: `pantalla_detalle_previa.dart:56-63`, `pantalla_perfil.dart:41-42`, `pantalla_mapa.dart:180` ("No se ha podido buscar" en una pastilla de 48 dp sin acción). Arreglo: un widget común `EstadoError(mensaje, onReintentar)` con `Semantics(liveRegion: true)` y botón de reintento (`ref.invalidate(...)`).
- Acciones sin `try/catch` que dejan al usuario sin respuesta si falla la red: `pantalla_detalle_previa.dart:90` (`repo.bloquear`) y `:104` (`repo.reportar`) lanzan excepción no capturada y no muestran nada; `pantalla_perfil.dart:249` (`eliminarMiCuenta`) igual; `_exportar` (`pantalla_perfil.dart:205-219`) solo dice "Datos preparados: N secciones" y **no entrega ningún fichero** (ver B5).
- Los mensajes (`SnackBar`) son correctos pero no son `liveRegion` garantizado; Flutter los anuncia, sin acción. OK.

### A8. Mensajes de error legibles — Baja
- `repositorio_auth.dart:176-197` traduce bien los errores de Supabase, pero depende de buscar subcadenas en inglés (`invalid login`, `already registered`): se romperá si Supabase cambia el texto. Usar `AuthException.code` (`invalid_credentials`, `user_already_exists`, `weak_password`) en lugar del mensaje.
- El validador de contraseña pide 6 caracteres (`pantalla_registro.dart:212`); ver B10 (subir a 8 y activar protección de contraseñas filtradas).
- Validación de correo solo `contains('@')` (`pantalla_registro.dart:190`): usar una regex simple.
- Los errores de formulario se ven en un recuadro (`pantalla_registro.dart:232`) pero no se anuncian al lector: envolver en `Semantics(liveRegion: true)` y mover el foco al primer campo inválido.
- Los errores no dependen solo del color (llevan icono y texto): correcto (1.4.1).

### A9. Otros — Baja
- Solo tema oscuro sin alternativa (`tema.dart:3-7`). Decisión razonada, pero WCAG 1.4.x no lo exige; conviene respetar `prefers-contrast`/alto contraste del sistema (`MediaQuery.highContrast`) usando un `ColorScheme` con más contraste.
- Orientación: iOS permite horizontal (Info.plist); la app está pensada en vertical. Probar horizontal o bloquear en `SystemChrome.setPreferredOrientations`.
- Idioma único `es_ES` (`main.dart:41`): correcto; los lectores pronunciarán en español.
- Animaciones: no hay; revisar si se añaden (respetar `MediaQuery.disableAnimations`).

---

## B) Preparación para publicar y utilidad real

### B1. Identificadores, nombre, iconos y splash — Alta
- `applicationId`/`namespace` = `com.previa.previa` (`android/app/build.gradle.kts:8,19`), bundle id iOS = `com.previa.previa` (`ios/Runner.xcodeproj/project.pbxproj:386`). Es el valor por defecto que crea `flutter create --org com.previa`: **probablemente ya esté cogido en Google Play o sea genérico**, y no corresponde a un dominio que controles. Decide ya un id definitivo (p. ej. `es.tudominio.previa`): cambiarlo después de publicar es imposible.
- Nombre: `android:label="Previa"` (AndroidManifest:13), `CFBundleDisplayName` Previa: correcto. `CFBundleName` = `previa` en minúsculas (Info.plist:~14) y `web/manifest.json` (`name: previa`, `description: "A new Flutter project."`, color `#0175C2` azul por defecto de Flutter, `web/index.html`): plantilla sin personalizar.
- Iconos: `android/.../mipmap-*/ic_launcher.png` y `ios/.../AppIcon.appiconset` parecen los iconos por defecto de Flutter (no hay `flutter_launcher_icons` en `pubspec.yaml`). Faltan: icono adaptativo Android (`mipmap-anydpi-v26` con foreground/background y monocromo), icono iOS 1024x1024 sin transparencia. Arreglo: añadir `flutter_launcher_icons` con el logo de marca.
- Splash: `LaunchScreen.storyboard` y `values/styles.xml` siguen siendo el splash blanco de Flutter, **en una app de tema oscuro produce un fogonazo blanco** al arrancar. Arreglo: `flutter_native_splash` con fondo `#0B0B12` (Android 12 usa su propia API `windowSplashScreenBackground`; `values-night/styles.xml` también).
- Versión visible en Ajustes es una cadena fija `versión 1.0.0` (`pantalla_ajustes.dart:~132`): leerla con `package_info_plus`.
- Falta `targetSdk`: hoy es `flutter.targetSdkVersion`; comprobar que cumple el requisito anual de Google Play.

### B2. Permisos — Media
- Android (`AndroidManifest.xml:3-12`): solo `INTERNET` y `ACCESS_COARSE_LOCATION`. Es lo correcto y mínimo. El `INTERNET` está en el manifest principal (no solo en debug): bien. Riesgo: `geolocator` fusiona su propio manifest y puede añadir `ACCESS_FINE_LOCATION`; verificar en el manifest fusionado de release (`build/app/intermediates/merged_manifests`) y quitar con `tools:node="remove"` si aparece. En Android 12+ el usuario puede conceder solo aproximada: el código actual ya tolera ambos.
- Faltan `POST_NOTIFICATIONS` (Android 13+) si se añade FCM (el README lo promete, pero no hay `firebase_messaging` en `pubspec.yaml`: ver B9).
- iOS (`Info.plist:70-73`): solo `NSLocationWhenInUseUsageDescription`, texto claro. **Problema de veracidad**: dice "Nunca la compartimos con nadie ni la guardamos" y los Ajustes dicen "Pedimos únicamente precisión aproximada"; en iOS `LocationAccuracy.medium` no garantiza aproximada, y si se envía la posición del usuario al servidor en `previas_cerca` (p_lat/p_lng, `pantalla_mapa.dart`/`servicio_ubicacion.dart`), los logs de Supabase/API la registran. Rebajar el texto a "No la compartimos con otros usuarios" o garantizar que no se loguea.
- Si se sube foto de perfil (Storage, README) hacen falta `NSPhotoLibraryUsageDescription`/`NSCameraUsageDescription`. Hoy no hay `image_picker`: coherente, pero el README dice "fotos de perfil" y `avatar_url` existe; decidir.
- iOS: añadir `PrivacyInfo.xcprivacy` (manifiesto de privacidad exigido por Apple) declarando ubicación aproximada, correo y nombre; y `ITSAppUsesNonExemptEncryption = false`.

### B3. Política de privacidad y condiciones — Crítica
- La "política" es una pantalla interna `Ajustes` (`pantalla_ajustes.dart`, ruta `/ajustes`) que solo se ve **con sesión iniciada** (`rutas.dart:~60`: el guard redirige a `/bienvenida` si no hay sesión). Google Play y Apple exigen una **URL pública** de política de privacidad (campo en la ficha de la tienda) y que sea accesible desde la app antes del registro.
- `pantalla_registro.dart:225-228` dice "acepto las condiciones de uso y la política de privacidad" pero **no hay enlace** a ninguna; y no existen unas condiciones de uso en ningún sitio.
- No hay identidad del responsable del tratamiento (nombre, contacto, email de ejercicio de derechos) ni plazos de conservación de reportes/logs; el RGPD art. 13 lo exige.
Arreglo:
1. Redactar política + condiciones de uso (responsable, finalidades, base legal, encargados como Supabase/CARTO/OSM y transferencias internacionales, derechos, contacto, edad mínima, normas de comunidad).
2. Publicarlas en una URL estática (la carpeta `web/` o un proyecto en Vercel: `/privacidad`, `/condiciones`, `/soporte`).
3. Enlazarlas con `url_launcher` desde el checkbox del registro (TextSpan con `TapGestureRecognizer`), desde `pantalla_bienvenida.dart` y desde Ajustes, y dar de alta la URL en App Store Connect / Play Console.
4. Añadir en Play Console la declaración "Seguridad de los datos" y el cuestionario de clasificación (alcohol: contenido sobre alcohol suele pedir clasificación 18+ / 17+ en iOS).

### B4. Firma de release — Crítica
- `android/app/build.gradle.kts:33-37`: el build `release` se firma con la clave **debug** (`TODO: Add your own signing config`). Google Play rechaza un AAB firmado con debug. Arreglo: crear un keystore de subida (`keytool`), `android/key.properties` (fuera del repositorio, añadir a `.gitignore`), `signingConfigs.release` leyendo ese fichero, y activar Play App Signing. Guardar copia del keystore fuera del equipo.
- Activar `isMinifyEnabled = true` + `isShrinkResources = true` y revisar reglas de R8 (`proguard-rules.pro`) para `flutter_map`/`geolocator`.
- iOS: falta configurar equipo de desarrollo y perfiles de aprovisionamiento; requiere cuenta de Apple Developer (99 USD/año) y un Mac.
- `.env` se carga como **asset** (`pubspec.yaml:54` lista assets; `main.dart:16` `dotenv.load`): el fichero `.env` queda empaquetado y **es extraíble del APK**. Es aceptable mientras solo contenga la URL y la clave publicable, pero no añadas nunca una `service_role`. Alternativa limpia: `--dart-define` en CI.

### B5. Borrado de cuenta dentro de la app — Alta (existe, pero con fallos)
Existe: `pantalla_perfil.dart:183-190` y `_eliminarCuenta` (:221) llaman a la RPC `eliminar_mi_cuenta` (`supabase/migrations/20260920201917_...sql:~126`), que borra `auth.users` y el resto cae en cascada. Cumple en lo esencial el requisito de Google Play y Apple 5.1.1(v). Fallos:
- **El proyecto Supabase `bfqzabpgtehncnbxtslg` no es exclusivo de Previa**: contiene también `posts`, `post_likes`, `follows`, `venues`, `venue_plans`, `direct_messages`, `venue_messages`, `notices`, `challenges` (con 14 perfiles, 32 follows, 15 planes...) y funciones `completar_reto`, `rajarse`, `retirar_publicacion` que no aparecen en `supabase/migrations/` (los advisors las listan). Es de **otra aplicación** o de un prototipo anterior. Consecuencias: (1) `eliminar_mi_cuenta` borra `auth.users` y, por cascada, datos de esa otra app para el mismo usuario; (2) `profiles` compartida puede mezclar perfiles; (3) la migraciones del repo no reproducen el estado real. **Decisión urgente**: usar un proyecto Supabase dedicado a Previa, o documentar y reconciliar el esquema.
- No hay paso de reautenticación ni escribir "ELIMINAR"; un toque accidental borra todo. Añadir confirmación con contraseña o texto.
- Sin `try/catch` (`pantalla_perfil.dart:249`): si falla, el usuario no ve nada; además se llama a `salir()` tras borrar (`repositorio_auth.dart:164-165`) y fallará con 401 (token ya inválido): envolver `salir()` en try/catch y forzar `signOut(scope: SignOutScope.local)`.
- Apple exige también poder iniciar el borrado desde un enlace web si no puedes borrar en app; no hace falta, pero Google Play sí pide una **URL web de "solicitud de eliminación de datos"** en la ficha de la tienda: publicarla junto a la política.
- **Exportar datos**: `_exportar` (`pantalla_perfil.dart:205`) solo muestra un SnackBar con el número de secciones; el usuario no recibe fichero (incumple art. 15/20 que la propia app promete). Arreglo: `share_plus` o `file_saver` para guardar/compartir el JSON.
- Datos que no borra ni exporta: reportes emitidos/recibidos (`reports` no figura en `exportar_mis_datos`); decidir conservación de reportes contra el usuario (interés legítimo) y documentarlo.

### B6. Moderación y reportes — Alta
Lo que existe: tablas `blocks` y `reports` con RLS (0 filas en el proyecto), botón de reportar/bloquear al anfitrión (`pantalla_detalle_previa.dart:47-49`).
Lo que falta:
- **Nadie lee los reportes**: no hay panel, ni vista, ni aviso por email/Slack. Sin un proceso de revisión, el reporte no cumple la política de contenido generado por usuarios de Apple (1.2: filtrar contenido, mecanismo de reporte, **bloquear abusivos y actuar en 24 h**) ni de Google Play UGC. Arreglo mínimo: una Edge Function o trigger `on insert reports` que envíe email (Resend/SMTP) a soporte, y una vista SQL `reportes_pendientes`; añadir columna `status`/`resolved_at`.
- El README y `pantalla_ajustes.dart:97` prometen "reportar perfiles, previas y **mensajes**", pero `pantalla_chat.dart` no tiene ninguna opción de reportar/bloquear (grep: `report` no aparece en `lib/features/chat`). Tampoco hay reporte/bloqueo desde perfiles de otros usuarios ni desde las solicitudes (`pantalla_solicitudes.dart`). Arreglo: menú de mantenimiento pulsación larga en mensaje → "Reportar"; botón en cabecera del chat "Bloquear/Reportar"; opciones en cada solicitante.
- No hay pantalla de "usuarios bloqueados" para desbloquear (`desbloquear` existe en `repositorio_previas.dart:296` pero no se usa).
- Una cuenta con muchos reportes no se suspende automáticamente: añadir `profiles.suspended_at` y policy que lo respete; y `retirar_publicacion` existe en BD (ver advisor) pero pertenece a otro esquema.
- Sin filtro de contenido (títulos/descripciones/mensajes con teléfonos, enlaces, insultos). Añadir una lista mínima de palabras y límites de longitud con `check` en SQL.

### B7. Protección de menores — Alta
- Solo hay casilla "Soy mayor de 18" + fecha de nacimiento (`pantalla_registro.dart:62,219`; trigger SQL `20260920201657_...sql:48`): es declarativo, bien documentado en `docs/05`. Riesgos reales por ser una app de **alcohol + desconocidos + localización**:
  - El trigger solo valida si `birth_date` no es nulo: `birth_date` admite `NULL` (registro con Google, línea 16 de la migración) y `onboarded := birth_date is not null`. Comprobar que **toda** acción (crear previa, solicitar plaza, chat) exige `onboarded = true` en las políticas RLS; y que no hay otro camino para dejar `birth_date` a null en un UPDATE.
  - Un menor puede cambiar la fecha de nacimiento tras el registro (`actualizarPerfil` permite `birth_date`; `pantalla_editar_perfil.dart`). Hacer `birth_date` inmutable una vez fijada (trigger `before update` que lo impida salvo soporte) para que no se "corrija" repetidamente hasta pasar el filtro.
  - Clasificación por edades en las tiendas: marcar 18+ (Play: clasificación IARC; Apple: 18+ por referencias a alcohol). Mencionar "consumo responsable" y no promover el alcohol a menores: el texto de tienda debe ser cuidadoso (no "emborracharse").
  - Texto de seguridad en la app: pantalla previa al primer encuentro con consejos (quedar en sitio público, avisar a un amigo) — hoy solo aparece en Ajustes (`pantalla_ajustes.dart:99-103`), que nadie lee.

### B8. Rate limiting y abuso en Supabase — Alta
- `docs/05-seguridad-y-rgpd.md` afirma "Limitación de frecuencia en la creación de previas y solicitudes", **pero no hay ninguna en las migraciones** (búsqueda de `rate|limit|throttle` en `supabase/migrations`: sin resultados relevantes). Un usuario o un script con una sola cuenta puede crear miles de previas, solicitudes, mensajes o reportes. Arreglo: triggers `before insert` que cuenten filas recientes por `auth.uid()` (p. ej. máx. 3 previas activas por anfitrión, 20 solicitudes/hora, 30 mensajes/minuto, 10 reportes/día) y `raise exception`; `check (char_length(body) <= 1000)` en mensajes y límites en `title/description`.
- Autenticación: en el panel, configurar Auth > Rate Limits (emails, inicios de sesión por IP), activar CAPTCHA (hCaptcha/Turnstile) en registro, y confirmación de correo obligatoria (comprobar que está activa: el registro de `pantalla_registro.dart:84` pasa directo a `Rutas.inicio`, lo que sugiere que **no** se exige confirmar el correo). Sin confirmación, el registro masivo con correos falsos es trivial.
- `previas_cerca` es RPC con límite de 50 filas (bien), pero sin límite de radio máximo en servidor: validar `p_radio_m <= 50000`.
- Realtime: limitar canales y revisar que los mensajes solo se emitan a miembros (RLS en `messages`).

### B9. Advisors de seguridad de Supabase (solo lectura) — Media
Resultado de `get_advisors(type=security)` sobre `bfqzabpgtehncnbxtslg`:
1. **WARN `authenticated_security_definer_function_executable` (8 funciones)**, todas expuestas como RPC a `authenticated`: `completar_reto`, `edad`, `eliminar_mi_cuenta`, `exportar_mis_datos`, `mi_fecha_nacimiento`, `rajarse`, `retirar_publicacion`, `ubicacion_exacta`. Para las de Previa (`edad`, `eliminar_mi_cuenta`, `exportar_mis_datos`, `mi_fecha_nacimiento`, `ubicacion_exacta`) es **intencionado y necesario** (comprueban `auth.uid()`/`es_miembro`). Aun así:
   - `edad(p_profile)` (`...funciones_busqueda_y_derechos_rgpd.sql`) permite a cualquier usuario autenticado consultar la edad exacta de cualquier perfil: aceptable si se decide que la edad es pública, pero contradice "la edad sale solo para..." Valora limitar a perfiles con interacción (miembro/solicitud) o redondear a tramos.
   - `completar_reto`, `rajarse`, `retirar_publicacion` **no pertenecen a Previa** (ver B5): revisar si `retirar_publicacion(reporte uuid)` permite que cualquier usuario autenticado retire publicaciones ajenas (función de moderación ejecutable por todos) y revocar `EXECUTE` si no es intencionado. Fuente: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
2. **WARN `auth_leaked_password_protection`**: desactivada. Actívala en Auth > Policies (HaveIBeenPwned; requiere plan Pro) y sube la longitud mínima a 8. https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
No aparecen tablas sin RLS (las 17 tienen RLS activado). Migración `20260920202302_cerrar_ejecucion_anonima.sql` y pruebas `supabase/tests/seguridad.sql` (16/16) son un buen punto de partida; añadir pruebas para los límites de B8 y `ubicacion_exacta` desde un no miembro.
Advisors de rendimiento no consultados (el encargo pedía seguridad).

### B10. Manejo de errores y modo sin conexión — Media
- `main.dart:16-23`: `dotenv.load` y `Supabase.initialize` sin `try/catch`; si falta `.env` o no hay red, pantalla en blanco/crash al arrancar. Envolver y mostrar una pantalla de error con "Reintentar".
- No hay `FlutterError.onError`/`PlatformDispatcher.instance.onError` ni reporte de fallos (Sentry/Crashlytics): tras publicar no sabrás por qué falla. Añadir `sentry_flutter` (sin PII) o Crashlytics.
- No hay detección de conectividad ni caché: el mapa y las previas se vacían sin red (el `StreamProvider` de chat `pantalla_chat.dart:12` se corta y no se re-suscribe con aviso). Añadir `connectivity_plus` con un banner "Sin conexión" y `retry` automático en providers; las teselas del mapa usan `cached_network_image`? No: `flutter_map` usa `NetworkTileProvider`; añadir `flutter_map_cache` si se quiere mapa offline.
- Mensajes de chat: si falla el envío se muestra SnackBar (`pantalla_chat.dart:64-68`) pero el texto ya se ha borrado; conservar el texto para reintentar.
- Las teselas de CARTO (`basemaps.cartocdn.com`, `pantalla_mapa.dart:87`) **no son libres para producción sin acuerdo** (sus condiciones limitan uso comercial/alto volumen, y hay que mantener atribución). Para publicar: usar un proveedor con plan (MapTiler, Stadia, Protomaps propio) o aceptar sus términos; `userAgentPackageName: 'com.previa.previa'` también debe actualizarse al id final.

### B11. Fugas de datos y ubicación exacta — Alta (comprobar) / Media
Lo bueno: `location` no es seleccionable por `authenticated`, solo por `ubicacion_exacta()` tras `es_miembro`; el difuminado es fijo por previa (`previas_y_difuminado_de_ubicacion.sql`); la fecha de nacimiento no es legible. Puntos débiles:
- **El difuminado es de ~300 m** (`core/entorno.dart:~32`): en un barrio residencial es aproximadamente "el portal o los de al lado". Combinado con `area_label`, título, hora, plazas, y el círculo dibujado como un disco con radio = 300 m **centrado en `location_fuzzed`** (`pantalla_mapa.dart:111-121`), la zona tiene centro fijo. Con el desplazamiento aleatorio fijo, un atacante que obtenga un punto fuzzed de una previa conocida no mejora, pero un atacante **que se haga aceptar en previas o tenga la posición real de otro** puede deducir el offset; y si el mismo anfitrión publica dos previas nuevas con **offset distinto** (si se recalcula por previa, no por anfitrión), promediar las dos revela el domicilio. Arreglo: derivar el offset de forma determinista por **anfitrión + ubicación cuadriculada** (p. ej. redondear a una cuadrícula de 500 m y mover al centro de celda), o usar un offset por `host_id` fijo; nunca dibujar el círculo centrado en el punto desplazado sino en la celda.
- La posición del usuario (`p_lat`, `p_lng`) viaja a `previas_cerca` en cada búsqueda (`repositorio_previas.dart`): queda en logs de la API/Postgres de Supabase. Redondear a 3 decimales (~100 m) en el cliente antes de llamar.
- Al aceptar a alguien, **la dirección exacta es permanente** para ese miembro hasta que se borra la previa (48 h): si luego se le expulsa/reporta, compruebar que `es_miembro` deja de ser verdadero. Añadir acción "Expulsar" para el anfitrión.
- `Perfil`: `reputation`, `ratings_count`, `username` legibles por cualquier autenticado: aceptable. Comprobar que `select` de `profiles` no expone `birth_date` ni correo (columnas listadas explícitamente en `repositorio_auth.dart:100,111`: correcto).
- Tiles de OSM/CARTO reciben la IP y el viewport del usuario (centro del mapa ≈ ubicación): informar en la política (B3) como tercero.
- `.env` empaquetado (B4) solo contiene claves públicas: OK.

### B12. Utilidad real y arranque en frío — Crítica (producto)
Con pocos usuarios, el mapa dirá "Nada por aquí ahora mismo" (`pantalla_mapa.dart:182`) y el usuario desinstalará en el primer minuto. Es un mercado de dos lados y hoy la app **solo funciona cuando ya hay previas publicadas**. Lo que falta, por orden de impacto:
1. **Lanzamiento por zona/comunidad, no global**: elegir una ciudad/campus (p. ej. una universidad) y una noche/un día fijo. Mensaje: "este viernes en X". Sin masa crítica por zona no hay producto; limitar el mapa a zonas activas.
2. **Estado vacío útil**: en vez de "Nada por aquí", ofrecer "Sé el primero: abre una previa", "Avísame cuando haya una cerca" (suscripción por zona) y "Invita a un amigo" (compartir enlace). Hoy no hay ninguna de las tres.
3. **Notificaciones push** (README promete FCM pero `pubspec.yaml` no tiene `firebase_messaging` ni hay `google-services.json`): sin push, el anfitrión no se entera de una solicitud ni el solicitante de la aceptación salvo que abra la app. Es lo que cierra el bucle con pocos usuarios. Incluye: nueva solicitud, aceptada/rechazada, mensaje nuevo, recordatorio 1 h antes.
4. **Enlaces compartibles y deep links** (`previa.app/p/<id>` → abre la previa o la tienda): permite que un grupo invite a sus amigos de WhatsApp/Instagram y traiga usuarios nuevos. Hoy las rutas son solo internas (`rutas.dart`) y no hay `intent-filter` ni `apple-app-site-association`.
5. **Previas de grupo a grupo** hoy exigen que el anfitrión tenga casa. Añadir un modo "busco plan / somos 3 sin sitio" (ofertas inversas) para que la demanda también aparezca en el mapa y el anfitrión pueda invitar.
6. **Contenido semilla**: eventos/locales cercanos (bares, fiestas universitarias) como "previas oficiales" publicadas por ti para que el mapa no esté vacío los primeros meses. (El proyecto Supabase ya tiene `venues`/`venue_plans`: si pertenecen a otro prototipo, reutilizar la idea.)
7. **Confianza**: hoy el perfil es solo iniciales (sin foto: `pantalla_perfil.dart:45`; `avatar_url` existe pero no hay subida). Un desconocido que entra en tu casa necesita ver una cara, verificación de correo/teléfono y reputación. Añadir foto (con moderación), "miembro desde", nº de previas hechas.
8. **Login con Google/Apple**: README dice "Auth (email + Google)" pero no hay `google_sign_in` en `pubspec.yaml` ni botón en `pantalla_entrar.dart`; y si añades Google, **Apple exige "Sign in with Apple"** en iOS. Reduce fricción de registro (hoy 6 campos, incluida fecha de nacimiento).
9. **Buscar por zona escrita** (`docs/05` lo promete): el mapa no tiene buscador de direcciones; hoy solo arrastrar (`pantalla_mapa.dart:72-80`). Añadir geocodificación (Nominatim/MapTiler) para "Malasaña", "Campus X".
10. **Medición**: sin analíticas ni métricas de retención no sabrás si funciona; añadir eventos anónimos mínimos (abrir mapa, crear previa, solicitud, aceptada) cumpliendo RGPD (consentimiento o datos sin PII).

### B13. Otros puntos de publicación — Media/Baja
- Web: `web/` es un scaffold sin personalizar (`manifest.json`, `index.html`); o se elimina la plataforma, o se usa para la landing/privacidad (B3).
- Android: `android:allowBackup` no declarado (por defecto `true`): poner `false` o `dataExtractionRules` para no subir tokens de sesión a copias de seguridad. `android:usesCleartextTraffic` no está: bien.
- `SceneDelegate`/iOS: comprobar `UISceneStoryboardFile` válido (Info.plist:~33; Flutter reciente lo trae).
- `README.md` y `docs/` desactualizados respecto al código en algunos puntos (push, Google, rate limiting): actualizar o el tribunal/revisor de tiendas lo verá como funciones declaradas y no entregadas.
- Pruebas: 5 unitarias. Añadir pruebas de widget de accesibilidad (`meetsGuideline(androidTapTargetGuideline)`, `labeledTapTargetGuideline`, `textContrastGuideline`) — Flutter trae estas comprobaciones y detectarían A1-A4 automáticamente.

---

## Lista priorizada de tareas

**Bloquean la publicación (hacer antes de cualquier envío a tienda)**
1. Decidir `applicationId`/bundle id definitivos propios y cambiarlos (Android, iOS, `userAgentPackageName`). (B1)
2. Firma de release real con keystore propio, `key.properties` fuera del repo, Play App Signing. (B4)
3. Política de privacidad + condiciones + página de soporte/eliminación en URL pública, enlazadas desde registro, bienvenida y Ajustes; identificar al responsable. (B3)
4. Separar Supabase: proyecto dedicado a Previa (o reconciliar esquema con `posts/venues/challenges` y las RPC `completar_reto/rajarse/retirar_publicacion`); revisar que `eliminar_mi_cuenta` no destruya datos de otra app. (B5, B9)
5. Icono adaptativo, splash oscuro, nombre, `manifest.json` y `PrivacyInfo.xcprivacy`. (B1, B2)
6. Proceso real de moderación: notificación de reportes, reporte/bloqueo desde chat y perfiles, pantalla de bloqueados, acción de expulsar. (B6)
7. Límites de frecuencia y de longitud en SQL (previas, solicitudes, mensajes, reportes) + confirmación obligatoria de correo + CAPTCHA + activar protección de contraseñas filtradas. (B8, B9)

**Altas**
8. Accesibilidad del mapa: `Semantics` en marcadores y punto de posición, lista alternativa completa, etiquetas/tooltips en todos los botones con icono. (A1, A2)
9. Contraste: subir `textoTenue`, borde de campos y `hintStyle`. (A4)
10. Entregar de verdad la exportación de datos (fichero) y confirmar con reautenticación el borrado de cuenta con manejo de errores. (B5)
11. Protección de menores: hacer `birth_date` inmutable, exigir `onboarded` en todas las políticas, clasificación 18+ en tiendas. (B7)
12. Revisar el difuminado de ubicación (offset por anfitrión/cuadrícula) y redondear la posición del usuario antes de enviarla. (B11)
13. Notificaciones push (FCM) y enlaces compartibles/deep links. (B12)
14. Estrategia de arranque en frío: elegir una zona, estado vacío con acciones, siembra de previas, invitación. (B12)

**Medias**
15. Tamaños táctiles a 48 dp, `textScaler` (alturas fijas), `semanticsLabel` en indicadores de carga, widget común de error con "Reintentar" y `try/catch` en bloquear/reportar/eliminar. (A3, A5, A7)
16. Manejo de fallos de arranque, reporte de errores (Sentry/Crashlytics), conectividad y mantener el texto del chat si falla el envío. (B10)
17. Proveedor de teselas con condiciones aptas para producción. (B10)
18. Permisos: verificar manifest fusionado, corregir el texto de ubicación de iOS, `allowBackup=false`. (B2, B13)
19. Login con Google/Apple, foto de perfil moderada, buscador de zonas. (B12)

**Bajas**
20. Usar `AuthException.code` en lugar de buscar texto, validar correo con regex, subir contraseña mínima a 8, foco/`textInputAction`, alto contraste, versión dinámica con `package_info_plus`, pruebas de guías de accesibilidad de Flutter. (A6, A8, A9, B13)

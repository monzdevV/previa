# Contexto de Previa

Léeme antes de tocar nada. Está escrito para que una sesión nueva no tenga
que releer medio proyecto para entenderlo.

## Qué es

Red social de proximidad para salir de fiesta. TFG de 2º de DAM, entrega en
junio de 2026. La idea: que la gente deje de salir siempre con los mismos.

Cinco pestañas en una barra de vidrio que flota sobre el contenido
(`lib/features/map/pantalla_inicio.dart`), y **una sola acción arriba** por
pantalla:

1. **Inicio** — el feed, la noche contada en fotos y vídeos. Arriba, el "+"
   abre la hoja de crear (subir foto o abrir previa).
2. **Mapa** — previas cerca: una pastilla arriba (resumen y filtros) y un
   carrusel de tarjetas atado al mapa.
3. **¿Vas?** — en el centro. Los locales de la ciudad como fotos a ancho
   completo, pegadas y ordenadas de más cerca a más lejos, con la ciudad en
   una pastilla blanca flotando arriba. Toque en la foto abre la ficha (quién
   va, sala, entradas); toque en la pastilla "¿Vas?" es "voy"; toque largo
   en cualquier parte, quizá, más tarde, estoy aquí o no voy.
4. **Buzón** — mensajes y avisos juntos. Arriba, buscar gente.
5. **Tú** — tu perfil: foto, redes, calendario social y fotos. Arriba, el
   engranaje de Ajustes, donde vive todo lo secundario (solicitudes, valorar,
   moderación, tema, juego, privacidad, datos, borrar cuenta y salir).

El registro pide solo nombre, fecha de nacimiento y correo con contraseña;
el nombre de usuario se genera solo y se cambia en Editar perfil. El perfil
recuerda lo que falta con la tarjeta "Completa tu perfil".

Alrededor: perfiles públicos, seguir gente, código QR, buscador y mensajes
directos.

Dentro de la sala de un local está el minijuego **No hay 🥚**: un sticker
reparte un reto ("busca a X y haceos una foto") con alguien que también ha
dicho que va a ese local esa noche, con su ficha y su cara. Se cumple
subiendo la foto a la sala.

## Stack

Flutter (Android, iOS, web) · Riverpod · go_router · Supabase (Postgres 17 +
PostGIS) · flutter_map sobre teselas Canvas de Esri (sin clave; CARTO dejo de servir gratis en sept. 2026).

Proyecto Supabase: `bfqzabpgtehncnbxtslg`, región eu-west-3.

## Convenciones que NO se negocian

- **Todo en español**: clases, variables, comentarios y mensajes de commit.
  La base de datos es la excepción: columnas y tablas en inglés, porque ya
  estaban así.
- **Los comentarios explican POR QUÉ, nunca QUÉ.** Es un TFG y hay defensa.
- Antes de cada commit: `flutter analyze` sin incidencias y `flutter test` en
  verde.
- Commits por bloque terminado, no al final.

## Reglas de diseño

Referencias fijadas por el usuario: **Instagram, TikTok, BeReal, Discord**
para la estructura, y **Nyxell** (nyxell.com) para la voz visual: titulares
enormes en mayúsculas con letra gorda y redondeada, bloques de color plano,
cintas de texto que corren y botones en pastilla. Se toma el lenguaje, no la
marca: Previa conserva su amarillo, su nombre y sus propias "pegatinas".

- La imagen ocupa el marco. Las caras están siempre presentes.
- **Amarillo `#FFE500` sobre negro puro `#000000`.** Sobre el amarillo el
  texto va en negro, nunca en blanco (`ColoresPrevia.sobrePrimario`).
- Verde `#35E07F` significa "queda sitio" o "está disponible".
- Esquinas generosas: `radio` 16, `radioGrande` 24, `pastilla` para botones,
  etiquetas, estados y avatares.
- **Titulares en Rubik 900 y en mayúsculas** con el widget `Titular` (las
  mayúsculas las pone el widget; el texto va escrito normal). El cuerpo sigue
  en la letra del sistema. Rubik va en `assets/fonts` con su licencia OFL.
- Bloques de color (`BloquesPrevia`: amarillo, menta, azul, rojo, lila) para
  fichas y secciones, siempre con `tintaSobreBloque` encima.
- `Marquesina` (cinta que corre) para rotular secciones y `Pegatina` (emoji
  grande torcido) como ilustración.
- Todo el sistema vive en `lib/app/tema.dart`.

## Invariante de privacidad

`parties.location` es la dirección exacta y el rol `authenticated` **no tiene
SELECT** sobre esa columna. Se obtiene con `ubicacion_exacta()`, que solo la
entrega si la previa es pública, eres el anfitrión o eres asistente aceptado.
En el mapa las previas se dibujan como **círculos**, nunca chinchetas, porque
las coordenadas que llegan al cliente están desplazadas ~300 m.

Esto se aplica en la base de datos, jamás en el cliente. No lo muevas.

## Esquema

Ya existía: `profiles`, `parties`, `join_requests`, `party_members`,
`messages`, `blocks`, `reports`, `ratings`.

Añadido para la parte social:

| Tabla | Para qué |
|---|---|
| `posts` | publicaciones del feed, foto o vídeo, con `area_label` de zona |
| `post_likes` | likes; el contador lo mantiene un disparador |
| `follows` | seguir gente, unidireccional como Instagram |
| `venues` | discotecas y bares, con enlace de entradas e Instagram |
| `venue_plans` | "voy a X esta noche"; la noche es una fecha, no un instante |
| `direct_messages` | mensajes directos entre personas |
| `venue_messages` | la sala de un local, por local y noche |
| `notices` | avisos; los crean disparadores, nadie los inserta a mano |
| `challenges` | retos de No hay 🥚; solo los escriben funciones |

Funciones: `feed_publicaciones`, `locales_de_la_noche`, `quien_va`,
`mis_conversaciones`, y las del juego: `comprobar_reto`, `crear_reto`,
`reescribir_reto` y `quitar_foto_de_reto_de` (solo `service_role`), y
`mi_reto`, `completar_reto` y `rajarse` para la app.

**Función de borde `no-hay-huevos`** (`supabase/functions/no-hay-huevos`):
verifica la sesión, llama a `comprobar_reto`, crea el reto con un texto de
reserva y luego deja que Claude lo reescriba (así pedir en paralelo no
multiplica llamadas a la IA). También atiende `{accion: 'quitar'}`: borra la
foto de un reto y su fichero del cubo. La IA solo recibe el nombre del local; el nombre de la
persona lo pone Postgres sustituyendo `{persona}`. Sin el secreto
`ANTHROPIC_API_KEY` funciona igual con retos de reserva. Se prueba con
`node --test supabase/functions/no-hay-huevos/reto.test.ts`.
Cubos de Storage: `publicaciones` y `avatares`, públicos de lectura, y cada
quien solo escribe en su carpeta `<uid>/`.

`privado.hay_bloqueo()` y `privado.hay_contacto()` viven fuera de `public` a
propósito: las políticas las llaman pero no deben ser rutas de la API.

**Regla de contacto de los mensajes**: solo puedes escribir a quien sigues o a
quien te sigue, y se aplica en la base de datos. Es lo que separa una red
social de un buzón abierto a desconocidos.

**Datos de demostración**: seis perfiles, sus publicaciones, seis discotecas de
Zaragoza y quién va a cada una. Todo lleva `is_demo = true`, así que se borra
con tres `delete ... where is_demo`. Las cuentas están en `auth.users` sin
contraseña: nadie puede iniciar sesión como ellas. Las fichas de los locales
van sin enlace de entradas a propósito, porque inventarlo sería una afirmación
comercial falsa.

## Colores

La paleta es una `ThemeExtension`, no constantes: se lee con
`context.colores.fondo`. Hay dos, `ColoresPrevia.oscuro` y `.claro`.

**Regla que se rompe sola si no la miras**: el amarillo de marca sobre blanco
no llega al contraste mínimo para texto. Como relleno de botón va bien (con
texto negro encima), pero para rótulos, iconos y ruletas hay que usar
`primarioTexto`, que en claro es un ámbar oscuro y en oscuro es el mismo
amarillo.

## Pendiente, por orden

00. **Aplicar la migración `supabase/migrations/20260928120000_vas_y_redes.sql`**
   (no se pudo aplicar desde la sesión que la escribió). Añade los estados de
   "¿Vas?" (`venue_plans.status`, tabla `venue_maybes`, RPC `decir_si_voy`,
   caras en `locales_de_la_noche`) y las columnas `tiktok` y `x_handle` del
   perfil. **La app funciona sin ella**: "quizá" avisa de que falta y TikTok/X
   no se guardan. Tras aplicarla, conviene añadir sus pruebas a
   `supabase/tests/`.

01. **Aplicar `supabase/migrations/20260929120000_locales_con_foto.sql`**
   (después de la anterior). Añade a `venues` `cover_url`, `logo_url` y
   `tagline` (solo lectura para la app) y hace que `locales_de_la_noche`
   devuelva eso más `lat`/`lng`. Luego hay que **rellenar foto, logo y
   coordenadas de los locales** desde el panel: sin foto la tarjeta pinta
   luces de colores y sin coordenadas no enseña distancia. La distancia se
   calcula en el teléfono; la posición no se manda al servidor.

0. **Poner la clave de la IA**: `npx supabase secrets set ANTHROPIC_API_KEY=...
   --project-ref bfqzabpgtehncnbxtslg`. Sin ella los retos salen de la lista
   de reserva de `reto.ts`.

1. **Notificaciones push.** Los avisos dentro de la aplicación ya funcionan y
   se guardan en `notices`; falta el proyecto de Firebase y enviar desde un
   disparador. La lógica de qué avisar ya está hecha.
2. **Probarla en un móvil.** Nada se ha ejecutado en un teléfono: ni cámara,
   ni escáner QR, ni compartir, ni permisos. Es el riesgo más serio.
3. **Vídeo en el feed**: se sube y se reproduce, pero no hay miniatura
   (`posts.thumbnail_url` queda nulo).
4. **Comentarios** en las publicaciones: solo hay likes.
5. Login con Google y caducidad automática de previas.

## Cosas que te van a morder

- **"Quizá" no es ir.** Vive en `venue_maybes`, no en `venue_plans`, a
  propósito: el juego, la sala y el calendario leen `venue_plans` como "va" y
  no tienen que acordarse de descontar nada. Se escribe siempre con
  `decir_si_voy`, que cambia de tabla en una transacción.
- El cliente tolera el servidor con y sin la migración `vas_y_redes`: la
  lectura del perfil (`leerPerfil` en `repositorio_auth.dart`) reintenta sin
  `tiktok`/`x_handle` si Postgres responde 42703, y `decirSiVoy` cae al
  insert/delete de antes si no existe la RPC (PGRST202). Cuando la migración
  esté aplicada en todas partes, esos dos atajos se pueden quitar.
- El calendario social (`repositorio_calendario.dart`) se arma con lecturas
  normales de `venue_plans` y `posts`: hereda los bloqueos de sus políticas.
  No hagas una función `security definer` para él sin repetir esa regla.
- Las pestañas principales tienen la barra flotando encima: lo que desplaza
  en ellas termina con `context.holguraInferior` o el último elemento queda
  tapado.

- Las migraciones de la parte social **se aplicaron directamente al proyecto
  remoto** y no están en `supabase/migrations/`. Para bajarlas:
  `npx supabase login`, `npx supabase link --project-ref bfqzabpgtehncnbxtslg`,
  `npx supabase db pull`.
- Falta activar la protección de contraseñas filtradas en el panel de
  Supabase (Auth → Passwords).
- **`parties` concede privilegios columna a columna.** Cada columna nueva hay
  que concederla a mano o el alta de previas se cae entera con un error de
  permisos que no dice qué columna falta. Ya pasó una vez con `is_public`.
- Un perfil se considera completo cuando tiene fecha de nacimiento, y sin
  perfil completo la política impide crear previas.
- El rol de moderador (`profiles.is_moderator`) solo se pone desde el panel de
  Supabase; la aplicación no puede escribirlo.
- Las pruebas de seguridad son tres: `supabase/tests/seguridad.sql` (16, el
  núcleo), `seguridad_social.sql` (18, la capa social) y `seguridad_retos.sql`
  (23, cierre de escrituras y el juego). Se pegan en el editor SQL y deben
  salir todas en PASA.
- `posts`, `join_requests`, `direct_messages` y `venues` también conceden
  privilegios **columna a columna** desde septiembre de 2026, igual que
  `parties`. Una columna nueva que escriba la app hay que concederla a mano.
- `posts.media_url` tiene que apuntar al cubo `publicaciones` del proyecto
  (salvo `is_demo`). Si cambia el proyecto, cambia la restricción.
- Las fechas de "la noche" en el servidor salen de `privado.noche_actual()`
  (Europa/Madrid, antes de las 6 cuenta el día anterior). No uses
  `current_date`: el servidor está en UTC.
- El movimiento vive en `lib/app/movimiento.dart` (curva, duraciones y
  `Pulsable`). Respeta `MediaQuery.disableAnimations`.
- Los iconos se generan con `python tool/generar_iconos.py`.
- Nada de esto se ha probado con una sesión real: compila, los tests pasan y
  las funciones devuelven datos por SQL, pero la primera subida de foto y el
  primer mensaje hay que hacerlos a mano.
- Los goldens de `test/` usan la Roboto del SDK cargada a mano; si un texto
  sale como bloques blancos es que ese `TextStyle` fija familia nula y no
  hereda. Es artefacto de test, no fallo de la app.
- `flutter build web --no-tree-shake-icons` es la forma rápida de comprobar
  que compila de verdad; `flutter analyze` no lo pilla todo.
- No hay emulador Android ni iOS en esta máquina. Solo Windows, Chrome y Edge.

## Racha de fiestas

- La regla vive en `lib/domain/racha/regla_de_racha.dart` (Dart puro, probado en
  `test/racha_regla_test.dart`): semanas lunes-domingo con al menos una noche,
  un comodín por racha, hitos 3/5/10/20, noche = hora de Madrid menos 6 h como
  `privado.noche_actual()`.
- Se calcula en el teléfono con `RepositorioCalendario.fechasDeNoches`; la RPC
  `mi_racha` que llamaba el cliente nunca estuvo en las migraciones y se quitó.
  No hay migración. `TarjetaRacha` (perfil) celebra los hitos y recuerda el
  último celebrado en `SharedPreferences`.

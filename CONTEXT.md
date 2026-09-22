# Contexto de Previa

Léeme antes de tocar nada. Está escrito para que una sesión nueva no tenga
que releer medio proyecto para entenderlo.

## Qué es

Red social de proximidad para salir de fiesta. TFG de 2º de DAM, entrega en
junio de 2026. La idea: que la gente deje de salir siempre con los mismos.

Cuatro pestañas:

1. **Feed** — la noche contada en fotos y vídeos. Es la pantalla de entrada.
2. **Mapa** — previas con plazas libres cerca de ti, pides plaza y te aceptan.
3. **Noche** — a qué discoteca va la gente esta noche, y su entrada.
4. **Perfil** — el tuyo, tus noches, tus solicitudes y los ajustes.

Alrededor: perfiles públicos, seguir gente, código QR, buscador y mensajes
directos.

## Stack

Flutter (Android, iOS, web) · Riverpod · go_router · Supabase (Postgres 17 +
PostGIS) · flutter_map sobre teselas oscuras de CARTO.

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

Referencias fijadas por el usuario: **Instagram, TikTok, BeReal, Discord**.
No se busca ser original, se busca estar a ese nivel.

- La imagen ocupa el marco. Las caras están siempre presentes.
- **Amarillo `#FFE500` sobre negro puro `#000000`.** Sobre el amarillo el
  texto va en negro, nunca en blanco (`ColoresPrevia.sobrePrimario`).
- Verde `#35E07F` significa "queda sitio" o "está disponible".
- Esquinas generosas: `radio` 16, `radioGrande` 24, `pastilla` para todo lo
  que sea etiqueta, estado o avatar.
- Tipografía del sistema. Nada de fuentes de display.
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

Funciones: `feed_publicaciones`, `locales_de_la_noche`, `quien_va`,
`mis_conversaciones`.
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
- Las pruebas de seguridad son dos: `supabase/tests/seguridad.sql` (16, el
  núcleo) y `seguridad_social.sql` (18, la capa social). Se pegan en el editor
  SQL y deben salir todas en PASA.
- Nada de esto se ha probado con una sesión real: compila, los tests pasan y
  las funciones devuelven datos por SQL, pero la primera subida de foto y el
  primer mensaje hay que hacerlos a mano.
- Los goldens de `test/` usan la Roboto del SDK cargada a mano; si un texto
  sale como bloques blancos es que ese `TextStyle` fija familia nula y no
  hereda. Es artefacto de test, no fallo de la app.
- `flutter build web --no-tree-shake-icons` es la forma rápida de comprobar
  que compila de verdad; `flutter analyze` no lo pilla todo.
- No hay emulador Android ni iOS en esta máquina. Solo Windows, Chrome y Edge.

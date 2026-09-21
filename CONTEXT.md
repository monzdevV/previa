# Contexto de Previa

Léeme antes de tocar nada. Está escrito para que una sesión nueva no tenga
que releer medio proyecto para entenderlo.

## Qué es

Red social de proximidad para salir de fiesta. TFG de 2º de DAM, entrega en
junio de 2026. La idea: que la gente deje de salir siempre con los mismos.

Tres capas de producto:

1. **Feed** — la noche contada en fotos y vídeos. Es la pantalla de entrada.
2. **Mapa** — previas con plazas libres cerca de ti, pides plaza y te aceptan.
3. **Noche** — a qué discoteca va la gente esta noche, y su entrada.

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

Funciones: `feed_publicaciones`, `locales_de_la_noche`, `quien_va`.
Cubos de Storage: `publicaciones` y `avatares`, públicos de lectura, y cada
quien solo escribe en su carpeta `<uid>/`.

`privado.hay_bloqueo()` vive fuera de `public` a propósito: las políticas la
llaman pero no debe ser una ruta de la API.

## Pendiente, por orden

1. **Modo claro.** Los colores están escritos a fuego en ~200 sitios como
   constantes estáticas. Hacerlo bien exige pasarlos a `ThemeExtension`; no
   es un interruptor.
2. **Foto de perfil**: el cubo `avatares` existe, falta la subida en editar
   perfil.
3. **Calendario de noches**: `RepositorioSocial.misNoches()` ya devuelve los
   datos, falta la pantalla.
4. **Interruptor público/privado** al crear previa (`parties.is_public` ya
   existe en base de datos).
5. Notificaciones push, login con Google, caducidad automática de previas.

## Cosas que te van a morder

- Las migraciones de la parte social **se aplicaron directamente al proyecto
  remoto** y no están en `supabase/migrations/`. Para bajarlas:
  `npx supabase login`, `npx supabase link --project-ref bfqzabpgtehncnbxtslg`,
  `npx supabase db pull`.
- Falta activar la protección de contraseñas filtradas en el panel de
  Supabase (Auth → Passwords).
- Los goldens de `test/` usan la Roboto del SDK cargada a mano; si un texto
  sale como bloques blancos es que ese `TextStyle` fija familia nula y no
  hereda. Es artefacto de test, no fallo de la app.
- `flutter build web --no-tree-shake-icons` es la forma rápida de comprobar
  que compila de verdad; `flutter analyze` no lo pilla todo.
- No hay emulador Android ni iOS en esta máquina. Solo Windows, Chrome y Edge.

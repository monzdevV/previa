# 3. Modelo de datos

Base de datos PostgreSQL gestionada por Supabase, con la extensión **PostGIS** activada
para las consultas geográficas.

## Diagrama de relaciones

```
auth.users (gestionada por Supabase)
     │ 1:1
     ▼
  profiles ──────┬──────────────┬─────────────┬──────────────┐
     │ 1:N       │ N:M          │ 1:N         │ 1:N          │ 1:N
     ▼           ▼              ▼             ▼              ▼
  parties   party_members  join_requests   messages    reports / blocks
     │                                         ▲
     │ 1:N                                     │
     └──────────────── chats ──────────────────┘
```

## Tablas

### `profiles`
Extiende la tabla de usuarios de Supabase con los datos públicos del perfil.

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` PK | Referencia a `auth.users.id` |
| `username` | `text` único | Identificador público |
| `display_name` | `text` | Nombre visible |
| `avatar_url` | `text` | Ruta en Supabase Storage |
| `bio` | `text` | Máximo 280 caracteres |
| `birth_date` | `date` | **Nunca se expone**, solo se deriva la edad |
| `is_verified` | `boolean` | Mayoría de edad comprobada |
| `reputation` | `numeric` | Media de valoraciones recibidas |
| `created_at` | `timestamptz` | |

> La fecha de nacimiento no se envía nunca al cliente. Una vista expone únicamente la
> edad en años, que es el dato mínimo necesario para la funcionalidad.

### `parties`
El objeto central: una previa.

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` PK | |
| `host_id` | `uuid` FK → profiles | Organizador |
| `title` | `text` | |
| `description` | `text` | |
| `vibe` | `text[]` | Etiquetas: reggaeton, tranqui, techno… |
| `area_label` | `text` | Zona legible: "Triana", "Centro" |
| `location` | `geography(Point,4326)` | **Coordenadas exactas, acceso restringido** |
| `location_fuzzed` | `geography(Point,4326)` | Desplazada ~300 m, de acceso público |
| `starts_at` | `timestamptz` | |
| `spots_total` | `smallint` | Plazas ofertadas |
| `spots_taken` | `smallint` | Plazas ya ocupadas |
| `min_age` / `max_age` | `smallint` | Franja de edad deseada |
| `status` | `enum` | `open`, `full`, `closed`, `cancelled` |
| `created_at` | `timestamptz` | |

### `join_requests`
Una solicitud de plaza. El grupo se pide entero, no persona a persona.

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` PK | |
| `party_id` | `uuid` FK → parties | |
| `requester_id` | `uuid` FK → profiles | Quien solicita en nombre del grupo |
| `group_size` | `smallint` | Cuántos van |
| `message` | `text` | Presentación breve |
| `status` | `enum` | `pending`, `accepted`, `rejected`, `cancelled` |
| `created_at` / `responded_at` | `timestamptz` | |

Restricción única sobre `(party_id, requester_id)` mientras la solicitud esté pendiente,
para impedir el envío repetido de solicitudes.

### `party_members`
Quién está finalmente dentro. Se rellena mediante *trigger* al aceptar una solicitud.

| Columna | Tipo | Notas |
|---|---|---|
| `party_id` | `uuid` FK | Clave primaria compuesta |
| `profile_id` | `uuid` FK | Clave primaria compuesta |
| `role` | `enum` | `host`, `guest` |
| `joined_at` | `timestamptz` | |

### `messages`
Mensajería en tiempo real, asociada a una previa.

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` PK | |
| `party_id` | `uuid` FK | |
| `sender_id` | `uuid` FK | |
| `body` | `text` | |
| `created_at` | `timestamptz` | |

### `reports` y `blocks`
Infraestructura de seguridad. Un reporte se revisa; un bloqueo es inmediato y unilateral.

| `reports` | Tipo |
|---|---|
| `id`, `reporter_id`, `reported_id`, `party_id` | `uuid` |
| `reason` | `enum`: acoso, perfil falso, menor de edad, contenido inapropiado, otro |
| `details` | `text` |
| `status` | `enum`: abierto, revisado, cerrado |

| `blocks` | Tipo |
|---|---|
| `blocker_id`, `blocked_id` | `uuid`, clave primaria compuesta |

### `ratings`
Valoración mutua tras la previa. Alimenta el campo `reputation` del perfil.

| Columna | Tipo | Notas |
|---|---|---|
| `party_id`, `rater_id`, `rated_id` | `uuid` | Clave primaria compuesta |
| `score` | `smallint` | De 1 a 5 |
| `comment` | `text` | Opcional |

## La consulta central

Buscar previas abiertas cerca del usuario, devolviendo siempre la ubicación difuminada:

```sql
select  p.id, p.title, p.area_label, p.vibe,
        p.starts_at, p.spots_total - p.spots_taken as plazas_libres,
        st_y(p.location_fuzzed::geometry) as lat,
        st_x(p.location_fuzzed::geometry) as lng,
        st_distance(p.location_fuzzed, st_point(:lng, :lat)::geography) as distancia_m
from    parties p
where   p.status = 'open'
  and   p.starts_at between now() and now() + interval '12 hours'
  and   st_dwithin(p.location_fuzzed, st_point(:lng, :lat)::geography, :radio_m)
  and   p.host_id not in (select blocked_id from blocks where blocker_id = auth.uid())
  and   auth.uid() not in (select blocker_id from blocks where blocked_id = p.host_id)
order by distancia_m
limit 50;
```

Un índice GiST sobre `location_fuzzed` mantiene esta consulta rápida aunque la tabla
crezca.

## Políticas de seguridad (Row Level Security)

Todas las tablas tienen RLS activado. Las reglas fundamentales:

| Tabla | Regla |
|---|---|
| `parties` | Cualquiera autenticado lee las previas abiertas; solo el anfitrión modifica la suya |
| `parties.location` | **Solo** el anfitrión y los miembros aceptados acceden a la ubicación exacta |
| `join_requests` | Solo el solicitante y el anfitrión ven la solicitud |
| `messages` | Solo los miembros aceptados de esa previa leen y escriben |
| `profiles` | Lectura pública de los campos públicos; `birth_date` nunca se expone |
| `blocks` | Un usuario bloqueado deja de ver por completo al que lo bloqueó |

> Que la ubicación exacta esté protegida por una política de base de datos, y no por una
> comprobación en la aplicación, es la decisión de diseño más importante del proyecto.

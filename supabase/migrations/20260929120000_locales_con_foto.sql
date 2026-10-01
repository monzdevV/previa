-- Locales con foto, logo, eslogan y coordenadas para la pestaña ¿Vas?
--
-- La pestaña pasa de ser una lista de carteles de color a una lista de
-- fotos a sangre, como las guías de ocio que la gente ya usa: lo que decide
-- entrar en un sitio es verlo por dentro. Para eso `venues` necesita una
-- foto de portada, un logo y una frase corta, y la RPC tiene que devolver
-- dónde está cada local para ordenarlos por cercanía.
--
-- Depende de 20260928120000_vas_y_redes.sql (venue_maybes, venue_plans.status
-- y privado.noche_actual): se aplica después de ella.
--
-- La app tolera que esta migración no esté aplicada: si la RPC no trae estas
-- columnas, cada tarjeta cae a un fondo propio y al nombre en grande, y sin
-- coordenadas no se enseña distancia.

-- 1. Columnas nuevas -------------------------------------------------------
-- Solo https: una URL http rompería en la web por contenido mixto y en iOS
-- por ATS, y así no se cuela un `javascript:` ni un fichero local.
-- El eslogan es corto porque va en una sola línea bajo el logo.

alter table public.venues
  add column if not exists cover_url text
    check (cover_url ~ '^https://'),
  add column if not exists logo_url text
    check (logo_url ~ '^https://'),
  add column if not exists tagline text
    check (char_length(tagline) between 1 and 80);

-- `venues` concede privilegios columna a columna: sin esto la RPC, que es de
-- invocador, falla entera con un error de permisos.
-- Solo lectura a propósito: la foto y el logo los pone quien administra el
-- local desde el panel. Dejar que cualquiera escriba una URL de imagen en la
-- ficha de un local ajeno sería abrir la puerta a colgar lo que sea en la
-- pestaña más vista de la app.
grant select (cover_url, logo_url, tagline) on public.venues to authenticated;

-- 2. locales_de_la_noche con foto y coordenadas -----------------------------
-- La distancia NO se calcula aquí: haría falta mandar la posición de quien
-- mira, y la app no la envía a ningún sitio (ver ServicioUbicacion). Se
-- devuelven las coordenadas del local, que son públicas (es un negocio
-- abierto al público, no la casa de nadie), y el teléfono ordena.
-- Cambia la forma de lo que devuelve, así que hay que borrarla y crearla.

drop function if exists public.locales_de_la_noche(text, date);

create function public.locales_de_la_noche(
  ciudad text,
  noche  date default privado.noche_actual()
)
returns table (
  id uuid, name text, city text, area_label text, ticket_url text,
  instagram text, cover_url text, logo_url text, tagline text,
  lat double precision, lng double precision,
  van bigint, quiza bigint, aqui bigint, mi_estado text, caras jsonb
)
language sql
stable
set search_path = public
as $$
  select v.id, v.name, v.city, v.area_label, v.ticket_url, v.instagram,
         v.cover_url, v.logo_url, v.tagline,
         extensions.st_y(v.location::extensions.geometry) as lat,
         extensions.st_x(v.location::extensions.geometry) as lng,
         (select count(*) from public.venue_plans p
           where p.venue_id = v.id and p.night = noche) as van,
         (select count(*) from public.venue_maybes m
           where m.venue_id = v.id and m.night = noche) as quiza,
         (select count(*) from public.venue_plans p
           where p.venue_id = v.id and p.night = noche
             and p.status = 'aqui') as aqui,
         coalesce(
           (select p.status from public.venue_plans p
             where p.venue_id = v.id and p.night = noche
               and p.profile_id = auth.uid()),
           (select 'quiza' from public.venue_maybes m
             where m.venue_id = v.id and m.night = noche
               and m.profile_id = auth.uid())
         ) as mi_estado,
         -- Cinco caras como mucho, primero la gente que sigues: una cara
         -- conocida decide la noche más que el número total.
         coalesce((
           select jsonb_agg(jsonb_build_object(
                    'id', c.id, 'nombre', c.display_name, 'avatar', c.avatar_url))
             from (
               select a.id, a.display_name, a.avatar_url
                 from public.venue_plans p
                 join public.profiles a on a.id = p.profile_id
                where p.venue_id = v.id and p.night = noche
                  and p.profile_id <> coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000')
                order by exists (select 1 from public.follows f
                                  where f.follower_id = auth.uid()
                                    and f.followee_id = a.id) desc,
                         (p.status = 'aqui') desc,
                         p.created_at desc
                limit 5
             ) c
         ), '[]'::jsonb) as caras
    from public.venues v
   where ciudad is null or v.city ilike ciudad
   -- Sin posición del teléfono, este es el orden que se ve: donde va más gente.
   order by van desc, v.name;
$$;

revoke all on function public.locales_de_la_noche(text, date) from public, anon;
grant execute on function public.locales_de_la_noche(text, date) to authenticated, service_role;

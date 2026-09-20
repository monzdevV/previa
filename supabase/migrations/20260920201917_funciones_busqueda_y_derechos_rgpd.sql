-- Previa · Migracion 6
-- Consulta geografica principal, acceso controlado a la ubicacion exacta
-- y funciones de derechos RGPD.

-- Busqueda de previas cercanas ----------------------------------------------
-- SECURITY INVOKER (por defecto): pasa por RLS, asi que los bloqueos y la
-- visibilidad se aplican solos. Devuelve siempre la ubicacion difuminada.

create or replace function public.previas_cerca(
  p_lat        double precision,
  p_lng        double precision,
  p_radio_m    integer default 5000,
  p_horas      integer default 12,
  p_plazas_min smallint default 1
)
returns table (
  id            uuid,
  title         text,
  description   text,
  vibe          text[],
  area_label    text,
  lat           double precision,
  lng           double precision,
  distancia_m   double precision,
  starts_at     timestamptz,
  plazas_libres smallint,
  min_age       smallint,
  max_age       smallint,
  host_id       uuid,
  host_nombre   text,
  host_avatar   text,
  host_reputacion numeric
)
language sql
stable
set search_path = public, extensions
as $$
  select
    p.id,
    p.title,
    p.description,
    p.vibe,
    p.area_label,
    extensions.ST_Y(p.location_fuzzed::extensions.geometry) as lat,
    extensions.ST_X(p.location_fuzzed::extensions.geometry) as lng,
    extensions.ST_Distance(
      p.location_fuzzed,
      extensions.ST_SetSRID(extensions.ST_Point(p_lng, p_lat), 4326)::extensions.geography
    ) as distancia_m,
    p.starts_at,
    (p.spots_total - p.spots_taken)::smallint as plazas_libres,
    p.min_age,
    p.max_age,
    p.host_id,
    h.display_name,
    h.avatar_url,
    h.reputation
  from public.parties p
  join public.profiles h on h.id = p.host_id
  where p.status = 'open'
    and p.starts_at between now() and now() + make_interval(hours => p_horas)
    and (p.spots_total - p.spots_taken) >= p_plazas_min
    and extensions.ST_DWithin(
          p.location_fuzzed,
          extensions.ST_SetSRID(extensions.ST_Point(p_lng, p_lat), 4326)::extensions.geography,
          p_radio_m
        )
  order by distancia_m
  limit 50;
$$;

-- Ubicacion exacta -----------------------------------------------------------
-- La unica puerta a la columna protegida. El rol authenticated no tiene
-- privilegio SELECT sobre parties.location, asi que esta funcion es
-- literalmente el unico camino, y comprueba la pertenencia antes de abrirla.

create or replace function public.ubicacion_exacta(p_party uuid)
returns table (lat double precision, lng double precision)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
begin
  if not public.es_miembro(p_party, auth.uid()) then
    raise exception 'Solo los asistentes aceptados pueden ver la direccion exacta.'
      using errcode = 'insufficient_privilege';
  end if;

  return query
    select extensions.ST_Y(p.location::extensions.geometry),
           extensions.ST_X(p.location::extensions.geometry)
    from public.parties p
    where p.id = p_party;
end;
$$;

-- Mi propia fecha de nacimiento ----------------------------------------------
-- Nadie puede leer birth_date por SELECT, ni siquiera la suya.
-- Esta funcion permite al titular consultarla para editar su perfil.

create or replace function public.mi_fecha_nacimiento()
returns date
language sql
stable
security definer
set search_path = public
as $$
  select birth_date from public.profiles where id = auth.uid();
$$;

-- RGPD: derecho de acceso y portabilidad (art. 15 y 20) ----------------------

create or replace function public.exportar_mis_datos()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'perfil',       (select to_jsonb(p) from public.profiles p where p.id = auth.uid()),
    'previas',      (select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
                     from (select id, title, description, area_label, starts_at,
                                  spots_total, status, created_at
                           from public.parties where host_id = auth.uid()) x),
    'asistencias',  (select coalesce(jsonb_agg(to_jsonb(m)), '[]'::jsonb)
                     from public.party_members m where m.profile_id = auth.uid()),
    'solicitudes',  (select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
                     from public.join_requests r where r.requester_id = auth.uid()),
    'mensajes',     (select coalesce(jsonb_agg(to_jsonb(ms)), '[]'::jsonb)
                     from public.messages ms where ms.sender_id = auth.uid()),
    'bloqueos',     (select coalesce(jsonb_agg(to_jsonb(b)), '[]'::jsonb)
                     from public.blocks b where b.blocker_id = auth.uid()),
    'valoraciones', (select coalesce(jsonb_agg(to_jsonb(v)), '[]'::jsonb)
                     from public.ratings v where v.rater_id = auth.uid()),
    'exportado_el', now()
  );
$$;

-- RGPD: derecho de supresion (art. 17) ---------------------------------------
-- Borra auth.users; el resto cae en cascada.

create or replace function public.eliminar_mi_cuenta()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'No hay sesion activa.' using errcode = 'insufficient_privilege';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

-- Permisos de ejecucion -------------------------------------------------------

revoke all on function public.difuminar_ubicacion(extensions.geography, double precision) from public, anon, authenticated;
revoke all on function public.caducar_previas() from public, anon, authenticated;

grant execute on function public.previas_cerca(double precision, double precision, integer, integer, smallint) to authenticated;
grant execute on function public.ubicacion_exacta(uuid)   to authenticated;
grant execute on function public.mi_fecha_nacimiento()    to authenticated;
grant execute on function public.exportar_mis_datos()     to authenticated;
grant execute on function public.eliminar_mi_cuenta()     to authenticated;
grant execute on function public.edad(uuid)               to authenticated;

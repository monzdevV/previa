-- ¿Vas? y redes del perfil.
--
-- El calendario social no necesita nada nuevo: lo arma el cliente con
-- lecturas de planes y publicaciones que las politicas ya permiten.
--
-- Todo es aditivo: ninguna columna ni fila existente cambia de significado.
-- Un plan de `venue_plans` sigue queriendo decir "va", asi que el juego, la
-- sala y el calendario, que ya lo leen asi, no se tocan.

-- 1. Como vas ---------------------------------------------------------------
-- "Voy", "voy mas tarde" y "estoy aqui" son formas de ir: viven en el plan.

alter table public.venue_plans
  add column if not exists status text not null default 'voy'
  check (status in ('voy', 'tarde', 'aqui'));

grant select (status), insert (status) on public.venue_plans to authenticated;

-- 2. Quiza ------------------------------------------------------------------
-- "Quiza" va aparte a proposito: no es ir. No cuenta como salida, no abre la
-- sala del local y no te hace objetivo de un reto de No hay huevos. Si fuera
-- un estado mas del plan, cada funcion que lee planes tendria que acordarse
-- de descontarlo, y bastaria con que una se olvidara.

create table if not exists public.venue_maybes (
  venue_id   uuid not null references public.venues (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  night      date not null,
  created_at timestamptz not null default now(),
  primary key (venue_id, profile_id, night)
);

alter table public.venue_maybes enable row level security;

create policy "los quiza se ven salvo bloqueo" on public.venue_maybes
  for select to authenticated
  using (profile_id = auth.uid() or not privado.hay_bloqueo(profile_id));

create policy "solo dices quiza tu" on public.venue_maybes
  for insert to authenticated
  with check (profile_id = auth.uid());

create policy "solo borras tus quiza" on public.venue_maybes
  for delete to authenticated
  using (profile_id = auth.uid());

revoke all on public.venue_maybes from anon, authenticated;
grant select, delete on public.venue_maybes to authenticated;
grant insert (venue_id, profile_id, night) on public.venue_maybes to authenticated;

-- La misma guardia que los planes: solo se habla de esta noche.
create trigger venue_maybes_guardia
  before insert on public.venue_maybes
  for each row execute function privado.guardia_de_plan();

-- 3. Decir si vas, de una vez ------------------------------------------------
-- Pasar de "quiza" a "estoy aqui" son dos tablas. Si el cliente lo hiciera en
-- dos peticiones, un fallo entre ambas te dejaria en las dos o en ninguna.
-- Nulo es "no voy".

create or replace function public.decir_si_voy(
  local  uuid,
  estado text,
  noche  date default privado.noche_actual()
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  yo uuid := auth.uid();
begin
  if yo is null then
    raise exception 'Hace falta iniciar sesion.' using errcode = 'insufficient_privilege';
  end if;
  if estado is not null and estado not in ('voy', 'tarde', 'aqui', 'quiza') then
    raise exception 'Estado desconocido.' using errcode = 'check_violation';
  end if;

  if estado is null or estado = 'quiza' then
    delete from public.venue_plans
     where venue_id = local and profile_id = yo and night = noche;
  end if;
  if estado is distinct from 'quiza' then
    delete from public.venue_maybes
     where venue_id = local and profile_id = yo and night = noche;
  end if;

  if estado = 'quiza' then
    insert into public.venue_maybes (venue_id, profile_id, night)
    values (local, yo, noche)
    on conflict do nothing;
  elsif estado is not null then
    -- Actualizar y no borrar e insertar: el plan conserva su hora de alta, y
    -- el reto que ya te haya tocado en ese local sigue teniendo sentido.
    insert into public.venue_plans (venue_id, profile_id, night, status)
    values (local, yo, noche, estado)
    on conflict (venue_id, profile_id, night)
    do update set status = excluded.status;
  end if;
end;
$$;

revoke all on function public.decir_si_voy(uuid, text, date) from public, anon;
grant execute on function public.decir_si_voy(uuid, text, date) to authenticated;

-- 4. Los locales de la noche, con caras -------------------------------------
-- Cambia la forma de lo que devuelve, asi que hay que borrarla y crearla.
-- Sigue siendo de invocador: las politicas de bloqueo se aplican solas.

drop function if exists public.locales_de_la_noche(text, date);

create function public.locales_de_la_noche(
  ciudad text,
  noche  date default privado.noche_actual()
)
returns table (
  id uuid, name text, city text, area_label text, ticket_url text,
  instagram text, van bigint, quiza bigint, aqui bigint, mi_estado text,
  caras jsonb
)
language sql
stable
set search_path = public
as $$
  select v.id, v.name, v.city, v.area_label, v.ticket_url, v.instagram,
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
         -- conocida decide la noche mas que el numero total.
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
   order by van desc, v.name;
$$;

revoke all on function public.locales_de_la_noche(text, date) from public, anon;
grant execute on function public.locales_de_la_noche(text, date) to authenticated, service_role;

-- 5. Quien va, con como va ---------------------------------------------------

drop function if exists public.quien_va(uuid, date);

create function public.quien_va(
  local uuid,
  noche date default privado.noche_actual()
)
returns table (
  id uuid, username text, display_name text, avatar_url text,
  le_sigo boolean, estado text
)
language sql
stable
set search_path = public
as $$
  select a.id, a.username, a.display_name, a.avatar_url,
         exists (
           select 1 from public.follows f
            where f.follower_id = auth.uid() and f.followee_id = a.id
         ) as le_sigo,
         g.estado
    from (
      select p.profile_id, p.status as estado from public.venue_plans p
       where p.venue_id = local and p.night = noche
      union all
      select m.profile_id, 'quiza' from public.venue_maybes m
       where m.venue_id = local and m.night = noche
    ) g
    join public.profiles a on a.id = g.profile_id
   order by case g.estado when 'aqui' then 0 when 'voy' then 1
                          when 'tarde' then 2 else 3 end,
            le_sigo desc, a.display_name
   limit 100;
$$;

revoke all on function public.quien_va(uuid, date) from public, anon;
grant execute on function public.quien_va(uuid, date) to authenticated, service_role;

-- 6. Redes en el perfil ------------------------------------------------------

alter table public.profiles
  add column if not exists tiktok text
    check (tiktok ~ '^[A-Za-z0-9_.]{2,30}$'),
  add column if not exists x_handle text
    check (x_handle ~ '^[A-Za-z0-9_]{1,15}$');

grant select (tiktok, x_handle), update (tiktok, x_handle)
  on public.profiles to authenticated;

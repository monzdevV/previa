-- Minijuego "No hay huevos": la aplicacion te pone un reto con alguien que
-- esta en tu mismo local esta noche y lo cumples con una foto juntos.
--
-- Todo el reparto de retos pasa por aqui y no por el cliente: quien te toca,
-- cuantos retos llevas y si de verdad estas dentro se deciden en la base de
-- datos. El cliente solo pide y ensena.

-- La noche empieza al anochecer: lo que pasa antes de las 6 de la manana
-- sigue siendo la noche anterior. Es la misma regla que aplica la app al
-- decir "voy esta noche", pero calculada en el servidor para que nadie pueda
-- jugar en una noche que no es la suya cambiando la hora del telefono.
create or replace function privado.noche_actual()
returns date
language sql
stable
set search_path = ''
as $$
  select ((now() at time zone 'Europe/Madrid') - interval '6 hours')::date;
$$;

-- Salir en los retos de otros es opcional. Por defecto si, porque decir que
-- vas a un local ya es aceptar que la gente de alli te vea; quien no quiera
-- lo apaga en ajustes y deja de aparecer al momento.
alter table public.profiles
  add column if not exists plays_challenges boolean not null default true;

grant select (plays_challenges), update (plays_challenges)
  on public.profiles to authenticated;

create type public.challenge_status as enum (
  'activo',   -- repartido y sin cumplir
  'hecho',    -- cumplido con foto
  'rajado',   -- "no hay huevos": el jugador se ha echado atras
  'caducado'  -- se acabo la noche sin cumplirlo
);

create table public.challenges (
  id          uuid primary key default gen_random_uuid(),
  player_id   uuid not null references public.profiles (id) on delete cascade,
  target_id   uuid not null references public.profiles (id) on delete cascade,
  venue_id    uuid not null references public.venues (id) on delete cascade,
  night       date not null,
  prompt      text not null check (char_length(prompt) between 10 and 240),
  -- Si el texto lo escribio la IA o salio de la lista de reserva. Sirve
  -- para medir si la IA aporta algo frente a las plantillas.
  source      text not null check (source in ('ia', 'plantilla')),
  status      public.challenge_status not null default 'activo',
  post_id     uuid references public.posts (id) on delete set null,
  created_at  timestamptz not null default now(),
  resolved_at timestamptz,
  constraint challenges_no_contigo_mismo check (player_id <> target_id)
);

-- Un solo reto abierto por persona. Ademas de la regla de juego, es lo que
-- impide que dos toques seguidos al sticker creen dos retos a la vez.
create unique index challenges_uno_activo
  on public.challenges (player_id) where status = 'activo';
create index challenges_jugador_noche on public.challenges (player_id, night);
create index challenges_objetivo on public.challenges (target_id);
create index challenges_publicacion on public.challenges (post_id)
  where post_id is not null;

alter table public.challenges enable row level security;

-- El jugador ve sus retos. El objetivo solo ve los cumplidos: enterarse
-- antes estropearia la sorpresa, y despues es justo que sepa que sale en
-- una foto.
create policy "ves tus retos y los cumplidos contigo"
  on public.challenges for select to authenticated
  using (
    player_id = auth.uid()
    or (target_id = auth.uid() and status = 'hecho')
  );

-- Ni una politica de escritura: se escribe solo desde las funciones.
revoke all on public.challenges from anon, authenticated;
grant select on public.challenges to authenticated;

-- Tope de retos por persona y noche, contando los que se rajan. Evita que
-- alguien pase retos sin parar hasta que le toque quien quiere, y acota lo
-- que cuesta la IA por persona.
create or replace function privado.retos_por_noche()
returns integer
language sql
immutable
set search_path = ''
as $$ select 8 $$;

-- Las comprobaciones que comparten pedir y crear un reto. Lanza un codigo
-- en mayusculas que la funcion de borde traduce y la app entiende.
create or replace function privado.validar_reto(jugador uuid, local uuid)
returns date
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_noche date := privado.noche_actual();
begin
  -- Lo que se quedo abierto de otras noches no bloquea la de hoy.
  update public.challenges
     set status = 'caducado', resolved_at = now()
   where player_id = jugador and status = 'activo' and night < v_noche;

  if not exists (select 1 from public.venues where id = local) then
    raise exception 'NO_EXISTE_LOCAL';
  end if;

  if not exists (
    select 1 from public.venue_plans
     where venue_id = local and profile_id = jugador and night = v_noche
  ) then
    raise exception 'NO_VAS';
  end if;

  if exists (
    select 1 from public.challenges
     where player_id = jugador and status = 'activo'
  ) then
    raise exception 'YA_TIENES_RETO';
  end if;

  if (
    select count(*) from public.challenges
     where player_id = jugador and night = v_noche
  ) >= privado.retos_por_noche() then
    raise exception 'LIMITE_NOCHE';
  end if;

  return v_noche;
end;
$$;

-- Quien puede tocarte: esta en el mismo local esta noche, juega, no es una
-- cuenta de demostracion (no hay nadie detras con quien hacerse la foto) y
-- no hay bloqueo en ningun sentido.
create or replace function privado.hay_objetivo(jugador uuid, local uuid, noche date)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.venue_plans vp
      join public.profiles p on p.id = vp.profile_id
     where vp.venue_id = local and vp.night = noche
       and vp.profile_id <> jugador
       and p.plays_challenges and not p.is_demo
       and not privado.hay_bloqueo(jugador, p.id)
  );
$$;

-- Paso 1, antes de gastar una llamada a la IA: ¿puede jugar ahora mismo?
-- Devuelve el nombre del local, que es lo unico que se le cuenta a la IA.
--
-- La distancia solo se mira si el local tiene coordenadas. Los moderadores
-- se la saltan para poder probar el juego sin ir hasta alli.
create or replace function public.comprobar_reto(
  jugador uuid,
  local uuid,
  lat double precision default null,
  lng double precision default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_noche date;
  v_local public.venues;
begin
  v_noche := privado.validar_reto(jugador, local);
  select * into v_local from public.venues where id = local;

  if v_local.location is not null
     and not coalesce(
       (select is_moderator from public.profiles where id = jugador), false
     ) then
    if lat is null or lng is null then
      raise exception 'SIN_UBICACION';
    end if;
    if not extensions.st_dwithin(
      v_local.location,
      extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography,
      300
    ) then
      raise exception 'NO_ESTAS_AQUI';
    end if;
  end if;

  if not privado.hay_objetivo(jugador, local, v_noche) then
    raise exception 'NO_HAY_NADIE';
  end if;

  return v_local.name;
end;
$$;

-- Paso 2: elige a quien te toca y guarda el reto. La plantilla trae el
-- hueco {persona} y el nombre se pone aqui, de modo que la IA nunca recibe
-- datos de nadie.
create or replace function public.crear_reto(
  jugador uuid,
  local uuid,
  plantilla text,
  origen text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_noche date;
  v_objetivo public.profiles;
  v_id uuid;
begin
  if plantilla is null
     or position('{persona}' in plantilla) = 0
     or char_length(plantilla) > 200 then
    raise exception 'PLANTILLA_INVALIDA';
  end if;

  -- Serializa las peticiones de una misma persona: sin esto, dos toques a
  -- la vez pasarian los dos el tope de la noche antes de insertar.
  perform pg_advisory_xact_lock(hashtextextended('reto:' || jugador::text, 0));

  v_noche := privado.validar_reto(jugador, local);

  -- Primero quien menos veces te ha tocado esta noche, y entre esos al
  -- azar: asi se va rotando por el local en vez de repetir siempre.
  select p.* into v_objetivo
    from public.venue_plans vp
    join public.profiles p on p.id = vp.profile_id
   where vp.venue_id = local and vp.night = v_noche
     and vp.profile_id <> jugador
     and p.plays_challenges and not p.is_demo
     and not privado.hay_bloqueo(jugador, p.id)
   order by (
     select count(*) from public.challenges c
      where c.player_id = jugador and c.target_id = p.id and c.night = v_noche
   ), random()
   limit 1;

  if v_objetivo.id is null then
    raise exception 'NO_HAY_NADIE';
  end if;

  insert into public.challenges (player_id, target_id, venue_id, night, prompt, source)
  values (
    jugador, v_objetivo.id, local, v_noche,
    replace(plantilla, '{persona}', v_objetivo.display_name),
    origen
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- El reto abierto que tienes en este local, con la ficha de a quien buscas.
-- Va con los permisos de quien llama: las politicas ya limitan a lo suyo.
create or replace function public.mi_reto(local uuid)
returns table (
  id uuid,
  texto text,
  origen text,
  creado_en timestamptz,
  objetivo_id uuid,
  objetivo_usuario text,
  objetivo_nombre text,
  objetivo_avatar text,
  objetivo_bio text,
  retos_restantes integer
)
language sql
stable
set search_path = ''
as $$
  select c.id, c.prompt, c.source, c.created_at,
         p.id, p.username, p.display_name, p.avatar_url, p.bio,
         greatest(
           privado.retos_por_noche() - (
             select count(*)::int from public.challenges x
              where x.player_id = auth.uid() and x.night = c.night
           ),
           0
         )
    from public.challenges c
    join public.profiles p on p.id = c.target_id
   where c.player_id = auth.uid()
     and c.venue_id = local
     and c.status = 'activo'
     and c.night = privado.noche_actual()
   limit 1;
$$;

-- Cumplir: la foto tiene que ser tuya, de este local y de esta noche. Se
-- avisa al objetivo, que a partir de aqui puede ver el reto y quitar la
-- foto si no quiere salir.
create or replace function public.completar_reto(reto uuid, publicacion uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reto public.challenges;
begin
  select * into v_reto from public.challenges
   where id = reto and player_id = auth.uid()
   for update;

  if v_reto.id is null then
    raise exception 'NO_EXISTE_RETO';
  end if;
  if v_reto.status <> 'activo' then
    raise exception 'RETO_CERRADO';
  end if;

  if not exists (
    select 1 from public.posts
     where id = publicacion
       and author_id = auth.uid()
       and venue_id = v_reto.venue_id
       and night = v_reto.night
  ) then
    raise exception 'FOTO_INVALIDA';
  end if;

  update public.challenges
     set status = 'hecho', post_id = publicacion, resolved_at = now()
   where id = reto;

  insert into public.notices (profile_id, actor_id, kind, post_id)
  values (v_reto.target_id, v_reto.player_id, 'reto', publicacion);
end;
$$;

-- "No hay huevos": te echas atras. Cuenta para el tope de la noche.
create or replace function public.rajarse(reto uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.challenges
     set status = 'rajado', resolved_at = now()
   where id = reto and player_id = auth.uid() and status = 'activo';

  if not found then
    raise exception 'NO_EXISTE_RETO';
  end if;
end;
$$;

-- Quien sale en la foto de un reto puede quitarla. No haberlo decidido tu
-- no deberia significar tener que aguantarla en la sala.
create or replace function public.quitar_foto_de_reto(reto uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post uuid;
begin
  select post_id into v_post from public.challenges
   where id = reto and target_id = auth.uid() and status = 'hecho';

  if v_post is null then
    raise exception 'NO_EXISTE_RETO';
  end if;

  delete from public.posts where id = v_post;
end;
$$;

-- Superficie de la API: los dos pasos del reparto solo los llama la funcion
-- de borde con la clave de servicio, porque son los que aceptan un jugador
-- por parametro. El resto lo llama la app con la sesion de cada uno.
revoke execute on function privado.noche_actual() from public;
revoke execute on function privado.retos_por_noche() from public;
revoke execute on function privado.validar_reto(uuid, uuid) from public;
revoke execute on function privado.hay_objetivo(uuid, uuid, date) from public;
grant execute on function privado.noche_actual() to authenticated;
grant execute on function privado.retos_por_noche() to authenticated;

revoke execute on function public.comprobar_reto(uuid, uuid, double precision, double precision) from public, anon, authenticated;
revoke execute on function public.crear_reto(uuid, uuid, text, text) from public, anon, authenticated;
grant execute on function public.comprobar_reto(uuid, uuid, double precision, double precision) to service_role;
grant execute on function public.crear_reto(uuid, uuid, text, text) to service_role;

revoke execute on function public.mi_reto(uuid) from public, anon;
revoke execute on function public.completar_reto(uuid, uuid) from public, anon;
revoke execute on function public.rajarse(uuid) from public, anon;
revoke execute on function public.quitar_foto_de_reto(uuid) from public, anon;
grant execute on function public.mi_reto(uuid) to authenticated;
grant execute on function public.completar_reto(uuid, uuid) to authenticated;
grant execute on function public.rajarse(uuid) to authenticated;
grant execute on function public.quitar_foto_de_reto(uuid) to authenticated;

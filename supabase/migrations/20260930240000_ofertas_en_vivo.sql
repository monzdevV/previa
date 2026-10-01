-- Ofertas en vivo: promociones de tiempo limitado de un local para quien esta
-- dentro ahora. Ver docs/ofertas-en-vivo.md.
--
-- SIN APLICAR: escrita para revision. Depende de `vas_y_redes` (estado 'aqui'
-- en venue_plans) y de `privado.noche_actual()`.
--
-- Limite legal: nada que fomente el consumo excesivo de alcohol. Se aplica en
-- tres capas: categorias cerradas sin bebida, copy de la app, y el disparador
-- `privado.guardia_de_oferta` que rechaza el texto de consumo de alcohol.

-- 1. Quien manda en un local -------------------------------------------------
-- `venues` no tiene dueño y los locales los puede proponer cualquiera, asi que
-- el dueño es una tabla aparte que SOLO escribe el equipo (service_role): si
-- un usuario pudiera darse de alta como dueño, cualquiera lanzaria ofertas en
-- el local de otro.

create table if not exists public.venue_owners (
  venue_id   uuid not null references public.venues (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (venue_id, profile_id)
);

alter table public.venue_owners enable row level security;

create policy "cada dueño ve sus locales" on public.venue_owners
  for select to authenticated
  using (profile_id = auth.uid());

revoke all on public.venue_owners from anon, authenticated;
grant select on public.venue_owners to authenticated;

-- 2. Auxiliares de RLS, fuera de la API ---------------------------------------

create or replace function privado.es_dueno_de_local(p_local uuid, p_perfil uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.venue_owners o
    where o.venue_id = p_local and o.profile_id = p_perfil
  );
$$;

create or replace function privado.es_mayor_de_edad(p_perfil uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select p.birth_date <= (current_date - interval '18 years')
    from public.profiles p where p.id = p_perfil
  ), false);
$$;

-- "Estoy aqui" esta noche. Es declarativo; la fuerza la pone el QR de la puerta.
create or replace function privado.esta_en_local(p_local uuid, p_perfil uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.venue_plans v
    where v.venue_id = p_local and v.profile_id = p_perfil
      and v.status = 'aqui'
      -- Solo esta noche. Aqui la tolerancia de "mañana" que si tiene la guardia
      -- de planes dejaria entrar desde casa diciendo "estoy aqui" para mañana.
      and v.night = privado.noche_actual()
  );
$$;

grant execute on function privado.es_dueno_de_local(uuid, uuid) to authenticated;
grant execute on function privado.es_mayor_de_edad(uuid)        to authenticated;
grant execute on function privado.esta_en_local(uuid, uuid)     to authenticated;

-- 3. Ofertas ------------------------------------------------------------------

create table if not exists public.venue_offers (
  id               uuid primary key default gen_random_uuid(),
  venue_id         uuid not null references public.venues (id) on delete cascade,
  created_by       uuid not null references public.profiles (id) on delete cascade,
  -- Cerrada a proposito: no hay categoria de bebida.
  kind             text not null check (kind in (
                     'entrada', 'mesa', 'zona', 'foto', 'guardarropa',
                     'comida', 'experiencia')),
  title            text not null check (char_length(title) between 3 and 60),
  detail           text check (detail is null or char_length(detail) <= 140),
  starts_at        timestamptz not null default now(),
  ends_at          timestamptz not null,
  max_redemptions  integer not null check (max_redemptions between 1 and 500),
  -- 'aqui': basta con haber dicho "estoy aqui". 'qr': hay que escanear el QR
  -- de la puerta, que demuestra presencia fisica.
  verification     text not null default 'qr' check (verification in ('aqui', 'qr')),
  -- Lo que lleva el QR de la puerta. Solo lo lee el dueño, via RPC.
  door_code        text not null default replace(gen_random_uuid()::text, '-', ''),
  cancelled_at     timestamptz,
  created_at       timestamptz not null default now(),
  check (ends_at > starts_at + interval '5 minutes'),
  check (ends_at <= starts_at + interval '120 minutes')
);

create index if not exists venue_offers_local_fin_idx
  on public.venue_offers (venue_id, ends_at desc);

alter table public.venue_offers enable row level security;

-- Las ve el dueño (todas, para su panel) y las personas de +18 que estan en el
-- local ahora mismo, mientras estan activas. Quien no esta no sabe que existen:
-- una oferta para "quien llegue ya" no es un cartel publico.
create policy "ofertas: dueño o presente +18" on public.venue_offers
  for select to authenticated
  using (
    privado.es_dueno_de_local(venue_id, auth.uid())
    or (
      cancelled_at is null
      and now() between starts_at and ends_at
      and privado.es_mayor_de_edad(auth.uid())
      and privado.esta_en_local(venue_id, auth.uid())
    )
  );

create policy "ofertas: solo el dueño crea" on public.venue_offers
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and privado.es_dueno_de_local(venue_id, auth.uid())
  );

-- Editar es, de hecho, cancelar: cambiar el texto o el cupo de una oferta ya
-- vista por la gente seria cambiar las reglas a mitad.
create policy "ofertas: solo el dueño cancela" on public.venue_offers
  for update to authenticated
  using (privado.es_dueno_de_local(venue_id, auth.uid()))
  with check (privado.es_dueno_de_local(venue_id, auth.uid()));

revoke all on public.venue_offers from anon, authenticated;
-- door_code queda fuera del SELECT: quien esta dentro no debe poder leerlo y
-- canjear sin escanear. El dueño lo pide con `codigo_de_puerta`.
grant select (id, venue_id, created_by, kind, title, detail, starts_at,
              ends_at, max_redemptions, verification, cancelled_at, created_at)
  on public.venue_offers to authenticated;
grant insert (venue_id, created_by, kind, title, detail, starts_at, ends_at,
              max_redemptions, verification)
  on public.venue_offers to authenticated;
grant update (cancelled_at) on public.venue_offers to authenticated;

-- 3.1 Guardia: texto, limites y ventana ----------------------------------------

create or replace function privado.guardia_de_oferta()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_activas integer;
  v_noche   integer;
  v_texto   text;
begin
  -- Antes de mirar los limites, se serializa por local: sin esto, dos altas a
  -- la vez ven las dos "1 activa" y entran, dejando tres.
  perform pg_advisory_xact_lock(hashtextextended(new.venue_id::text, 0));

  -- El texto se normaliza antes de buscar: sin tildes, en minusculas, con la
  -- "x" de "2×1" y sin signos ni caracteres invisibles entre letras. Las raices
  -- (beb, cerve...) van sin \m para atrapar "bebed", "cervezas" o "bebidas".
  v_texto := regexp_replace(
    translate(lower(new.title || ' ' || coalesce(new.detail, '')),
              'áéíóúüñ×', 'aeiouunx'),
    '[^a-z0-9 ]', '', 'g');
  if v_texto ~ (
       'barra\s*libre|open\s*bar|\m(2|dos)\s*(x|por)\s*(1|uno)\M|\m3\s*x\s*2\M|'
       'beb(e|es|ed|er|id)|\mcopa|chupit|cubat|combinad|cerve|birra|\mcana\M|'
       'vodka|\mron\M|whisk|\mgin\M|tequila|mojito|trago|litro|alcohol|'
       '\mshots?\M|emborrach|vermu|sangria|sidra|\mvino'
     ) then
    raise exception 'Las ofertas no pueden promover el consumo de alcohol.'
      using errcode = 'check_violation';
  end if;

  -- Se empieza ahora: una oferta "para dentro de una hora" no es en vivo y
  -- permitiria reservar el cupo de ofertas activas.
  if new.starts_at < now() - interval '1 minute'
     or new.starts_at > now() + interval '1 minute' then
    raise exception 'La oferta empieza ahora.' using errcode = 'check_violation';
  end if;

  select count(*) into v_activas
    from public.venue_offers o
   where o.venue_id = new.venue_id and o.cancelled_at is null
     and o.ends_at > now();
  if v_activas >= 2 then
    raise exception 'Ya hay dos ofertas activas en este local.'
      using errcode = 'check_violation';
  end if;

  select count(*) into v_noche
    from public.venue_offers o
   where o.venue_id = new.venue_id
     and o.created_at > now() - interval '12 hours';
  if v_noche >= 6 then
    raise exception 'Se ha alcanzado el maximo de ofertas por noche.'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger venue_offers_guardia
  before insert on public.venue_offers
  for each row execute function privado.guardia_de_oferta();

revoke execute on function privado.guardia_de_oferta() from public;

-- 3.2 Guardia de cancelacion ------------------------------------------------------
-- El unico cambio permitido a una oferta es cancelarla, una vez. Si el dueño
-- pudiera poner `cancelled_at` a null, cancelaria, crearia otras dos y
-- descancelaria, saltandose el tope de ofertas activas.
create or replace function privado.guardia_de_cancelacion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.cancelled_at is not null or new.cancelled_at is null then
    raise exception 'Una oferta cancelada no se puede reactivar.'
      using errcode = 'check_violation';
  end if;
  -- La fecha la pone el servidor: no se admite una inventada por el cliente.
  new.cancelled_at := now();
  return new;
end;
$$;

create trigger venue_offers_cancelacion
  before update on public.venue_offers
  for each row execute function privado.guardia_de_cancelacion();

revoke execute on function privado.guardia_de_cancelacion() from public;

-- 4. Canjes ----------------------------------------------------------------------

create table if not exists public.offer_redemptions (
  id           uuid primary key default gen_random_uuid(),
  offer_id     uuid not null references public.venue_offers (id) on delete cascade,
  profile_id   uuid not null references public.profiles (id) on delete cascade,
  -- Lo que se ensena en la puerta. Corto para poder dictarlo.
  code         text not null unique,
  redeemed_at  timestamptz not null default now(),
  validated_at timestamptz,
  -- Un canje por persona y oferta: la garantia anti-abuso vive aqui y no en la
  -- app, donde bastaria con tocar dos veces.
  unique (offer_id, profile_id)
);

alter table public.offer_redemptions enable row level security;

create policy "canjes: los mios o los de mi local" on public.offer_redemptions
  for select to authenticated
  using (
    profile_id = auth.uid()
    or exists (
      select 1 from public.venue_offers o
      where o.id = offer_id
        and privado.es_dueno_de_local(o.venue_id, auth.uid())
    )
  );

-- Sin politicas de insert ni update: solo escriben las funciones de abajo.
revoke all on public.offer_redemptions from anon, authenticated;
grant select on public.offer_redemptions to authenticated;

-- 5. Funciones de la app -----------------------------------------------------------

-- Canjear. Devuelve el codigo para ensenar en la puerta.
create or replace function public.canjear_oferta(p_oferta uuid, p_codigo_puerta text default null)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  yo       uuid := auth.uid();
  v_oferta public.venue_offers;
  v_codigo text;
  v_usados integer;
begin
  if yo is null then
    raise exception 'Hace falta iniciar sesion.' using errcode = 'insufficient_privilege';
  end if;
  if not privado.es_mayor_de_edad(yo) then
    raise exception 'Previa es solo para mayores de 18 anos.' using errcode = 'insufficient_privilege';
  end if;

  -- Bloquea la fila: dos canjes a la vez no pueden pasarse del cupo.
  select * into v_oferta from public.venue_offers where id = p_oferta for update;
  if not found or v_oferta.cancelled_at is not null
     or now() not between v_oferta.starts_at and v_oferta.ends_at then
    raise exception 'La oferta ya no esta activa.' using errcode = 'check_violation';
  end if;
  if not privado.esta_en_local(v_oferta.venue_id, yo) then
    raise exception 'Tienes que estar en el local.' using errcode = 'insufficient_privilege';
  end if;

  -- Si ya la tenias, se devuelve el mismo codigo en lugar de dar error. Va
  -- antes del QR y del cupo: quien se llevo el ultimo cupo y reintenta (por
  -- una mala conexion, por ejemplo) debe recibir su codigo, no "agotados".
  select code into v_codigo from public.offer_redemptions
   where offer_id = p_oferta and profile_id = yo;
  if v_codigo is not null then return v_codigo; end if;

  -- Se compara sin mayusculas ni espacios: el teclado de la app escribe en
  -- mayusculas y el codigo se genera en minusculas.
  if v_oferta.verification = 'qr'
     and lower(btrim(coalesce(p_codigo_puerta, ''))) <> lower(v_oferta.door_code) then
    raise exception 'Escanea el QR de la puerta.' using errcode = 'insufficient_privilege';
  end if;

  select count(*) into v_usados from public.offer_redemptions where offer_id = p_oferta;
  if v_usados >= v_oferta.max_redemptions then
    raise exception 'Se han agotado los cupos.' using errcode = 'check_violation';
  end if;

  -- 8 caracteres (4.300 millones de combinaciones): `code` es unico para
  -- siempre y con 6 acabaria chocando.
  v_codigo := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  insert into public.offer_redemptions (offer_id, profile_id, code)
  values (p_oferta, yo, v_codigo);
  return v_codigo;
end;
$$;

-- El dueño ve el codigo de puerta de sus ofertas para imprimir el QR.
create or replace function public.codigo_de_puerta(p_oferta uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select o.door_code from public.venue_offers o
   where o.id = p_oferta and privado.es_dueno_de_local(o.venue_id, auth.uid());
$$;

-- El dueño marca como usado el codigo que le ensenan.
create or replace function public.validar_canje(p_codigo text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_filas integer;
begin
  update public.offer_redemptions r
     set validated_at = now()
   where r.code = upper(trim(p_codigo)) and r.validated_at is null
     and exists (
       select 1 from public.venue_offers o
        where o.id = r.offer_id
          and privado.es_dueno_de_local(o.venue_id, auth.uid()));
  get diagnostics v_filas = row_count;
  return v_filas = 1;
end;
$$;

-- Cuantos canjes lleva cada oferta, para el cupo restante y el panel. Solo
-- responde a quien puede ver la oferta (security definer se salta la RLS, asi
-- que la comprobacion va dentro); no revela quien canjeo.
create or replace function public.canjes_de_oferta(p_oferta uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from public.offer_redemptions r
   where r.offer_id = p_oferta
     and exists (
       select 1 from public.venue_offers o
        where o.id = p_oferta
          and (privado.es_dueno_de_local(o.venue_id, auth.uid())
               or (privado.es_mayor_de_edad(auth.uid())
                   and privado.esta_en_local(o.venue_id, auth.uid()))));
$$;

revoke all on function public.canjear_oferta(uuid, text) from public, anon;
revoke all on function public.codigo_de_puerta(uuid)    from public, anon;
revoke all on function public.validar_canje(text)       from public, anon;
revoke all on function public.canjes_de_oferta(uuid)    from public, anon;
grant execute on function public.canjear_oferta(uuid, text) to authenticated;
grant execute on function public.codigo_de_puerta(uuid)    to authenticated;
grant execute on function public.validar_canje(text)       to authenticated;
grant execute on function public.canjes_de_oferta(uuid)    to authenticated;

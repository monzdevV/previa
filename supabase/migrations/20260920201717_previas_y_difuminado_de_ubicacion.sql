-- Previa · Migracion 2
-- Tabla de previas y difuminado de la ubicacion.

create table public.parties (
  id              uuid primary key default gen_random_uuid(),
  host_id         uuid not null references public.profiles(id) on delete cascade,
  title           text not null check (char_length(title) between 3 and 60),
  description     text check (char_length(description) <= 500),
  vibe            text[] not null default '{}',
  area_label      text not null check (char_length(area_label) between 2 and 60),
  location         extensions.geography(Point, 4326) not null,
  location_fuzzed  extensions.geography(Point, 4326) not null,
  starts_at       timestamptz not null,
  spots_total     smallint not null check (spots_total between 1 and 30),
  spots_taken     smallint not null default 0 check (spots_taken >= 0),
  min_age         smallint not null default 18 check (min_age >= 18),
  max_age         smallint,
  status          public.party_status not null default 'open',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint plazas_coherentes  check (spots_taken <= spots_total),
  constraint franja_edad_valida check (max_age is null or max_age >= min_age)
);

comment on column public.parties.location is
  'Ubicacion EXACTA. El rol authenticated no tiene privilegio SELECT sobre esta columna. Se obtiene con public.ubicacion_exacta().';
comment on column public.parties.location_fuzzed is
  'Ubicacion desplazada ~300 m, calculada una sola vez. Es la que ve todo el mundo.';

-- Difuminado ---------------------------------------------------------------
-- Desplaza el punto una distancia aleatoria dentro de un radio.
-- sqrt(random()) reparte los puntos de forma uniforme sobre el area del
-- circulo; sin la raiz se concentrarian cerca del centro.
--
-- NOTA: en la migracion 9 esta funcion se traslada al esquema `privado`
-- por motivos de privilegios. Aqui se conserva tal y como se aplico.

create or replace function public.difuminar_ubicacion(
  p_punto  extensions.geography,
  p_radio_m double precision default 300
)
returns extensions.geography
language plpgsql
volatile
set search_path = public, extensions
as $$
declare
  v_angulo   double precision := random() * 2 * pi();
  v_distancia double precision := sqrt(random()) * p_radio_m;
begin
  return extensions.ST_Project(p_punto, v_distancia, v_angulo);
end;
$$;

-- El desplazamiento se calcula UNA vez y se guarda.
-- Si se recalculase en cada consulta, promediar varias lecturas
-- permitiria deducir el centro real.

create or replace function public.fijar_ubicacion_difuminada()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'INSERT' or new.location is distinct from old.location then
    new.location_fuzzed := public.difuminar_ubicacion(new.location, 300);
  end if;
  return new;
end;
$$;

create trigger parties_difuminar
  before insert or update of location on public.parties
  for each row execute function public.fijar_ubicacion_difuminada();

create trigger parties_updated_at
  before update on public.parties
  for each row execute function public.tocar_updated_at();

-- El anfitrion es miembro de su propia previa -------------------------------

create or replace function public.registrar_anfitrion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.party_members (party_id, profile_id, role, group_size)
  values (new.id, new.host_id, 'host', 1);
  return new;
end;
$$;

-- Indices ------------------------------------------------------------------

create index parties_fuzzed_gix  on public.parties using gist (location_fuzzed);
create index parties_status_time on public.parties (status, starts_at);
create index parties_host        on public.parties (host_id);

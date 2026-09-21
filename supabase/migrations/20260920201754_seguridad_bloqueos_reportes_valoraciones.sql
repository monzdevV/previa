-- Previa · Migracion 4
-- Infraestructura de confianza y seguridad.

create table public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint no_autobloqueo check (blocker_id <> blocked_id)
);

create index blocks_blocked on public.blocks (blocked_id);

create table public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_id uuid references public.profiles(id) on delete cascade,
  party_id    uuid references public.parties(id) on delete set null,
  message_id  uuid references public.messages(id) on delete set null,
  reason      public.report_reason not null,
  details     text check (char_length(details) <= 1000),
  status      public.report_status not null default 'abierto',
  created_at  timestamptz not null default now(),
  constraint reporte_con_objeto check (
    reported_id is not null or party_id is not null or message_id is not null
  ),
  constraint no_autoreporte check (reported_id is null or reported_id <> reporter_id)
);

create index reports_status on public.reports (status, created_at desc);

-- Valoraciones ---------------------------------------------------------------
-- Solo entre personas que coincidieron en la misma previa.

create table public.ratings (
  party_id   uuid not null references public.parties(id) on delete cascade,
  rater_id   uuid not null references public.profiles(id) on delete cascade,
  rated_id   uuid not null references public.profiles(id) on delete cascade,
  score      smallint not null check (score between 1 and 5),
  comment    text check (char_length(comment) <= 300),
  created_at timestamptz not null default now(),
  primary key (party_id, rater_id, rated_id),
  constraint no_autovaloracion check (rater_id <> rated_id)
);

create index ratings_rated on public.ratings (rated_id);

-- Reputacion agregada --------------------------------------------------------

create or replace function public.recalcular_reputacion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_objetivo uuid := coalesce(new.rated_id, old.rated_id);
begin
  update public.profiles p
     set reputation    = sub.media,
         ratings_count = sub.total
    from (
      select round(avg(score)::numeric, 2) as media,
             count(*)                      as total
      from public.ratings
      where rated_id = v_objetivo
    ) sub
   where p.id = v_objetivo;
  return null;
end;
$$;

create trigger ratings_reputacion
  after insert or update or delete on public.ratings
  for each row execute function public.recalcular_reputacion();

-- Solo se valora a quien compartio previa contigo -----------------------------

create or replace function public.validar_valoracion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.party_members m
    where m.party_id = new.party_id and m.profile_id = new.rater_id
  ) or not exists (
    select 1 from public.party_members m
    where m.party_id = new.party_id and m.profile_id = new.rated_id
  ) then
    raise exception 'Solo puedes valorar a alguien con quien compartiste previa.'
      using errcode = 'check_violation';
  end if;

  if (select starts_at from public.parties where id = new.party_id) > now() then
    raise exception 'No puedes valorar una previa que aun no ha empezado.'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger ratings_validar
  before insert or update on public.ratings
  for each row execute function public.validar_valoracion();

-- Caducidad de previas --------------------------------------------------------
-- Las previas pasadas se cierran; a las 48 h se borran (RGPD: limitacion del plazo).

create or replace function public.caducar_previas()
returns void
language sql
security definer
set search_path = public
as $$
  with cerradas as (
    update public.parties
       set status = 'closed'
     where status in ('open', 'full')
       and starts_at < now() - interval '8 hours'
    returning 1
  )
  delete from public.parties
   where starts_at < now() - interval '48 hours';
$$;

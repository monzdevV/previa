-- Previa · Migracion 1
-- Extensiones, tipos enumerados y tabla de perfiles.

create extension if not exists postgis with schema extensions;

-- Tipos enumerados ---------------------------------------------------------

create type public.party_status   as enum ('open', 'full', 'closed', 'cancelled');
create type public.request_status as enum ('pending', 'accepted', 'rejected', 'cancelled');
create type public.member_role    as enum ('host', 'guest');
create type public.report_reason  as enum ('acoso', 'perfil_falso', 'menor_edad', 'contenido_inapropiado', 'spam', 'otro');
create type public.report_status  as enum ('abierto', 'revisado', 'cerrado');

-- Perfiles -----------------------------------------------------------------
-- Extiende auth.users con los datos publicos del usuario.
-- birth_date es nullable porque el registro con Google no lo aporta:
-- se completa en el onboarding y hasta entonces onboarded = false.

create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  username      text unique not null
                  check (char_length(username) between 3 and 20
                         and username ~ '^[a-z0-9_]+$'),
  display_name  text not null check (char_length(display_name) between 2 and 40),
  avatar_url    text,
  bio           text check (char_length(bio) <= 280),
  birth_date    date,
  onboarded     boolean not null default false,
  reputation    numeric(3,2),
  ratings_count integer not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on column public.profiles.birth_date is
  'Dato sensible: nunca se expone al cliente. La edad se consulta con public.edad().';

-- Mayoria de edad ----------------------------------------------------------
-- No puede ser un CHECK porque current_date no es IMMUTABLE,
-- asi que se valida con un disparador.

create or replace function public.validar_mayoria_de_edad()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.birth_date is not null
     and new.birth_date > (current_date - interval '18 years') then
    raise exception 'Previa es solo para mayores de 18 anos.'
      using errcode = 'check_violation';
  end if;

  -- El perfil se considera completo cuando hay fecha de nacimiento valida.
  new.onboarded := new.birth_date is not null;
  return new;
end;
$$;

create trigger profiles_mayoria_de_edad
  before insert or update of birth_date on public.profiles
  for each row execute function public.validar_mayoria_de_edad();

-- updated_at automatico ----------------------------------------------------

create or replace function public.tocar_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.tocar_updated_at();

-- Alta automatica de perfil al registrarse ---------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text;
begin
  v_username := lower(coalesce(
    new.raw_user_meta_data->>'username',
    'user_' || replace(substr(new.id::text, 1, 8), '-', '')
  ));

  insert into public.profiles (id, username, display_name, birth_date)
  values (
    new.id,
    v_username,
    coalesce(new.raw_user_meta_data->>'display_name', v_username),
    (new.raw_user_meta_data->>'birth_date')::date
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Edad derivada ------------------------------------------------------------
-- Unica via por la que el cliente conoce la edad de alguien.

create or replace function public.edad(p_profile uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select case
           when p.birth_date is null then null
           else extract(year from age(current_date, p.birth_date))::integer
         end
  from public.profiles p
  where p.id = p_profile;
$$;

-- Previa · Migracion 3
-- Solicitudes de plaza, miembros aceptados y mensajeria.

create table public.party_members (
  party_id   uuid not null references public.parties(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role       public.member_role not null default 'guest',
  group_size smallint not null default 1 check (group_size between 1 and 10),
  joined_at  timestamptz not null default now(),
  primary key (party_id, profile_id)
);

create index party_members_profile on public.party_members (profile_id);

-- Ahora que existe party_members, se activa el disparador de la migracion 2.
create trigger parties_alta_anfitrion
  after insert on public.parties
  for each row execute function public.registrar_anfitrion();

-- Solicitudes ---------------------------------------------------------------
-- Se solicita por grupo, no por persona: "somos 3".

create table public.join_requests (
  id           uuid primary key default gen_random_uuid(),
  party_id     uuid not null references public.parties(id) on delete cascade,
  requester_id uuid not null references public.profiles(id) on delete cascade,
  group_size   smallint not null check (group_size between 1 and 10),
  message      text check (char_length(message) <= 300),
  status       public.request_status not null default 'pending',
  created_at   timestamptz not null default now(),
  responded_at timestamptz
);

-- Solo una solicitud pendiente por persona y previa: evita el spam de peticiones.
create unique index join_requests_una_pendiente
  on public.join_requests (party_id, requester_id)
  where status = 'pending';

create index join_requests_party     on public.join_requests (party_id, status);
create index join_requests_requester on public.join_requests (requester_id, status);

-- Al aceptar una solicitud ---------------------------------------------------
-- Toda la logica vive en el servidor: el cliente solo cambia el estado.

create or replace function public.procesar_solicitud_aceptada()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_libres smallint;
begin
  if new.status = 'accepted' and old.status = 'pending' then

    select p.spots_total - p.spots_taken into v_libres
    from public.parties p
    where p.id = new.party_id
    for update;

    if v_libres < new.group_size then
      raise exception 'No quedan plazas suficientes: libres %, solicitadas %.',
        v_libres, new.group_size
        using errcode = 'check_violation';
    end if;

    insert into public.party_members (party_id, profile_id, role, group_size)
    values (new.party_id, new.requester_id, 'guest', new.group_size)
    on conflict (party_id, profile_id) do nothing;

    update public.parties
       set spots_taken = spots_taken + new.group_size,
           status = case
                      when spots_taken + new.group_size >= spots_total then 'full'
                      else status
                    end
     where id = new.party_id;

    new.responded_at := now();

  elsif new.status in ('rejected', 'cancelled') and old.status = 'pending' then
    new.responded_at := now();
  end if;

  return new;
end;
$$;

create trigger join_requests_aceptar
  before update of status on public.join_requests
  for each row execute function public.procesar_solicitud_aceptada();

-- Mensajes -------------------------------------------------------------------

create table public.messages (
  id         uuid primary key default gen_random_uuid(),
  party_id   uuid not null references public.parties(id) on delete cascade,
  sender_id  uuid not null references public.profiles(id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

create index messages_party_created on public.messages (party_id, created_at desc);

-- Realtime: el cliente se suscribe a los mensajes de su previa.
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.join_requests;

-- Previa · Migracion 5
-- Seguridad a nivel de fila y de columna.
--
-- Dos mecanismos complementarios:
--   RLS  -> decide QUE FILAS ve cada usuario.
--   GRANT-> decide QUE COLUMNAS puede leer. Es lo que protege la ubicacion
--           exacta, porque RLS por si sola no puede ocultar una columna.
--
-- NOTA: en la migracion 7 las cuatro funciones auxiliares se trasladan al
-- esquema `privado` y las politicas se repuntan. Aqui se conserva tal y
-- como se aplico originalmente.

-- Funciones auxiliares ------------------------------------------------------
-- SECURITY DEFINER para que no vuelvan a pasar por RLS y provoquen recursion.

create or replace function public.es_miembro(p_party uuid, p_profile uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.party_members m
    where m.party_id = p_party and m.profile_id = p_profile
  );
$$;

create or replace function public.es_anfitrion(p_party uuid, p_profile uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.parties p
    where p.id = p_party and p.host_id = p_profile
  );
$$;

-- El bloqueo es simetrico en sus efectos: si cualquiera de los dos bloqueo
-- al otro, dejan de verse mutuamente.
create or replace function public.hay_bloqueo(p_a uuid, p_b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.blocks b
    where (b.blocker_id = p_a and b.blocked_id = p_b)
       or (b.blocker_id = p_b and b.blocked_id = p_a)
  );
$$;

create or replace function public.perfil_completo(p_profile uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select onboarded from public.profiles where id = p_profile), false);
$$;

-- Activacion de RLS ---------------------------------------------------------

alter table public.profiles      enable row level security;
alter table public.parties       enable row level security;
alter table public.party_members enable row level security;
alter table public.join_requests enable row level security;
alter table public.messages      enable row level security;
alter table public.blocks        enable row level security;
alter table public.reports       enable row level security;
alter table public.ratings       enable row level security;

-- Privilegios de columna ----------------------------------------------------
-- Supabase concede ALL por defecto: hay que revocarlo antes de afinar.

revoke all on public.profiles      from anon, authenticated;
revoke all on public.parties       from anon, authenticated;
revoke all on public.party_members from anon, authenticated;
revoke all on public.join_requests from anon, authenticated;
revoke all on public.messages      from anon, authenticated;
revoke all on public.blocks        from anon, authenticated;
revoke all on public.reports       from anon, authenticated;
revoke all on public.ratings       from anon, authenticated;

-- profiles: birth_date NO figura entre las columnas legibles.
grant select (id, username, display_name, avatar_url, bio, onboarded,
              reputation, ratings_count, created_at, updated_at)
  on public.profiles to authenticated;
grant update (username, display_name, avatar_url, bio, birth_date)
  on public.profiles to authenticated;
grant delete on public.profiles to authenticated;

-- parties: location NO figura entre las columnas legibles.
-- Se puede escribir (el anfitrion la fija) pero no leer.
grant select (id, host_id, title, description, vibe, area_label, location_fuzzed,
              starts_at, spots_total, spots_taken, min_age, max_age, status,
              created_at, updated_at)
  on public.parties to authenticated;
grant insert (host_id, title, description, vibe, area_label, location,
              location_fuzzed, starts_at, spots_total, min_age, max_age)
  on public.parties to authenticated;
-- spots_taken queda fuera: solo lo modifican los disparadores.
grant update (title, description, vibe, area_label, location, starts_at,
              spots_total, min_age, max_age, status)
  on public.parties to authenticated;
grant delete on public.parties to authenticated;

grant select, delete                on public.party_members to authenticated;
grant select, insert, update        on public.join_requests to authenticated;
grant select, insert, delete        on public.messages      to authenticated;
grant select, insert, delete        on public.blocks        to authenticated;
grant select, insert                on public.reports       to authenticated;
grant select, insert, update, delete on public.ratings      to authenticated;

-- Politicas: profiles -------------------------------------------------------

create policy "perfiles visibles salvo bloqueo"
  on public.profiles for select to authenticated
  using (id = auth.uid() or not public.hay_bloqueo(auth.uid(), id));

create policy "solo edito mi perfil"
  on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create policy "solo borro mi perfil"
  on public.profiles for delete to authenticated
  using (id = auth.uid());

-- Politicas: parties --------------------------------------------------------

create policy "previas abiertas y las mias"
  on public.parties for select to authenticated
  using (
    host_id = auth.uid()
    or public.es_miembro(id, auth.uid())
    or (
      status in ('open', 'full')
      and starts_at > now() - interval '8 hours'
      and not public.hay_bloqueo(auth.uid(), host_id)
    )
  );

create policy "creo previas si tengo el perfil completo"
  on public.parties for insert to authenticated
  with check (host_id = auth.uid() and public.perfil_completo(auth.uid()));

create policy "solo edito mis previas"
  on public.parties for update to authenticated
  using (host_id = auth.uid()) with check (host_id = auth.uid());

create policy "solo borro mis previas"
  on public.parties for delete to authenticated
  using (host_id = auth.uid());

-- Politicas: party_members --------------------------------------------------

create policy "veo a los miembros de mis previas"
  on public.party_members for select to authenticated
  using (profile_id = auth.uid() or public.es_miembro(party_id, auth.uid()));

create policy "me salgo yo o me echa el anfitrion"
  on public.party_members for delete to authenticated
  using (
    (profile_id = auth.uid() and role = 'guest')
    or public.es_anfitrion(party_id, auth.uid())
  );

-- Politicas: join_requests --------------------------------------------------

create policy "veo mis solicitudes y las de mis previas"
  on public.join_requests for select to authenticated
  using (requester_id = auth.uid() or public.es_anfitrion(party_id, auth.uid()));

create policy "solicito plaza para mi grupo"
  on public.join_requests for insert to authenticated
  with check (
    requester_id = auth.uid()
    and public.perfil_completo(auth.uid())
    and not public.es_miembro(party_id, auth.uid())
    and exists (
      select 1 from public.parties p
      where p.id = party_id
        and p.status = 'open'
        and p.starts_at > now()
        and not public.hay_bloqueo(auth.uid(), p.host_id)
    )
  );

create policy "el anfitrion responde, el solicitante cancela"
  on public.join_requests for update to authenticated
  using (public.es_anfitrion(party_id, auth.uid()) or requester_id = auth.uid())
  with check (public.es_anfitrion(party_id, auth.uid()) or requester_id = auth.uid());

-- Politicas: messages -------------------------------------------------------

create policy "solo leo el chat de mis previas"
  on public.messages for select to authenticated
  using (public.es_miembro(party_id, auth.uid()));

create policy "solo escribo en mis previas"
  on public.messages for insert to authenticated
  with check (sender_id = auth.uid() and public.es_miembro(party_id, auth.uid()));

create policy "solo borro mis mensajes"
  on public.messages for delete to authenticated
  using (sender_id = auth.uid());

-- Politicas: blocks ---------------------------------------------------------

create policy "gestiono mis bloqueos"
  on public.blocks for select to authenticated using (blocker_id = auth.uid());
create policy "bloqueo a quien quiero"
  on public.blocks for insert to authenticated with check (blocker_id = auth.uid());
create policy "desbloqueo a quien quiero"
  on public.blocks for delete to authenticated using (blocker_id = auth.uid());

-- Politicas: reports --------------------------------------------------------

create policy "veo mis reportes"
  on public.reports for select to authenticated using (reporter_id = auth.uid());
create policy "reporto en mi nombre"
  on public.reports for insert to authenticated with check (reporter_id = auth.uid());

-- Politicas: ratings --------------------------------------------------------

create policy "las valoraciones son publicas"
  on public.ratings for select to authenticated
  using (not public.hay_bloqueo(auth.uid(), rated_id));

create policy "valoro en mi nombre"
  on public.ratings for insert to authenticated with check (rater_id = auth.uid());
create policy "edito mi valoracion"
  on public.ratings for update to authenticated
  using (rater_id = auth.uid()) with check (rater_id = auth.uid());
create policy "borro mi valoracion"
  on public.ratings for delete to authenticated using (rater_id = auth.uid());

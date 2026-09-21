-- Previa · Migracion 7
-- Reduccion de la superficie de API.
--
-- PostgREST publica automaticamente como endpoint REST toda funcion del
-- esquema public. Las funciones auxiliares de RLS y las de disparador no
-- deberian ser llamables desde fuera: un usuario podria consultar
-- es_miembro(previa_ajena, perfil_ajeno) y deducir quien va a donde.
--
-- Solucion: las auxiliares pasan a un esquema privado no publicado,
-- y a las de disparador se les retira el privilegio EXECUTE.

create schema if not exists privado;
grant usage on schema privado to authenticated;

-- Auxiliares de RLS en esquema privado --------------------------------------

create or replace function privado.es_miembro(p_party uuid, p_profile uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.party_members m
    where m.party_id = p_party and m.profile_id = p_profile
  );
$$;

create or replace function privado.es_anfitrion(p_party uuid, p_profile uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.parties p
    where p.id = p_party and p.host_id = p_profile
  );
$$;

create or replace function privado.hay_bloqueo(p_a uuid, p_b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.blocks b
    where (b.blocker_id = p_a and b.blocked_id = p_b)
       or (b.blocker_id = p_b and b.blocked_id = p_a)
  );
$$;

create or replace function privado.perfil_completo(p_profile uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select onboarded from public.profiles where id = p_profile), false);
$$;

grant execute on function privado.es_miembro(uuid, uuid)      to authenticated;
grant execute on function privado.es_anfitrion(uuid, uuid)    to authenticated;
grant execute on function privado.hay_bloqueo(uuid, uuid)     to authenticated;
grant execute on function privado.perfil_completo(uuid)       to authenticated;

-- Repuntado de las politicas a las nuevas funciones --------------------------

alter policy "perfiles visibles salvo bloqueo" on public.profiles
  using (id = auth.uid() or not privado.hay_bloqueo(auth.uid(), id));

alter policy "previas abiertas y las mias" on public.parties
  using (
    host_id = auth.uid()
    or privado.es_miembro(id, auth.uid())
    or (
      status in ('open', 'full')
      and starts_at > now() - interval '8 hours'
      and not privado.hay_bloqueo(auth.uid(), host_id)
    )
  );

alter policy "creo previas si tengo el perfil completo" on public.parties
  with check (host_id = auth.uid() and privado.perfil_completo(auth.uid()));

alter policy "veo a los miembros de mis previas" on public.party_members
  using (profile_id = auth.uid() or privado.es_miembro(party_id, auth.uid()));

alter policy "me salgo yo o me echa el anfitrion" on public.party_members
  using (
    (profile_id = auth.uid() and role = 'guest')
    or privado.es_anfitrion(party_id, auth.uid())
  );

alter policy "veo mis solicitudes y las de mis previas" on public.join_requests
  using (requester_id = auth.uid() or privado.es_anfitrion(party_id, auth.uid()));

alter policy "solicito plaza para mi grupo" on public.join_requests
  with check (
    requester_id = auth.uid()
    and privado.perfil_completo(auth.uid())
    and not privado.es_miembro(party_id, auth.uid())
    and exists (
      select 1 from public.parties p
      where p.id = party_id
        and p.status = 'open'
        and p.starts_at > now()
        and not privado.hay_bloqueo(auth.uid(), p.host_id)
    )
  );

alter policy "el anfitrion responde, el solicitante cancela" on public.join_requests
  using (privado.es_anfitrion(party_id, auth.uid()) or requester_id = auth.uid())
  with check (privado.es_anfitrion(party_id, auth.uid()) or requester_id = auth.uid());

alter policy "solo leo el chat de mis previas" on public.messages
  using (privado.es_miembro(party_id, auth.uid()));

alter policy "solo escribo en mis previas" on public.messages
  with check (sender_id = auth.uid() and privado.es_miembro(party_id, auth.uid()));

alter policy "las valoraciones son publicas" on public.ratings
  using (not privado.hay_bloqueo(auth.uid(), rated_id));

-- ubicacion_exacta usaba la version publica: se repunta tambien.
create or replace function public.ubicacion_exacta(p_party uuid)
returns table (lat double precision, lng double precision)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
begin
  if not privado.es_miembro(p_party, auth.uid()) then
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

-- Retirada de las versiones publicas ----------------------------------------

drop function public.es_miembro(uuid, uuid);
drop function public.es_anfitrion(uuid, uuid);
drop function public.hay_bloqueo(uuid, uuid);
drop function public.perfil_completo(uuid);

-- Funciones de disparador: no deben ser endpoints ----------------------------
-- El privilegio EXECUTE de una funcion de disparador se comprueba al crear el
-- disparador, no al dispararse, asi que revocarlo ahora no rompe nada.

revoke all on function public.handle_new_user()              from public, anon, authenticated;
revoke all on function public.registrar_anfitrion()          from public, anon, authenticated;
revoke all on function public.procesar_solicitud_aceptada()  from public, anon, authenticated;
revoke all on function public.recalcular_reputacion()        from public, anon, authenticated;
revoke all on function public.validar_valoracion()           from public, anon, authenticated;
revoke all on function public.validar_mayoria_de_edad()      from public, anon, authenticated;
revoke all on function public.tocar_updated_at()             from public, anon, authenticated;
revoke all on function public.fijar_ubicacion_difuminada()   from public, anon, authenticated;

-- El rol anonimo no tiene nada que hacer aqui --------------------------------

revoke all on function public.previas_cerca(double precision, double precision, integer, integer, smallint) from anon;
revoke all on function public.ubicacion_exacta(uuid)   from anon;
revoke all on function public.mi_fecha_nacimiento()    from anon;
revoke all on function public.exportar_mis_datos()     from anon;
revoke all on function public.eliminar_mi_cuenta()     from anon;
revoke all on function public.edad(uuid)               from anon;

grant execute on function public.ubicacion_exacta(uuid) to authenticated;

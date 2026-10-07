-- Ajustes de No hay huevos tras la auditoria final.
--
-- 1. Un reto abierto nunca queda escondido: mi_reto ya no filtra por local
--    (se puede ir a dos sitios la misma noche) y un bloqueo o dejar de jugar
--    cierra los retos abiertos entre esas dos personas.
-- 2. Cumplir exige una foto hecha despues de repartirse el reto y que no
--    haya servido ya para otro.
-- 3. La IA escribe despues de crear el reto y no antes: asi cada llamada a
--    la IA corresponde a un reto ya guardado, y pedir en paralelo no
--    multiplica el gasto.
-- 4. Quitar la foto de un reto borra tambien el fichero; lo hace la funcion
--    de borde, porque solo la clave de servicio puede borrar de Storage.

-- 1. Retos que se cierran solos --------------------------------------------

create or replace function privado.cerrar_retos_entre(a uuid, b uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.challenges
     set status = 'caducado', resolved_at = now()
   where status = 'activo'
     and ((player_id = a and target_id = b) or (player_id = b and target_id = a));
$$;

create or replace function privado.al_bloquear()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform privado.cerrar_retos_entre(new.blocker_id, new.blocked_id);
  return new;
end;
$$;

drop trigger if exists blocks_cierra_retos on public.blocks;
create trigger blocks_cierra_retos after insert on public.blocks
  for each row execute function privado.al_bloquear();

-- Dejar de jugar tiene efecto inmediato tambien para los retos ya repartidos.
create or replace function privado.al_dejar_de_jugar()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.plays_challenges and not new.plays_challenges then
    update public.challenges
       set status = 'caducado', resolved_at = now()
     where status = 'activo' and target_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_deja_de_jugar on public.profiles;
create trigger profiles_deja_de_jugar after update of plays_challenges on public.profiles
  for each row execute function privado.al_dejar_de_jugar();

revoke execute on function privado.cerrar_retos_entre(uuid, uuid) from public;
revoke execute on function privado.al_bloquear() from public;
revoke execute on function privado.al_dejar_de_jugar() from public;

-- El reto abierto, en el local que sea. Trae el local y la noche para que la
-- app suba la foto a la sala correcta y con la noche del reto, no con la del
-- reloj del telefono.
drop function if exists public.mi_reto(uuid);
create function public.mi_reto()
returns table (
  id uuid,
  texto text,
  origen text,
  creado_en timestamptz,
  local_id uuid,
  local_nombre text,
  noche date,
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
  -- retos_restantes: los que quedan despues de este.
  select c.id, c.prompt, c.source, c.created_at,
         v.id, v.name, c.night,
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
    join public.venues v on v.id = c.venue_id
   where c.player_id = auth.uid()
     and c.status = 'activo'
     and c.night = privado.noche_actual()
   limit 1;
$$;

revoke execute on function public.mi_reto() from public, anon;
grant execute on function public.mi_reto() to authenticated;

-- 2. Cumplir con una foto nueva y sin repetir ------------------------------

drop index if exists public.challenges_publicacion;
create unique index challenges_publicacion
  on public.challenges (post_id) where post_id is not null;

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
  -- Por si el bloqueo llego por otro camino: nunca se avisa a quien te ha
  -- bloqueado.
  if privado.hay_bloqueo(v_reto.player_id, v_reto.target_id) then
    raise exception 'NO_EXISTE_RETO';
  end if;

  if not exists (
    select 1 from public.posts
     where id = publicacion
       and author_id = auth.uid()
       and venue_id = v_reto.venue_id
       and night = v_reto.night
       and created_at >= v_reto.created_at
  ) or exists (
    select 1 from public.challenges where post_id = publicacion
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

-- 3. La IA reescribe un reto ya creado ------------------------------------

create or replace function public.reescribir_reto(reto uuid, plantilla text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if plantilla is null
     or position('{persona}' in plantilla) = 0
     or char_length(plantilla) > 200 then
    raise exception 'PLANTILLA_INVALIDA';
  end if;

  -- Solo el texto de reserva de un reto recien creado: si el jugador ya lo
  -- esta leyendo, cambiarselo por debajo seria peor que dejarlo.
  update public.challenges c
     set prompt = replace(plantilla, '{persona}', p.display_name),
         source = 'ia'
    from public.profiles p
   where c.id = reto
     and p.id = c.target_id
     and c.status = 'activo'
     and c.source = 'plantilla'
     and c.created_at > now() - interval '30 seconds';
end;
$$;

revoke execute on function public.reescribir_reto(uuid, text) from public, anon, authenticated;
grant execute on function public.reescribir_reto(uuid, text) to service_role;

-- 4. Quitar la foto, con fichero incluido ---------------------------------

-- Devuelve la URL del fichero para que la funcion de borde lo borre. Recibe
-- el objetivo por parametro, asi que solo la llama la clave de servicio.
create or replace function public.quitar_foto_de_reto_de(objetivo uuid, reto uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post uuid;
  v_url text;
begin
  select c.post_id, p.media_url into v_post, v_url
    from public.challenges c
    join public.posts p on p.id = c.post_id
   where c.id = reto and c.target_id = objetivo and c.status = 'hecho';

  if v_post is null then
    raise exception 'NO_EXISTE_RETO';
  end if;

  delete from public.posts where id = v_post;
  return v_url;
end;
$$;

revoke execute on function public.quitar_foto_de_reto_de(uuid, uuid) from public, anon, authenticated;
grant execute on function public.quitar_foto_de_reto_de(uuid, uuid) to service_role;

-- La version para la app dejaba el fichero en el cubo publico.
drop function if exists public.quitar_foto_de_reto(uuid);

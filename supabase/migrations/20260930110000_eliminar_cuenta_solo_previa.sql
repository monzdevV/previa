-- Previa · eliminar_mi_cuenta reescrita.
--
-- POR QUE: este proyecto de Supabase aloja tambien tablas de otra aplicacion
-- (posts, follows, venues, challenges...) que cuelgan del MISMO profiles.id.
-- La version anterior hacia solo `delete from auth.users` y dejaba el borrado
-- a las cascadas: no liberaba las plazas que el usuario ocupaba en previas
-- ajenas (spots_taken quedaba inflado), no borraba su foto del Storage (dato
-- personal huerfano, incumple RGPD art. 17) y no dejaba claro que se borraba.
--
-- Ahora el borrado de datos de PREVIA es explicito y ordenado. Lo unico que
-- sigue borrandose por cascada es lo que cuelga de la cuenta en si (perfil y
-- filas propias de la otra app para ese mismo usuario): es inevitable si se
-- elimina la cuenta, y nunca se toca nada de OTRAS personas (sus posts, sus
-- follows, sus retos permanecen; las previas borradas solo dejan posts.party_id
-- a NULL por el ON DELETE SET NULL existente).
--
-- search_path vacio: toda referencia va calificada, asi nadie puede colar un
-- objeto homonimo en un esquema anterior del path (la funcion es SECURITY DEFINER).

create or replace function public.eliminar_mi_cuenta()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'No hay sesion activa.' using errcode = 'insufficient_privilege';
  end if;

  -- 1. Liberar las plazas que ocupaba en previas AJENAS. Sin esto, al borrarse
  --    la pertenencia las plazas quedarian ocupadas para siempre.
  update public.parties p
     set spots_taken = greatest(0, p.spots_taken - m.group_size),
         status = case when p.status = 'full'::public.party_status
                       then 'open'::public.party_status else p.status end
    from public.party_members m
   where m.profile_id = v_uid
     and m.party_id = p.id
     and m.role = 'guest'
     and p.host_id <> v_uid;

  -- 2. Datos de Previa propios (explicito, no por cascada, para que sea auditable).
  delete from public.messages      where sender_id    = v_uid;
  delete from public.join_requests where requester_id = v_uid;
  delete from public.party_members where profile_id   = v_uid;
  delete from public.ratings       where rater_id = v_uid or rated_id = v_uid;
  delete from public.blocks        where blocker_id = v_uid or blocked_id = v_uid;
  delete from public.reports       where reporter_id = v_uid;
  -- Sus previas como anfitrion: arrastran miembros, solicitudes y chat.
  delete from public.parties       where host_id = v_uid;

  -- 3. Foto de perfil. Se borra la fila de storage.objects de su carpeta
  --    (<uid>/...) en el bucket avatars. Solo ese bucket: 'avatares' y
  --    'publicaciones' pertenecen a la otra app.
  --    Storage protege la tabla con un disparador que rechaza DELETE directos
  --    salvo que storage.allow_delete_query = 'true' (solo dentro de esta
  --    transaccion: set_config(..., true)). Al borrar la fila la URL publica
  --    deja de servirse, pero el binario puede quedar huerfano en el almacen de
  --    objetos; lo correcto es que la app llame antes a
  --    storage.from('avatars').remove(['<uid>/foto']) (ver supabase/README.md).
  perform set_config('storage.allow_delete_query', 'true', true);
  delete from storage.objects
   where bucket_id = 'avatars'
     and split_part(name, '/', 1) = v_uid::text;
  perform set_config('storage.allow_delete_query', 'false', true);

  -- 4. La cuenta. Cascada: profiles y lo que de el cuelga para esta persona.
  delete from auth.users where id = v_uid;
end;
$$;

revoke all on function public.eliminar_mi_cuenta() from public, anon;
grant execute on function public.eliminar_mi_cuenta() to authenticated;

comment on function public.eliminar_mi_cuenta() is
  'API. RGPD art. 17. Solo borra la cuenta y los datos de auth.uid(): libera sus plazas, borra datos de Previa, su foto de avatars y la cuenta.';

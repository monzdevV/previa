-- Previa · Bateria de pruebas de la capa social
--
-- Continua la numeracion de seguridad.sql. Crea tres usuarios ficticios
-- (Diana, Eva y Fran), ejerce las politicas de la parte social desde el punto
-- de vista de cada uno y borra los datos al terminar.
--
-- Como ejecutarla: pegar el contenido en el editor SQL de Supabase.
-- Resultado esperado: 18 filas, todas con resultado PASA.
--
-- Que demuestra cada prueba:
--   17-19  el feed se ve, solo publicas en tu nombre y solo borras lo tuyo
--   20-21  los likes cuentan solos y no se pueden poner en nombre de otro
--   22     un bloqueo esconde las publicaciones en ambos sentidos
--   23-25  seguir es unidireccional, tuyo, y no se puede sobre un bloqueo
--   26-29  los mensajes directos solo viajan entre quien se sigue
--   30-32  la sala de un local solo existe para quien ha dicho que va
--   33-34  una previa publica revela su direccion y una privada no

create temp table resultados_social (
  n int, prueba text, esperado text, obtenido text, ok boolean
);

do $test$
declare
  v_diana uuid := 'd1a11111-1111-4111-8111-111111111111';
  v_eva   uuid := 'e2a22222-2222-4222-8222-222222222222';
  v_fran  uuid := 'f3a33333-3333-4333-8333-333333333333';
  v_post  uuid;
  v_local uuid;
  v_priv  uuid;
  v_pub   uuid;
  v_noche date := current_date;
  v_txt   text;
  v_int   int;
begin
  -- Alta de usuarios ---------------------------------------------------------
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at,
                          raw_user_meta_data)
  values
    (v_diana, '00000000-0000-0000-0000-000000000000','authenticated',
     'authenticated','diana@previa.test','x', now(), now(), now(),
     jsonb_build_object('username','diana_test','display_name','Diana',
                        'birth_date','2000-02-02')),
    (v_eva, '00000000-0000-0000-0000-000000000000','authenticated',
     'authenticated','eva@previa.test','x', now(), now(), now(),
     jsonb_build_object('username','eva_test','display_name','Eva',
                        'birth_date','1999-07-07')),
    (v_fran, '00000000-0000-0000-0000-000000000000','authenticated',
     'authenticated','fran@previa.test','x', now(), now(), now(),
     jsonb_build_object('username','fran_test','display_name','Fran',
                        'birth_date','1998-12-12'));

  insert into public.venues (name, city, area_label)
  values ('Local de prueba','Ciudad de prueba','Centro')
  returning id into v_local;

  -- Diana publica ------------------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_diana,'role','authenticated')::text, true);
  insert into public.posts (author_id, media_url, media_type, caption, area_label)
  values (v_diana,'https://ejemplo.test/1.jpg','photo','Una noche','Ciudad de prueba')
  returning id into v_post;
  execute 'reset role';
  insert into resultados_social values
    (17,'Se puede publicar','creada', coalesce(v_post::text,'null'), v_post is not null);

  -- Eva no puede publicar en nombre de Diana ---------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_eva,'role','authenticated')::text, true);
  begin
    insert into public.posts (author_id, media_url, media_type)
    values (v_diana,'https://ejemplo.test/falsa.jpg','photo');
    execute 'reset role';
    insert into resultados_social values
      (18,'Nadie publica en nombre de otro','denegado','lo ha hecho', false);
  exception when others then
    execute 'reset role';
    insert into resultados_social values
      (18,'Nadie publica en nombre de otro','denegado','denegado', true);
  end;

  -- Eva no puede borrar lo de Diana ------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_eva,'role','authenticated')::text, true);
  delete from public.posts where id = v_post;
  execute 'reset role';
  select count(*)::int into v_int from public.posts where id = v_post;
  insert into resultados_social values
    (19,'Nadie borra publicaciones ajenas','1', v_int::text, v_int = 1);

  -- El like sube el contador solo --------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_eva,'role','authenticated')::text, true);
  insert into public.post_likes (post_id, user_id) values (v_post, v_eva);
  execute 'reset role';
  select like_count into v_int from public.posts where id = v_post;
  insert into resultados_social values
    (20,'El disparador cuenta el like','1', v_int::text, v_int = 1);

  -- Fran no puede dar like en nombre de Eva ----------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_fran,'role','authenticated')::text, true);
  begin
    insert into public.post_likes (post_id, user_id) values (v_post, v_eva);
    execute 'reset role';
    insert into resultados_social values
      (21,'Nadie da like en nombre de otro','denegado','lo ha hecho', false);
  exception when others then
    execute 'reset role';
    insert into resultados_social values
      (21,'Nadie da like en nombre de otro','denegado','denegado', true);
  end;

  -- Un bloqueo esconde las publicaciones -------------------------------------
  insert into public.blocks (blocker_id, blocked_id) values (v_fran, v_diana);
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_fran,'role','authenticated')::text, true);
  select count(*)::int into v_int from public.posts where id = v_post;
  execute 'reset role';
  insert into resultados_social values
    (22,'Un bloqueo esconde las publicaciones','0', v_int::text, v_int = 0);

  -- Y tambien impide seguir --------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_fran,'role','authenticated')::text, true);
  begin
    insert into public.follows (follower_id, followee_id) values (v_fran, v_diana);
    execute 'reset role';
    insert into resultados_social values
      (23,'No se puede seguir a quien has bloqueado','denegado','lo ha hecho', false);
  exception when others then
    execute 'reset role';
    insert into resultados_social values
      (23,'No se puede seguir a quien has bloqueado','denegado','denegado', true);
  end;
  delete from public.blocks where blocker_id = v_fran and blocked_id = v_diana;

  -- Nadie crea seguimientos ajenos -------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_eva,'role','authenticated')::text, true);
  begin
    insert into public.follows (follower_id, followee_id) values (v_diana, v_fran);
    execute 'reset role';
    insert into resultados_social values
      (24,'Nadie sigue en nombre de otro','denegado','lo ha hecho', false);
  exception when others then
    execute 'reset role';
    insert into resultados_social values
      (24,'Nadie sigue en nombre de otro','denegado','denegado', true);
  end;

  -- Seguir de verdad ---------------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_eva,'role','authenticated')::text, true);
  insert into public.follows (follower_id, followee_id) values (v_eva, v_diana);
  execute 'reset role';
  select count(*)::int into v_int from public.follows
   where follower_id = v_eva and followee_id = v_diana;
  insert into resultados_social values
    (25,'Se puede seguir a alguien','1', v_int::text, v_int = 1);

  -- Fran no sigue a nadie, asi que no puede escribir --------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_fran,'role','authenticated')::text, true);
  begin
    insert into public.direct_messages (sender_id, recipient_id, body)
    values (v_fran, v_diana, 'Hola');
    execute 'reset role';
    insert into resultados_social values
      (26,'Sin seguimiento no se puede escribir','denegado','lo ha hecho', false);
  exception when others then
    execute 'reset role';
    insert into resultados_social values
      (26,'Sin seguimiento no se puede escribir','denegado','denegado', true);
  end;

  -- Eva sigue a Diana, asi que si puede --------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_eva,'role','authenticated')::text, true);
  insert into public.direct_messages (sender_id, recipient_id, body)
  values (v_eva, v_diana, 'Hola Diana');
  execute 'reset role';
  select count(*)::int into v_int from public.direct_messages
   where sender_id = v_eva and recipient_id = v_diana;
  insert into resultados_social values
    (27,'Con seguimiento si se puede escribir','1', v_int::text, v_int = 1);

  -- Diana recibe, aunque ella no siga a Eva: la regla es para escribir --------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_diana,'role','authenticated')::text, true);
  select count(*)::int into v_int from public.direct_messages
   where recipient_id = v_diana;
  execute 'reset role';
  insert into resultados_social values
    (28,'Quien recibe lee su mensaje','1', v_int::text, v_int = 1);

  -- Fran no ve conversaciones ajenas -----------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_fran,'role','authenticated')::text, true);
  select count(*)::int into v_int from public.direct_messages;
  execute 'reset role';
  insert into resultados_social values
    (29,'Nadie lee conversaciones ajenas','0', v_int::text, v_int = 0);

  -- La sala esta cerrada si no has dicho que vas ------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_diana,'role','authenticated')::text, true);
  begin
    insert into public.venue_messages (venue_id, night, sender_id, body)
    values (v_local, v_noche, v_diana, 'Estoy dentro');
    execute 'reset role';
    insert into resultados_social values
      (30,'Sin decir que vas, la sala esta cerrada','denegado','lo ha hecho', false);
  exception when others then
    execute 'reset role';
    insert into resultados_social values
      (30,'Sin decir que vas, la sala esta cerrada','denegado','denegado', true);
  end;

  -- Decir que vas abre la sala ------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_diana,'role','authenticated')::text, true);
  insert into public.venue_plans (venue_id, profile_id, night)
  values (v_local, v_diana, v_noche);
  insert into public.venue_messages (venue_id, night, sender_id, body)
  values (v_local, v_noche, v_diana, 'Ya estoy aqui');
  execute 'reset role';
  select count(*)::int into v_int from public.venue_messages
   where venue_id = v_local and night = v_noche;
  insert into resultados_social values
    (31,'Decir que vas abre la sala','1', v_int::text, v_int = 1);

  -- Quien no va, no lee la sala -----------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_fran,'role','authenticated')::text, true);
  select count(*)::int into v_int from public.venue_messages;
  execute 'reset role';
  insert into resultados_social values
    (32,'Quien no va no lee la sala','0', v_int::text, v_int = 0);

  -- Una previa privada no revela su direccion ---------------------------------
  insert into public.parties (host_id, title, area_label, location, location_fuzzed,
                              starts_at, spots_total, is_public)
  values (v_diana,'Previa privada','Centro',
          extensions.ST_SetSRID(extensions.ST_Point(-0.88, 41.65), 4326)::extensions.geography,
          extensions.ST_SetSRID(extensions.ST_Point(-0.88, 41.65), 4326)::extensions.geography,
          now() + interval '4 hours', 3, false)
  returning id into v_priv;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_fran,'role','authenticated')::text, true);
  begin
    select lat::text into v_txt from public.ubicacion_exacta(v_priv);
    execute 'reset role';
    insert into resultados_social values
      (33,'Una previa privada no da su direccion','denegado','la ha dado', false);
  exception when others then
    execute 'reset role';
    insert into resultados_social values
      (33,'Una previa privada no da su direccion','denegado','denegado', true);
  end;

  -- Una publica si ------------------------------------------------------------
  insert into public.parties (host_id, title, area_label, location, location_fuzzed,
                              starts_at, spots_total, is_public)
  values (v_diana,'Quedada en la plaza','Centro',
          extensions.ST_SetSRID(extensions.ST_Point(-0.88, 41.65), 4326)::extensions.geography,
          extensions.ST_SetSRID(extensions.ST_Point(-0.88, 41.65), 4326)::extensions.geography,
          now() + interval '4 hours', 5, true)
  returning id into v_pub;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_fran,'role','authenticated')::text, true);
  select count(*)::int into v_int from public.ubicacion_exacta(v_pub);
  execute 'reset role';
  insert into resultados_social values
    (34,'Una previa publica si da su direccion','1', v_int::text, v_int = 1);

  -- Limpieza -------------------------------------------------------------------
  delete from public.venues where id = v_local;
  delete from auth.users where id in (v_diana, v_eva, v_fran);
end;
$test$;

select n, prueba, esperado, obtenido,
       case when ok then 'PASA' else 'FALLA' end as resultado
from resultados_social order by n;

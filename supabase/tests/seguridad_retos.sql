-- Previa · Pruebas del cierre de escrituras y del minijuego "No hay huevos"
--
-- Continua la numeracion de seguridad_social.sql. Crea tres usuarios
-- ficticios (Gala, Hugo e Ines), ejerce las reglas desde cada uno y lo borra
-- todo al terminar.
--
-- Como ejecutarla: pegar el contenido en el editor SQL de Supabase.
-- Resultado esperado: 20 filas, todas con resultado PASA.
--
-- Que demuestra cada prueba:
--   35-37  una solicitud solo la acepta el anfitrion, y no se muda de previa
--   38     quien recibe un mensaje no puede reescribirlo
--   39-41  una publicacion no trae likes de serie, ni media de fuera, ni
--          se cuela en la sala de un local al que no vas
--   42     un usuario no pone enlace de entradas a un local
--   43-44  los pasos del reparto no se llaman desde la app, y exigen ir
--   45-48  el reto se reparte, es uno cada vez y el objetivo no lo ve antes
--   49-50  se cumple con foto y el objetivo puede quitarla
--   51-52  un bloqueo o no querer jugar te sacan del reparto
--   53-54  rajarse cierra el reto y el cliente no escribe retos a mano

create temp table resultados_retos (
  n int, prueba text, esperado text, obtenido text, ok boolean
);

do $test$
declare
  v_gala  uuid := 'a4a44444-4444-4444-8444-444444444444';
  v_hugo  uuid := 'b5b55555-5555-4555-8555-555555555555';
  v_ines  uuid := 'c6c66666-6666-4666-8666-666666666666';
  v_media text := 'https://bfqzabpgtehncnbxtslg.supabase.co/storage/v1/object/public/publicaciones/prueba/';
  v_noche date := privado.noche_actual();
  v_local uuid;
  v_otro  uuid;
  v_fiesta uuid;
  v_sol   uuid;
  v_dm    uuid;
  v_reto  uuid;
  v_post  uuid;
  v_txt   text;
  v_int   int;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at,
                          raw_user_meta_data)
  values
    (v_gala, '00000000-0000-0000-0000-000000000000','authenticated',
     'authenticated','gala@previa.test','x', now(), now(), now(),
     jsonb_build_object('username','gala_test','display_name','Gala',
                        'birth_date','2000-03-03')),
    (v_hugo, '00000000-0000-0000-0000-000000000000','authenticated',
     'authenticated','hugo@previa.test','x', now(), now(), now(),
     jsonb_build_object('username','hugo_test','display_name','Hugo',
                        'birth_date','1999-04-04')),
    (v_ines, '00000000-0000-0000-0000-000000000000','authenticated',
     'authenticated','ines@previa.test','x', now(), now(), now(),
     jsonb_build_object('username','ines_test','display_name','Ines',
                        'birth_date','1998-05-05'));

  insert into public.venues (name, city) values ('Sala de prueba','Ciudad de prueba')
  returning id into v_local;
  insert into public.venues (name, city) values ('Otra sala','Ciudad de prueba')
  returning id into v_otro;

  -- 35-37: solicitudes -----------------------------------------------------
  insert into public.parties (host_id, title, area_label, location, location_fuzzed,
                              starts_at, spots_total)
  values (v_gala,'Previa de prueba','Centro',
          extensions.ST_SetSRID(extensions.ST_Point(-0.88, 41.65), 4326)::extensions.geography,
          extensions.ST_SetSRID(extensions.ST_Point(-0.88, 41.65), 4326)::extensions.geography,
          now() + interval '4 hours', 5)
  returning id into v_fiesta;
  insert into public.join_requests (party_id, requester_id, group_size)
  values (v_fiesta, v_hugo, 1) returning id into v_sol;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_hugo,'role','authenticated')::text, true);
  begin
    update public.join_requests set status = 'accepted' where id = v_sol;
    execute 'reset role';
    insert into resultados_retos values
      (35,'El solicitante no se acepta a si mismo','denegado','se ha aceptado', false);
  exception when others then
    execute 'reset role';
    insert into resultados_retos values
      (35,'El solicitante no se acepta a si mismo','denegado','denegado', true);
  end;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_hugo,'role','authenticated')::text, true);
  begin
    update public.join_requests set party_id = v_fiesta where id = v_sol;
    execute 'reset role';
    insert into resultados_retos values
      (36,'Una solicitud no se muda de previa','denegado','lo ha hecho', false);
  exception when others then
    execute 'reset role';
    insert into resultados_retos values
      (36,'Una solicitud no se muda de previa','denegado','denegado', true);
  end;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_gala,'role','authenticated')::text, true);
  update public.join_requests set status = 'accepted' where id = v_sol;
  execute 'reset role';
  select count(*)::int into v_int from public.party_members
   where party_id = v_fiesta and profile_id = v_hugo;
  insert into resultados_retos values
    (37,'El anfitrion si acepta','1 asistente', v_int::text, v_int = 1);

  -- 38: mensajes ------------------------------------------------------------
  insert into public.follows (follower_id, followee_id) values (v_gala, v_hugo);
  insert into public.direct_messages (sender_id, recipient_id, body)
  values (v_gala, v_hugo, 'Hola') returning id into v_dm;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_hugo,'role','authenticated')::text, true);
  begin
    update public.direct_messages set body = 'Te odio' where id = v_dm;
    execute 'reset role';
    insert into resultados_retos values
      (38,'Quien recibe no reescribe el mensaje','denegado','reescrito', false);
  exception when others then
    execute 'reset role';
    insert into resultados_retos values
      (38,'Quien recibe no reescribe el mensaje','denegado','denegado', true);
  end;

  -- 39-41: publicaciones ----------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_gala,'role','authenticated')::text, true);
  begin
    insert into public.posts (author_id, media_url, media_type, like_count)
    values (v_gala, v_media || 'a.jpg', 'photo', 9999);
    execute 'reset role';
    insert into resultados_retos values
      (39,'Una publicacion no nace con likes','denegado','creada', false);
  exception when others then
    execute 'reset role';
    insert into resultados_retos values
      (39,'Una publicacion no nace con likes','denegado','denegado', true);
  end;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_gala,'role','authenticated')::text, true);
  begin
    insert into public.posts (author_id, media_url, media_type)
    values (v_gala, 'https://rastreo.test/pixel.gif', 'photo');
    execute 'reset role';
    insert into resultados_retos values
      (40,'La media tiene que ser del proyecto','denegado','creada', false);
  exception when others then
    execute 'reset role';
    insert into resultados_retos values
      (40,'La media tiene que ser del proyecto','denegado','denegado', true);
  end;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_gala,'role','authenticated')::text, true);
  begin
    insert into public.posts (author_id, media_url, media_type, venue_id, night)
    values (v_gala, v_media || 'b.jpg', 'photo', v_otro, v_noche);
    execute 'reset role';
    insert into resultados_retos values
      (41,'No se sube a la sala de un local al que no vas','denegado','creada', false);
  exception when others then
    execute 'reset role';
    insert into resultados_retos values
      (41,'No se sube a la sala de un local al que no vas','denegado','denegado', true);
  end;

  -- 42: locales -------------------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_gala,'role','authenticated')::text, true);
  begin
    insert into public.venues (name, city, ticket_url)
    values ('Falsa','Ciudad de prueba','https://phishing.test');
    execute 'reset role';
    insert into resultados_retos values
      (42,'Un usuario no pone enlace de entradas','denegado','creado', false);
  exception when others then
    execute 'reset role';
    insert into resultados_retos values
      (42,'Un usuario no pone enlace de entradas','denegado','denegado', true);
  end;

  -- 43-44: el reparto no se llama desde la app y exige ir -------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_gala,'role','authenticated')::text, true);
  begin
    perform public.crear_reto(v_gala, v_local, 'Busca a {persona} ya', 'ia');
    execute 'reset role';
    insert into resultados_retos values
      (43,'La app no reparte retos por su cuenta','denegado','repartido', false);
  exception when others then
    execute 'reset role';
    insert into resultados_retos values
      (43,'La app no reparte retos por su cuenta','denegado','denegado', true);
  end;

  begin
    perform public.comprobar_reto(v_gala, v_local);
    insert into resultados_retos values
      (44,'Sin decir que vas no hay reto','NO_VAS','ha dejado', false);
  exception when others then
    insert into resultados_retos values
      (44,'Sin decir que vas no hay reto','NO_VAS', sqlerrm, sqlerrm = 'NO_VAS');
  end;

  -- 45-48: reparto -----------------------------------------------------------
  insert into public.venue_plans (venue_id, profile_id, night) values
    (v_local, v_gala, v_noche), (v_local, v_hugo, v_noche);

  v_txt := public.comprobar_reto(v_gala, v_local);
  v_reto := public.crear_reto(v_gala, v_local, 'Busca a {persona} y haceos una foto', 'ia');
  select prompt into v_txt from public.challenges where id = v_reto;
  insert into resultados_retos values
    (45,'Te toca quien esta en el local','Busca a Hugo…', v_txt,
     v_txt = 'Busca a Hugo y haceos una foto'
     and (select target_id from public.challenges where id = v_reto) = v_hugo);

  begin
    perform public.crear_reto(v_gala, v_local, 'Otra vez {persona}', 'ia');
    insert into resultados_retos values
      (46,'Un reto cada vez','YA_TIENES_RETO','otro reto', false);
  exception when others then
    insert into resultados_retos values
      (46,'Un reto cada vez','YA_TIENES_RETO', sqlerrm, sqlerrm = 'YA_TIENES_RETO');
  end;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_hugo,'role','authenticated')::text, true);
  select count(*)::int into v_int from public.challenges;
  execute 'reset role';
  insert into resultados_retos values
    (47,'El objetivo no ve el reto antes de tiempo','0', v_int::text, v_int = 0);

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_gala,'role','authenticated')::text, true);
  select objetivo_usuario into v_txt from public.mi_reto(v_local);
  execute 'reset role';
  insert into resultados_retos values
    (48,'El jugador ve su reto con la ficha del objetivo','hugo_test',
     coalesce(v_txt,'nada'), v_txt = 'hugo_test');

  -- 49-50: cumplir y quitar la foto -------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_gala,'role','authenticated')::text, true);
  insert into public.posts (author_id, media_url, media_type, venue_id, night)
  values (v_gala, v_media || 'reto.jpg', 'photo', v_local, v_noche)
  returning id into v_post;
  perform public.completar_reto(v_reto, v_post);
  execute 'reset role';
  select count(*)::int into v_int from public.notices
   where profile_id = v_hugo and kind = 'reto' and post_id = v_post;
  insert into resultados_retos values
    (49,'Cumplir avisa al objetivo','1 aviso', v_int::text,
     v_int = 1
     and (select status from public.challenges where id = v_reto) = 'hecho');

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_hugo,'role','authenticated')::text, true);
  perform public.quitar_foto_de_reto(v_reto);
  execute 'reset role';
  select count(*)::int into v_int from public.posts where id = v_post;
  insert into resultados_retos values
    (50,'El objetivo puede quitar la foto','0', v_int::text, v_int = 0);

  -- 51-52: bloqueo y no querer jugar ---------------------------------------
  insert into public.blocks (blocker_id, blocked_id) values (v_hugo, v_gala);
  begin
    perform public.comprobar_reto(v_gala, v_local);
    insert into resultados_retos values
      (51,'Con bloqueo no te toca esa persona','NO_HAY_NADIE','ha tocado', false);
  exception when others then
    insert into resultados_retos values
      (51,'Con bloqueo no te toca esa persona','NO_HAY_NADIE', sqlerrm, sqlerrm = 'NO_HAY_NADIE');
  end;
  delete from public.blocks where blocker_id = v_hugo;

  update public.profiles set plays_challenges = false where id = v_hugo;
  begin
    perform public.comprobar_reto(v_gala, v_local);
    insert into resultados_retos values
      (52,'Quien no juega no sale en retos','NO_HAY_NADIE','ha tocado', false);
  exception when others then
    insert into resultados_retos values
      (52,'Quien no juega no sale en retos','NO_HAY_NADIE', sqlerrm, sqlerrm = 'NO_HAY_NADIE');
  end;
  update public.profiles set plays_challenges = true where id = v_hugo;

  -- 53-54: rajarse y escribir a mano ------------------------------------------
  v_reto := public.crear_reto(v_gala, v_local, 'Busca a {persona} otra vez', 'plantilla');
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_gala,'role','authenticated')::text, true);
  perform public.rajarse(v_reto);
  execute 'reset role';
  select status::text into v_txt from public.challenges where id = v_reto;
  insert into resultados_retos values
    (53,'Rajarse cierra el reto','rajado', v_txt, v_txt = 'rajado');

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_gala,'role','authenticated')::text, true);
  begin
    update public.challenges set status = 'hecho' where id = v_reto;
    get diagnostics v_int = row_count;
    execute 'reset role';
    insert into resultados_retos values
      (54,'Un reto no se da por hecho a mano','denegado',
       v_int || ' filas', v_int = 0);
  exception when others then
    execute 'reset role';
    insert into resultados_retos values
      (54,'Un reto no se da por hecho a mano','denegado','denegado', true);
  end;

  -- Limpieza -----------------------------------------------------------------
  delete from public.venues where id in (v_local, v_otro);
  delete from auth.users where id in (v_gala, v_hugo, v_ines);
end;
$test$;

select n, prueba, esperado, obtenido,
       case when ok then 'PASA' else 'FALLA' end as resultado
from resultados_retos order by n;

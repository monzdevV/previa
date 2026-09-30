-- Previa · Bateria de pruebas del modelo de seguridad
--
-- Crea tres usuarios ficticios (Ana, Bea y Carlos), ejerce las politicas de
-- seguridad desde el punto de vista de cada uno y borra los datos al terminar.
--
-- Como ejecutarla: pegar el contenido en el editor SQL de Supabase.
-- Resultado esperado: 38 filas, todas con resultado PASA (1-16 originales, 17-38 nuevas).
--
-- Que demuestra cada prueba:
--   1      el disparador de alta de perfil funciona
--   2      la barrera de mayoria de edad funciona
--   3-5    se crean previas y la ubicacion se difumina de verdad
--   6, 15  los privilegios de columna ocultan location y birth_date
--   7-8    un extrano ve la previa pero no su direccion
--   9-12   el recorrido de solicitud y aceptacion, y el revelado de direccion
--   13     el chat es privado para los miembros
--   14     el bloqueo oculta por completo al bloqueado
--   16     la busqueda geografica encuentra lo que debe

create temp table resultados (n int, prueba text, esperado text, obtenido text, ok boolean);

do $test$
declare
  v_ana    uuid := '11111111-1111-1111-1111-111111111111';
  v_bea    uuid := '22222222-2222-2222-2222-222222222222';
  v_carlos uuid := '33333333-3333-3333-3333-333333333333';
  v_previa uuid;
  v_sol    uuid;
  v_txt    text;
  v_num    numeric;
  v_int    int;
begin
  -- Alta de usuarios (dispara handle_new_user) --------------------------------
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at, raw_user_meta_data)
  values
    (v_ana, '00000000-0000-0000-0000-000000000000','authenticated','authenticated',
     'ana@previa.test','x', now(), now(), now(),
     jsonb_build_object('username','ana_test','display_name','Ana','birth_date','2000-05-10')),
    (v_bea, '00000000-0000-0000-0000-000000000000','authenticated','authenticated',
     'bea@previa.test','x', now(), now(), now(),
     jsonb_build_object('username','bea_test','display_name','Bea','birth_date','2001-03-22')),
    (v_carlos, '00000000-0000-0000-0000-000000000000','authenticated','authenticated',
     'carlos@previa.test','x', now(), now(), now(),
     jsonb_build_object('username','carlos_test','display_name','Carlos','birth_date','1999-11-02'));

  select count(*)::int into v_int from public.profiles where id in (v_ana, v_bea, v_carlos);
  insert into resultados values (1,'El registro crea el perfil automaticamente','3', v_int::text, v_int = 3);

  -- Mayoria de edad -----------------------------------------------------------
  begin
    update public.profiles set birth_date = current_date - interval '16 years' where id = v_ana;
    insert into resultados values (2,'Un menor de 18 es rechazado','error','sin error', false);
  exception when others then
    insert into resultados values (2,'Un menor de 18 es rechazado','error','error '||sqlstate, true);
  end;

  -- Ana crea una previa en Triana ---------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_ana,'role','authenticated')::text, true);
  insert into public.parties (host_id, title, description, area_label, location,
                              location_fuzzed, starts_at, spots_total, vibe)
  values (v_ana,'Previa en Triana','Somos 4, caben 3 mas','Triana',
          extensions.ST_SetSRID(extensions.ST_Point(-6.0025, 37.3820), 4326)::extensions.geography,
          extensions.ST_SetSRID(extensions.ST_Point(-6.0025, 37.3820), 4326)::extensions.geography,
          now() + interval '5 hours', 3, array['reggaeton','tranqui'])
  returning id into v_previa;
  execute 'reset role';
  insert into resultados values (3,'Se puede crear una previa','creada', coalesce(v_previa::text,'null'), v_previa is not null);

  select count(*)::int into v_int from public.party_members
   where party_id = v_previa and profile_id = v_ana and role = 'host';
  insert into resultados values (4,'El anfitrion es miembro de su previa','1', v_int::text, v_int = 1);

  select round(extensions.ST_Distance(location, location_fuzzed)::numeric,1) into v_num
    from public.parties where id = v_previa;
  insert into resultados values (5,'La ubicacion se difumina (0 a 300 m)','0 < d <= 300',
    v_num::text||' m', v_num > 0 and v_num <= 300);

  -- Privilegio de columna: nadie lee parties.location -------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_bea,'role','authenticated')::text, true);
  begin
    execute 'select location::text from public.parties limit 1' into v_txt;
    execute 'reset role';
    insert into resultados values (6,'authenticated NO puede leer parties.location','denegado','lo ha leido', false);
  exception when insufficient_privilege then
    execute 'reset role';
    insert into resultados values (6,'authenticated NO puede leer parties.location','denegado','denegado', true);
  end;

  -- Un extrano ve la previa pero no su direccion ------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_bea,'role','authenticated')::text, true);
  select count(*)::int into v_int from public.parties where id = v_previa;
  execute 'reset role';
  insert into resultados values (7,'Un extrano ve la previa abierta','1', v_int::text, v_int = 1);

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_bea,'role','authenticated')::text, true);
  begin
    perform public.ubicacion_exacta(v_previa);
    execute 'reset role';
    insert into resultados values (8,'Un extrano NO obtiene la direccion exacta','error','la ha obtenido', false);
  exception when insufficient_privilege then
    execute 'reset role';
    insert into resultados values (8,'Un extrano NO obtiene la direccion exacta','error','error', true);
  end;

  -- Bea solicita plaza para 2 --------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_bea,'role','authenticated')::text, true);
  insert into public.join_requests (party_id, requester_id, group_size, message)
  values (v_previa, v_bea, 2, 'Somos 2, nos pasamos?') returning id into v_sol;
  execute 'reset role';
  insert into resultados values (9,'Se puede solicitar plaza','creada', coalesce(v_sol::text,'null'), v_sol is not null);

  -- Ana acepta -----------------------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_ana,'role','authenticated')::text, true);
  update public.join_requests set status = 'accepted' where id = v_sol;
  execute 'reset role';

  select spots_taken::int into v_int from public.parties where id = v_previa;
  insert into resultados values (10,'Aceptar suma las plazas del grupo','2', v_int::text, v_int = 2);

  select count(*)::int into v_int from public.party_members where party_id = v_previa and profile_id = v_bea;
  insert into resultados values (11,'Aceptar crea la pertenencia','1', v_int::text, v_int = 1);

  -- Ahora Bea si ve la direccion ------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_bea,'role','authenticated')::text, true);
  select round(lat::numeric,4) into v_num from public.ubicacion_exacta(v_previa);
  execute 'reset role';
  insert into resultados values (12,'Aceptada, Bea SI ve la direccion exacta','37.3820', v_num::text, v_num = 37.3820);

  -- Chat ------------------------------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_bea,'role','authenticated')::text, true);
  insert into public.messages (party_id, sender_id, body) values (v_previa, v_bea, 'Genial, llevamos bebida');
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_carlos,'role','authenticated')::text, true);
  select count(*)::int into v_int from public.messages where party_id = v_previa;
  execute 'reset role';
  insert into resultados values (13,'Carlos, que no va, NO lee el chat','0', v_int::text, v_int = 0);

  -- Bloqueo -----------------------------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_ana,'role','authenticated')::text, true);
  insert into public.blocks (blocker_id, blocked_id) values (v_ana, v_carlos);
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_carlos,'role','authenticated')::text, true);
  select count(*)::int into v_int from public.parties where id = v_previa;
  execute 'reset role';
  insert into resultados values (14,'Bloqueado, Carlos deja de ver la previa','0', v_int::text, v_int = 0);

  -- birth_date nunca es legible -------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_ana,'role','authenticated')::text, true);
  begin
    execute 'select birth_date::text from public.profiles limit 1' into v_txt;
    execute 'reset role';
    insert into resultados values (15,'Nadie puede leer profiles.birth_date','denegado','lo ha leido', false);
  exception when insufficient_privilege then
    execute 'reset role';
    insert into resultados values (15,'Nadie puede leer profiles.birth_date','denegado','denegado', true);
  end;

  -- Busqueda geografica ------------------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_bea,'role','authenticated')::text, true);
  select count(*)::int into v_int from public.previas_cerca(37.3826, -6.0020, 5000, 12, 1::smallint);
  execute 'reset role';
  insert into resultados values (16,'La busqueda por cercania encuentra la previa','1', v_int::text, v_int = 1);

  -- Limpieza -------------------------------------------------------------------------
  delete from auth.users where id in (v_ana, v_bea, v_carlos);
end;
$test$;

-- =============================================================================
-- Pruebas 17-38: fecha de nacimiento, limitacion de frecuencia, cautela por
-- reportes, permisos, caducidad programada y eliminar_mi_cuenta.
--
--   17-21  birth_date: no NULL, no cambiar, mismo valor OK, onboarding OK,
--          cambio controlado (service role / SQL) OK
--   22-25  limites de frecuencia: chat, reportes, previas, solicitudes
--   26-29  3 reportes distintos ocultan la previa y bloquean a la persona
--   30-32  la revision de reportes y la moderacion son solo service role
--   33     levantar la cautela devuelve la visibilidad
--   34     pg_cron tiene el job programado
--   35-38  eliminar_mi_cuenta: libera plazas, borra foto, no toca datos ajenos
-- =============================================================================
do $test2$
declare
  v_dani  uuid := '44444444-4444-4444-4444-444444444444';
  v_eva   uuid := '55555555-5555-5555-5555-555555555555';
  v_fran  uuid := '66666666-6666-6666-6666-666666666666';
  v_gus   uuid := '77777777-7777-7777-7777-777777777777';
  v_hugo  uuid := '88888888-8888-8888-8888-888888888888';
  v_ivan  uuid := '99999999-9999-9999-9999-999999999999';
  v_jose  uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_kira  uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  v_p     uuid[] := '{}';
  v_id    uuid;
  v_int   int;
  v_int2  int;
  v_bool  boolean;
  v_txt   text;
  i       int;
  v_fallo int;
begin
  -- Sin sesion de usuario: auth.uid() nulo (como service role o SQL editor).
  perform set_config('request.jwt.claims', '', true);

  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at, raw_user_meta_data)
  select u.id, '00000000-0000-0000-0000-000000000000','authenticated','authenticated',
         u.nombre||'@previa.test','x', now(), now(), now(),
         jsonb_build_object('username', u.nombre||'_t2', 'display_name', u.nombre)
         || case when u.nac is null then '{}'::jsonb else jsonb_build_object('birth_date', u.nac) end
    from (values (v_dani,'dani','1990-01-01'), (v_eva,'eva','1995-02-02'),
                 (v_fran,'fran','1996-03-03'), (v_gus,'gus','1997-04-04'),
                 (v_hugo,'hugo','1992-05-05'), (v_ivan,'ivan','1993-06-06'),
                 (v_jose,'jose','1994-07-07'), (v_kira,'kira',null)) as u(id, nombre, nac);

  -- Dani es anfitrion de 22 previas (insertadas sin sesion: sin limite).
  for i in 1..22 loop
    insert into public.parties (host_id, title, area_label, location, location_fuzzed,
                                starts_at, spots_total)
    values (v_dani, 'Previa de prueba '||i, 'Centro',
            extensions.ST_SetSRID(extensions.ST_Point(-6.0, 37.38), 4326)::extensions.geography,
            extensions.ST_SetSRID(extensions.ST_Point(-6.0, 37.38), 4326)::extensions.geography,
            now() + interval '5 hours', 5)
    returning id into v_id;
    v_p := v_p || v_id;
  end loop;

  -- 17. birth_date no se puede poner a NULL ------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_dani,'role','authenticated')::text, true);
  begin
    update public.profiles set birth_date = null where id = v_dani;
    execute 'reset role';
    insert into resultados values (17,'birth_date no puede ponerse a NULL','error','sin error', false);
  exception when insufficient_privilege then
    execute 'reset role';
    insert into resultados values (17,'birth_date no puede ponerse a NULL','error','error', true);
  end;

  -- 18. ni cambiarse a otra fecha valida -----------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_dani,'role','authenticated')::text, true);
  begin
    update public.profiles set birth_date = '1985-01-01' where id = v_dani;
    execute 'reset role';
    insert into resultados values (18,'birth_date no puede cambiarse a otra fecha','error','sin error', false);
  exception when insufficient_privilege then
    execute 'reset role';
    insert into resultados values (18,'birth_date no puede cambiarse a otra fecha','error','error', true);
  end;

  -- 19. reescribir el mismo valor es inocuo ----------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_dani,'role','authenticated')::text, true);
  begin
    update public.profiles set birth_date = '1990-01-01' where id = v_dani;
    execute 'reset role';
    insert into resultados values (19,'Reenviar la misma fecha se admite','sin error','sin error', true);
  exception when others then
    execute 'reset role';
    insert into resultados values (19,'Reenviar la misma fecha se admite','sin error','error '||sqlstate, false);
  end;

  -- 20. onboarding: NULL -> fecha permitido una vez -----------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_kira,'role','authenticated')::text, true);
  update public.profiles set birth_date = '1998-08-08' where id = v_kira;
  execute 'reset role';
  select onboarded into v_bool from public.profiles where id = v_kira;
  insert into resultados values (20,'Completar la fecha por primera vez (onboarding) funciona','onboarded=true', v_bool::text, v_bool);

  -- 21. cambio controlado: sin sesion de usuario (service role / SQL) ---------------
  perform set_config('request.jwt.claims', '', true);
  begin
    update public.profiles set birth_date = '1990-01-02' where id = v_dani;
    insert into resultados values (21,'Cambio controlado de birth_date sin sesion de usuario','permitido','permitido', true);
  exception when others then
    insert into resultados values (21,'Cambio controlado de birth_date sin sesion de usuario','permitido','error '||sqlstate, false);
  end;

  -- 22. limite de chat: 30 por minuto -------------------------------------------------------
  -- Cada insercion va en su propio sub-bloque: si el limite salta, las anteriores
  -- se conservan y se puede comprobar cuantas entraron.
  v_fallo := 0;
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_dani,'role','authenticated')::text, true);
  for i in 1..31 loop
    begin
      insert into public.messages (party_id, sender_id, body) values (v_p[2], v_dani, 'mensaje '||i);
    exception when program_limit_exceeded then
      v_fallo := i; exit;
    end;
  end loop;
  execute 'reset role';
  select count(*)::int into v_int from public.messages where sender_id = v_dani;
  insert into resultados values (22,'El mensaje 31 en un minuto se rechaza','falla el 31, 30 guardados', 'falla el '||v_fallo||', '||v_int||' guardados', v_fallo = 31 and v_int = 30);

  -- 23. limite de reportes: 10 por dia --------------------------------------------------------
  v_fallo := 0;
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_kira,'role','authenticated')::text, true);
  for i in 1..11 loop
    begin
      insert into public.reports (reporter_id, reported_id, reason) values (v_kira, v_hugo, 'spam');
    exception when program_limit_exceeded then
      v_fallo := i; exit;
    end;
  end loop;
  execute 'reset role';
  select count(*)::int into v_int from public.reports where reporter_id = v_kira;
  insert into resultados values (23,'El reporte 11 en un dia se rechaza','falla el 11, 10 guardados', 'falla el '||v_fallo||', '||v_int||' guardados', v_fallo = 11 and v_int = 10);

  -- 24. limite de previas: 5 por dia ----------------------------------------------------------
  v_fallo := 0;
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_hugo,'role','authenticated')::text, true);
  for i in 1..6 loop
    begin
      insert into public.parties (host_id, title, area_label, location, location_fuzzed,
                                  starts_at, spots_total)
      values (v_hugo, 'Hugo '||i, 'Centro',
              extensions.ST_SetSRID(extensions.ST_Point(-6.0, 37.38), 4326)::extensions.geography,
              extensions.ST_SetSRID(extensions.ST_Point(-6.0, 37.38), 4326)::extensions.geography,
              now() + interval '5 hours', 3);
    exception when program_limit_exceeded then
      v_fallo := i; exit;
    end;
  end loop;
  execute 'reset role';
  select count(*)::int into v_int from public.parties where host_id = v_hugo;
  insert into resultados values (24,'La previa 6 en un dia se rechaza','falla la 6, 5 creadas', 'falla la '||v_fallo||', '||v_int||' creadas', v_fallo = 6 and v_int = 5);

  -- 25. limite de solicitudes: 20 por hora ------------------------------------------------------
  v_fallo := 0;
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_eva,'role','authenticated')::text, true);
  for i in 1..21 loop
    begin
      insert into public.join_requests (party_id, requester_id, group_size) values (v_p[i], v_eva, 1);
    exception when program_limit_exceeded then
      v_fallo := i; exit;
    end;
  end loop;
  execute 'reset role';
  select count(*)::int into v_int from public.join_requests where requester_id = v_eva;
  insert into resultados values (25,'La solicitud 21 en una hora se rechaza','falla la 21, 20 creadas', 'falla la '||v_fallo||', '||v_int||' creadas', v_fallo = 21 and v_int = 20);

  -- 26. tres reportes DISTINTOS ocultan una previa ----------------------------------------------
  -- v_p[1] es de Dani. Un mismo reportante repetido NO cuenta: Eva reporta dos veces.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_eva,'role','authenticated')::text, true);
  insert into public.reports (reporter_id, party_id, reason) values (v_eva, v_p[1], 'spam');
  insert into public.reports (reporter_id, party_id, reason) values (v_eva, v_p[1], 'acoso');
  execute 'reset role';
  select count(*)::int into v_int from public.moderacion_cautelar where objeto_id = v_p[1] and levantado_en is null;
  insert into resultados values (26,'Un solo reportante (aunque repita) no activa la cautela','0', v_int::text, v_int = 0);

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_fran,'role','authenticated')::text, true);
  insert into public.reports (reporter_id, party_id, reason) values (v_fran, v_p[1], 'spam');
  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_gus,'role','authenticated')::text, true);
  insert into public.reports (reporter_id, party_id, reason) values (v_gus, v_p[1], 'spam');
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_hugo,'role','authenticated')::text, true);
  select count(*)::int into v_int  from public.parties where id = v_p[1];
  select count(*)::int into v_int2 from public.previas_cerca(37.38, -6.0, 5000, 12, 1::smallint) where id = v_p[1];
  execute 'reset role';
  insert into resultados values (27,'Con 3 reportantes distintos la previa se oculta a extranos','0 y 0', v_int||' y '||v_int2, v_int = 0 and v_int2 = 0);

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_dani,'role','authenticated')::text, true);
  select count(*)::int into v_int from public.parties where id = v_p[1];
  execute 'reset role';
  insert into resultados values (28,'El anfitrion sigue viendo su previa oculta','1', v_int::text, v_int = 1);

  -- 29. tres reportantes distintos contra una PERSONA la bloquean cautelarmente -------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_eva,'role','authenticated')::text, true);
  insert into public.reports (reporter_id, reported_id, reason) values (v_eva, v_ivan, 'acoso');
  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_fran,'role','authenticated')::text, true);
  insert into public.reports (reporter_id, reported_id, reason) values (v_fran, v_ivan, 'acoso');
  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_gus,'role','authenticated')::text, true);
  insert into public.reports (reporter_id, reported_id, reason) values (v_gus, v_ivan, 'acoso');
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_ivan,'role','authenticated')::text, true);
  begin
    insert into public.parties (host_id, title, area_label, location, location_fuzzed,
                                starts_at, spots_total)
    values (v_ivan, 'Previa de Ivan', 'Centro',
            extensions.ST_SetSRID(extensions.ST_Point(-6.0, 37.38), 4326)::extensions.geography,
            extensions.ST_SetSRID(extensions.ST_Point(-6.0, 37.38), 4326)::extensions.geography,
            now() + interval '5 hours', 3);
    execute 'reset role';
    insert into resultados values (29,'Una persona con 3 reportes distintos no puede crear previas','error','sin error', false);
  exception when insufficient_privilege then
    execute 'reset role';
    insert into resultados values (29,'Una persona con 3 reportes distintos no puede crear previas','error','error', true);
  end;

  -- 30-32. revision de reportes y cautela: solo service role -----------------------------------------
  execute 'set local role authenticated';
  begin
    perform 1 from public.revision_reportes limit 1;
    execute 'reset role';
    insert into resultados values (30,'authenticated NO puede leer revision_reportes','denegado','lo ha leido', false);
  exception when insufficient_privilege then
    execute 'reset role';
    insert into resultados values (30,'authenticated NO puede leer revision_reportes','denegado','denegado', true);
  end;

  execute 'set local role service_role';
  begin
    select count(*)::int into v_int from public.revision_reportes where party_id = v_p[1];
    execute 'reset role';
    insert into resultados values (31,'service_role SI lee revision_reportes (ve 4 filas de la previa)','4', v_int::text, v_int = 4);
  exception when others then
    execute 'reset role';
    insert into resultados values (31,'service_role SI lee revision_reportes (ve 4 filas de la previa)','4','error '||sqlstate, false);
  end;

  select (has_function_privilege('authenticated','public.levantar_cautela(text,uuid)','execute')
       or has_function_privilege('authenticated','public.poner_cautela(text,uuid,text)','execute')
       or has_function_privilege('anon','public.levantar_cautela(text,uuid)','execute')
       or has_function_privilege('authenticated','public.caducar_previas()','execute')
       or has_function_privilege('anon','public.eliminar_mi_cuenta()','execute'))
    into v_bool;
  insert into resultados values (32,'Funciones de moderacion/caducidad no ejecutables por clientes; anon no borra cuentas','false', v_bool::text, not v_bool);

  -- Levantar la cautela devuelve la visibilidad y cierra los reportes.
  perform public.levantar_cautela('previa', v_p[1]);
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_hugo,'role','authenticated')::text, true);
  select count(*)::int into v_int from public.parties where id = v_p[1];
  execute 'reset role';
  insert into resultados values (33,'Levantar la cautela devuelve la previa a la vista','1', v_int::text, v_int = 1);

  -- 34. el job de pg_cron existe y es horario -------------------------------------------------------------
  select count(*)::int into v_int from cron.job
   where jobname = 'caducar-previas' and schedule = '7 * * * *' and command ilike '%caducar_previas%';
  insert into resultados values (34,'caducar_previas() esta programada cada hora en pg_cron','1', v_int::text, v_int = 1);

  -- 35-38. eliminar_mi_cuenta -----------------------------------------------------------------------------
  -- Jose entra en una previa de Dani, tiene foto, y existen datos de la otra app ajenos a el.
  perform set_config('request.jwt.claims', '', true);
  insert into public.follows (follower_id, followee_id) values (v_eva, v_dani);
  insert into storage.objects (bucket_id, name) values ('avatars', v_jose::text||'/foto');
  insert into storage.objects (bucket_id, name) values ('avatars', v_dani::text||'/foto');
  insert into public.join_requests (party_id, requester_id, group_size) values (v_p[3], v_jose, 1);

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_dani,'role','authenticated')::text, true);
  update public.join_requests set status = 'accepted' where party_id = v_p[3] and requester_id = v_jose;
  execute 'reset role';
  select spots_taken::int into v_int from public.parties where id = v_p[3];
  select count(*)::int into v_int2 from public.posts;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',v_jose,'role','authenticated')::text, true);
  perform public.eliminar_mi_cuenta();
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);

  select count(*)::int into v_int from public.profiles p where p.id = v_jose;
  insert into resultados values (35,'eliminar_mi_cuenta borra perfil y cuenta','0 perfiles', v_int||' perfiles',
    v_int = 0 and not exists (select 1 from auth.users where id = v_jose));

  select count(*)::int into v_int from storage.objects where bucket_id='avatars' and name like v_jose::text||'/%';
  select count(*)::int into v_int2 from storage.objects where bucket_id='avatars' and name like v_dani::text||'/%';
  insert into resultados values (36,'Borra SU foto del bucket avatars y no la de otras personas','0 y 1', v_int||' y '||v_int2, v_int = 0 and v_int2 = 1);

  select spots_taken::int into v_int from public.parties where id = v_p[3];
  insert into resultados values (37,'Libera la plaza que ocupaba en la previa ajena','0', v_int::text, v_int = 0);

  select count(*)::int into v_int from public.follows where follower_id = v_eva and followee_id = v_dani;
  insert into resultados values (38,'No toca datos de otras personas (follows de la otra app)','1', v_int::text, v_int = 1);

  -- Limpieza -------------------------------------------------------------------------------------------------
  -- Storage rechaza DELETE directos salvo con este ajuste (solo esta transaccion).
  perform set_config('storage.allow_delete_query', 'true', true);
  delete from storage.objects where bucket_id='avatars' and name like v_dani::text||'/%';
  perform set_config('storage.allow_delete_query', 'false', true);
  delete from public.moderacion_cautelar where objeto_id = any(v_p) or objeto_id = v_ivan;
  delete from auth.users where id in (v_dani, v_eva, v_fran, v_gus, v_hugo, v_ivan, v_jose, v_kira);
end;
$test2$;

select n, prueba, esperado, obtenido,
       case when ok then 'PASA' else 'FALLA' end as resultado
from resultados order by n;

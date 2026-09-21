-- Previa · Bateria de pruebas del modelo de seguridad
--
-- Crea tres usuarios ficticios (Ana, Bea y Carlos), ejerce las politicas de
-- seguridad desde el punto de vista de cada uno y borra los datos al terminar.
--
-- Como ejecutarla: pegar el contenido en el editor SQL de Supabase.
-- Resultado esperado: 16 filas, todas con resultado PASA.
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

select n, prueba, esperado, obtenido,
       case when ok then 'PASA' else 'FALLA' end as resultado
from resultados order by n;

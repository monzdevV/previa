-- Previa · Bateria de pruebas de las ofertas en vivo
--
-- Continua la numeracion de seguridad_retos.sql (que acaba en la 57). Necesita
-- aplicada la migracion 20260930240000_ofertas_en_vivo.sql. Crea cuatro
-- usuarios ficticios (Gala duena del local, Hugo y Ines dentro, Joel fuera),
-- ejerce las politicas desde cada punto de vista y borra los datos al terminar.
--
-- Como ejecutarla: pegar el contenido en el editor SQL de Supabase.
-- Resultado esperado: 14 filas (58 a 71), todas con resultado PASA.
--
-- Que demuestra cada prueba:
--   58-60  solo el dueno crea, y el texto de alcohol se rechaza
--   61-62  la oferta solo la ve quien esta en el local (y el dueno)
--   63     el codigo de puerta no se puede leer con SELECT
--   64-67  canje: pide el QR, es unico por persona, respeta cupo y presencia
--   68     no se escribe en canjes a mano
--   69     limite de ofertas activas
--   70-71  solo el dueno valida un codigo

create temp table resultados_ofertas (
  n int, prueba text, esperado text, obtenido text, ok boolean
);

do $test$
declare
  v_gala  uuid := 'a1a11111-1111-4111-8111-111111111111';
  v_hugo  uuid := 'b2a22222-2222-4222-8222-222222222222';
  v_ines  uuid := 'c3a33333-3333-4333-8333-333333333333';
  v_joel  uuid := 'd4a44444-4444-4444-8444-444444444444';
  v_local uuid;
  v_oferta uuid;
  v_puerta text;
  v_codigo text;
  v_codigo2 text;
  v_int   int;
  v_txt   text;
  v_ok    boolean;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at,
                          raw_user_meta_data)
  select u.id, '00000000-0000-0000-0000-000000000000','authenticated',
         'authenticated', u.nombre || '@previa.test','x', now(), now(), now(),
         jsonb_build_object('username', u.nombre || '_ofe','display_name', u.nombre,
                            'birth_date','1999-01-01')
  from (values (v_gala,'gala'),(v_hugo,'hugo'),(v_ines,'ines'),(v_joel,'joel')) u(id, nombre);

  insert into public.venues (name, city, area_label)
  values ('Local de ofertas','Ciudad de prueba','Centro') returning id into v_local;

  insert into public.venue_owners (venue_id, profile_id) values (v_local, v_gala);
  insert into public.venue_plans (venue_id, profile_id, night, status)
  values (v_local, v_hugo, privado.noche_actual(), 'aqui'),
         (v_local, v_ines, privado.noche_actual(), 'aqui'),
         (v_local, v_joel, privado.noche_actual(), 'voy');

  -- 58: la duena crea una oferta ---------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_gala,'role','authenticated')::text, true);
  insert into public.venue_offers (venue_id, created_by, kind, title, ends_at,
                                   max_redemptions, verification)
  values (v_local, v_gala, 'entrada', 'Entrada gratis si llegas ya',
          now() + interval '30 minutes', 1, 'qr')
  returning id into v_oferta;
  select public.codigo_de_puerta(v_oferta) into v_puerta;
  execute 'reset role';
  insert into resultados_ofertas values
    (58,'La duena crea una oferta','creada', coalesce(v_oferta::text,'null'), v_oferta is not null);

  -- 59: quien no es dueno no crea ---------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_hugo,'role','authenticated')::text, true);
  begin
    insert into public.venue_offers (venue_id, created_by, kind, title, ends_at, max_redemptions)
    values (v_local, v_hugo, 'foto', 'Foto de grupo gratis', now() + interval '20 minutes', 5);
    execute 'reset role';
    insert into resultados_ofertas values (59,'Un no dueno no crea ofertas','denegado','lo ha hecho', false);
  exception when others then
    execute 'reset role';
    insert into resultados_ofertas values (59,'Un no dueno no crea ofertas','denegado','denegado', true);
  end;

  -- 60: el texto de alcohol se rechaza -----------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_gala,'role','authenticated')::text, true);
  begin
    insert into public.venue_offers (venue_id, created_by, kind, title, ends_at, max_redemptions)
    values (v_local, v_gala, 'experiencia', 'Barra libre media hora', now() + interval '30 minutes', 20);
    execute 'reset role';
    insert into resultados_ofertas values (60,'Se rechaza promover alcohol','denegado','lo ha hecho', false);
  exception when others then
    execute 'reset role';
    insert into resultados_ofertas values (60,'Se rechaza promover alcohol','denegado','denegado', true);
  end;

  -- 61: quien esta dentro la ve --------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_hugo,'role','authenticated')::text, true);
  select count(*)::int into v_int from public.venue_offers where id = v_oferta;
  execute 'reset role';
  insert into resultados_ofertas values (61,'Quien esta en el local ve la oferta','1', v_int::text, v_int = 1);

  -- 62: quien solo "va" (no esta) no la ve -----------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_joel,'role','authenticated')::text, true);
  select count(*)::int into v_int from public.venue_offers where id = v_oferta;
  execute 'reset role';
  insert into resultados_ofertas values (62,'Quien no esta dentro no ve la oferta','0', v_int::text, v_int = 0);

  -- 63: el codigo de puerta no se lee con SELECT -------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_hugo,'role','authenticated')::text, true);
  begin
    execute 'select door_code from public.venue_offers limit 1' into v_txt;
    execute 'reset role';
    insert into resultados_ofertas values (63,'El codigo de puerta no se lee','denegado','lo ha leido', false);
  exception when others then
    execute 'reset role';
    insert into resultados_ofertas values (63,'El codigo de puerta no se lee','denegado','denegado', true);
  end;

  -- 64: sin QR no se canjea una oferta con QR ------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_hugo,'role','authenticated')::text, true);
  begin
    perform public.canjear_oferta(v_oferta, null);
    execute 'reset role';
    insert into resultados_ofertas values (64,'Sin QR no se canjea','denegado','canjeada', false);
  exception when others then
    execute 'reset role';
    insert into resultados_ofertas values (64,'Sin QR no se canjea','denegado','denegado', true);
  end;

  -- 65: con el QR si, y repetir devuelve el mismo codigo ----------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_hugo,'role','authenticated')::text, true);
  v_codigo  := public.canjear_oferta(v_oferta, v_puerta);
  v_codigo2 := public.canjear_oferta(v_oferta, v_puerta);
  execute 'reset role';
  select count(*)::int into v_int from public.offer_redemptions
   where offer_id = v_oferta and profile_id = v_hugo;
  insert into resultados_ofertas values
    (65,'Un canje por persona y oferta','1 canje, mismo codigo',
     v_int || ' canje, ' || case when v_codigo = v_codigo2 then 'mismo codigo' else 'otro codigo' end,
     v_int = 1 and v_codigo = v_codigo2 and v_codigo is not null);

  -- 66: el cupo (1) se agota para la siguiente persona --------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_ines,'role','authenticated')::text, true);
  begin
    perform public.canjear_oferta(v_oferta, v_puerta);
    execute 'reset role';
    insert into resultados_ofertas values (66,'El cupo se respeta','denegado','canjeada', false);
  exception when others then
    execute 'reset role';
    insert into resultados_ofertas values (66,'El cupo se respeta','denegado','denegado', true);
  end;

  -- 67: quien no esta dentro no canjea aunque tenga el QR --------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_joel,'role','authenticated')::text, true);
  begin
    perform public.canjear_oferta(v_oferta, v_puerta);
    execute 'reset role';
    insert into resultados_ofertas values (67,'Fuera del local no se canjea','denegado','canjeada', false);
  exception when others then
    execute 'reset role';
    insert into resultados_ofertas values (67,'Fuera del local no se canjea','denegado','denegado', true);
  end;

  -- 68: no se escribe en canjes a mano ------------------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_ines,'role','authenticated')::text, true);
  begin
    insert into public.offer_redemptions (offer_id, profile_id, code)
    values (v_oferta, v_ines, 'TRAMPA');
    execute 'reset role';
    insert into resultados_ofertas values (68,'No se inserta en canjes a mano','denegado','lo ha hecho', false);
  exception when others then
    execute 'reset role';
    insert into resultados_ofertas values (68,'No se inserta en canjes a mano','denegado','denegado', true);
  end;

  -- 69: tope de dos ofertas activas ---------------------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_gala,'role','authenticated')::text, true);
  insert into public.venue_offers (venue_id, created_by, kind, title, ends_at, max_redemptions)
  values (v_local, v_gala, 'foto', 'Foto de grupo gratis', now() + interval '20 minutes', 10);
  begin
    insert into public.venue_offers (venue_id, created_by, kind, title, ends_at, max_redemptions)
    values (v_local, v_gala, 'guardarropa', 'Guardarropa gratis', now() + interval '20 minutes', 10);
    execute 'reset role';
    insert into resultados_ofertas values (69,'Maximo dos ofertas activas','denegado','tercera creada', false);
  exception when others then
    execute 'reset role';
    insert into resultados_ofertas values (69,'Maximo dos ofertas activas','denegado','denegado', true);
  end;

  -- 70: un cliente no valida codigos --------------------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_hugo,'role','authenticated')::text, true);
  v_ok := public.validar_canje(v_codigo);
  execute 'reset role';
  insert into resultados_ofertas values (70,'Un cliente no valida codigos','false', v_ok::text, v_ok = false);

  -- 71: la duena si ------------------------------------------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub',v_gala,'role','authenticated')::text, true);
  v_ok := public.validar_canje(v_codigo);
  execute 'reset role';
  insert into resultados_ofertas values (71,'La duena valida el codigo','true', v_ok::text, v_ok);

  -- Limpieza ---------------------------------------------------------------------------------------------
  delete from public.venues where id = v_local;
  delete from auth.users where id in (v_gala, v_hugo, v_ines, v_joel);
end;
$test$;

select n, prueba, esperado, obtenido,
       case when ok then 'PASA' else 'FALLA' end as resultado
from resultados_ofertas order by n;

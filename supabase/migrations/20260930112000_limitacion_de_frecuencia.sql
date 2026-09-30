-- Previa · limitacion de frecuencia en base de datos.
--
-- POR QUE: limitar solo en el cliente no frena a quien llama a la API REST
-- directamente. Se hace con disparadores BEFORE INSERT que cuentan las filas
-- recientes del propio usuario y reutilizan privado.limitar() (ya existente,
-- lo usa tambien la otra app). Es "best effort": dos inserciones exactamente
-- simultaneas podrian pasar ambas; para frenar spam es suficiente.
--
-- Si auth.uid() es null (service role, SQL editor, pg_cron) no se limita:
-- son operaciones de administracion, no de usuarios.
--
-- Limites:
--   previas creadas ........ 5 por dia y anfitrion
--   solicitudes de plaza ... 20 por hora y persona
--   mensajes de chat ....... 30 por minuto y persona
--   reportes ............... 10 por dia y persona
--
-- Indices: cada disparador cuenta por (usuario, fecha); sin ellos cada
-- insercion haria un recorrido completo de la tabla.

create index if not exists parties_host_created      on public.parties       (host_id, created_at desc);
create index if not exists join_requests_req_created on public.join_requests (requester_id, created_at desc);
create index if not exists messages_sender_created   on public.messages      (sender_id, created_at desc);
create index if not exists reports_reporter_created  on public.reports       (reporter_id, created_at desc);

create or replace function privado.frena_previas()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then return new; end if;
  perform privado.limitar((select count(*) from public.parties
      where host_id = auth.uid() and created_at > now() - interval '1 day'), 5, 'las previas');
  return new;
end;
$$;

create or replace function privado.frena_solicitudes()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then return new; end if;
  perform privado.limitar((select count(*) from public.join_requests
      where requester_id = auth.uid() and created_at > now() - interval '1 hour'), 20, 'las solicitudes');
  return new;
end;
$$;

create or replace function privado.frena_chat_previa()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then return new; end if;
  perform privado.limitar((select count(*) from public.messages
      where sender_id = auth.uid() and created_at > now() - interval '1 minute'), 30, 'el chat');
  return new;
end;
$$;

create or replace function privado.frena_reportes()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then return new; end if;
  perform privado.limitar((select count(*) from public.reports
      where reporter_id = auth.uid() and created_at > now() - interval '1 day'), 10, 'los reportes');
  return new;
end;
$$;

-- Funciones de disparador: nadie las llama por RPC.
revoke all on function privado.frena_previas()     from public, anon, authenticated;
revoke all on function privado.frena_solicitudes() from public, anon, authenticated;
revoke all on function privado.frena_chat_previa() from public, anon, authenticated;
revoke all on function privado.frena_reportes()    from public, anon, authenticated;

drop trigger if exists parties_frena       on public.parties;
drop trigger if exists join_requests_frena on public.join_requests;
drop trigger if exists messages_frena      on public.messages;
drop trigger if exists reports_frena       on public.reports;

create trigger parties_frena       before insert on public.parties       for each row execute function privado.frena_previas();
create trigger join_requests_frena before insert on public.join_requests for each row execute function privado.frena_solicitudes();
create trigger messages_frena      before insert on public.messages      for each row execute function privado.frena_chat_previa();
create trigger reports_frena       before insert on public.reports       for each row execute function privado.frena_reportes();

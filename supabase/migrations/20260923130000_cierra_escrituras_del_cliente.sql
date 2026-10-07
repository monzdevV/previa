-- Cierra escrituras que el cliente podia hacer y no debia.
--
-- Salio de la auditoria de seguridad previa a la beta. Lo grave era el
-- primer punto: un solicitante podia ponerse a si mismo en 'accepted', el
-- disparador le daba de alta como asistente y con eso ubicacion_exacta() le
-- entregaba la direccion. Rompia el invariante de privacidad entero.
--
-- El criterio es el mismo que ya seguia `parties`: privilegios columna a
-- columna, solo las que la app escribe de verdad.

-- 1. Solicitudes ----------------------------------------------------------

revoke insert, update on public.join_requests from authenticated;
grant insert (party_id, requester_id, group_size, message)
  on public.join_requests to authenticated;
grant update (status) on public.join_requests to authenticated;

-- Quien puede mover el estado y hacia donde. La politica UPDATE deja entrar
-- al anfitrion y al solicitante, pero no distinguia que puede hacer cada
-- uno: eso es lo que decide este disparador.
--
-- Se llama "a_guardia" para dispararse antes que join_requests_aceptar: los
-- BEFORE del mismo evento van por orden alfabetico, y la guardia tiene que
-- decir que no antes de que nadie de de alta a un asistente.
create or replace function privado.guardia_de_solicitud()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Sin sesion es el panel de Supabase o una funcion de servicio.
  if auth.uid() is null or new.status is not distinct from old.status then
    return new;
  end if;

  if privado.es_anfitrion(old.party_id, auth.uid()) then
    if old.status = 'pending' and new.status in ('accepted', 'rejected') then
      return new;
    end if;
  elsif old.requester_id = auth.uid() then
    if old.status = 'pending' and new.status = 'cancelled' then
      return new;
    end if;
  end if;

  raise exception 'No puedes cambiar esta solicitud de % a %.',
    old.status, new.status
    using errcode = 'insufficient_privilege';
end;
$$;

revoke execute on function privado.guardia_de_solicitud() from public;

drop trigger if exists join_requests_a_guardia on public.join_requests;
create trigger join_requests_a_guardia
  before update of status on public.join_requests
  for each row execute function privado.guardia_de_solicitud();

-- 2. Mensajes directos ------------------------------------------------------

-- El destinatario solo marca como leido. Antes podia reescribir el texto y
-- el remitente, y fabricar asi mensajes "de" otra persona.
revoke insert, update on public.direct_messages from authenticated;
grant insert (sender_id, recipient_id, body) on public.direct_messages to authenticated;
grant update (read_at) on public.direct_messages to authenticated;

-- 3. Publicaciones ----------------------------------------------------------

-- Fuera like_count, created_at e is_demo: likes inventados y fechas futuras
-- para quedarse arriba del feed.
revoke insert, update on public.posts from authenticated;
grant insert (author_id, media_url, media_type, caption, area_label,
              party_id, venue_id, night, thumbnail_url)
  on public.posts to authenticated;

-- La media tiene que ser del cubo del proyecto. Una URL externa convertia
-- cada publicacion en un pixel de rastreo con la IP de quien la mira.
alter table public.posts
  add constraint posts_media_del_proyecto check (
    is_demo
    or media_url like 'https://bfqzabpgtehncnbxtslg.supabase.co/storage/v1/object/public/publicaciones/%'
  ) not valid;

-- Colgar una foto "en" una previa o en la sala de un local exige haber
-- estado: si no, cualquiera aparece en el resumen de una noche ajena.
create or replace function privado.guardia_de_publicacion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  if new.party_id is not null
     and not privado.es_miembro(new.party_id, auth.uid()) then
    raise exception 'Solo publica en una previa quien va a ella.'
      using errcode = 'insufficient_privilege';
  end if;

  if new.venue_id is not null then
    if new.night is null
       or new.night not between privado.noche_actual() - 1 and privado.noche_actual() + 1
       or not exists (
         select 1 from public.venue_plans
          where venue_id = new.venue_id
            and profile_id = auth.uid()
            and night = new.night
       ) then
      raise exception 'Solo sube fotos a la sala quien ha dicho que va.'
        using errcode = 'insufficient_privilege';
    end if;
  end if;

  return new;
end;
$$;

revoke execute on function privado.guardia_de_publicacion() from public;

drop trigger if exists posts_guardia on public.posts;
create trigger posts_guardia
  before insert on public.posts
  for each row execute function privado.guardia_de_publicacion();

-- 4. Locales ----------------------------------------------------------------

-- Proponer un sitio si; ponerle enlace de entradas o coordenadas no. Un
-- enlace de entradas en una ficha que parece oficial es phishing servido.
-- Eso lo rellenan los moderadores desde el panel.
revoke insert, update on public.venues from authenticated;
grant insert (name, city, area_label, instagram) on public.venues to authenticated;

-- 5. Direccion exacta -------------------------------------------------------

-- La rama publica ignoraba bloqueos y previas ya pasadas o canceladas.
create or replace function public.ubicacion_exacta(p_party uuid)
returns table (lat double precision, lng double precision)
language plpgsql
stable
security definer
set search_path = 'public', 'extensions'
as $$
declare
  punto extensions.geography;
begin
  select p.location into punto
    from public.parties p
   where p.id = p_party
     and (
       p.host_id = auth.uid()
       or exists (
         select 1 from public.party_members m
          where m.party_id = p.id and m.profile_id = auth.uid()
       )
       or (
         p.is_public
         and p.status in ('open', 'full')
         and not privado.hay_bloqueo(auth.uid(), p.host_id)
       )
     );

  if punto is null then
    raise exception 'Sin acceso a la ubicacion exacta de esa previa'
      using errcode = 'insufficient_privilege';
  end if;

  return query
    select extensions.st_y(punto::extensions.geometry),
           extensions.st_x(punto::extensions.geometry);
end;
$$;

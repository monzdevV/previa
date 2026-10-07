-- Limites de frecuencia, noches validas para "voy" y cubos que no se listan.
--
-- Segunda tanda de la auditoria de seguridad previa a la beta. Nada de esto
-- era un agujero por si solo, pero con desconocidos dentro cada punto es
-- una forma barata de molestar.

-- 1. Limites de frecuencia -------------------------------------------------
--
-- En la base de datos y no en la app: un cliente modificado se salta
-- cualquier limite que viva en el telefono. Los topes estan pensados para
-- que una persona normal no los roce nunca y un bucle choque enseguida.

create or replace function privado.limitar(
  cuantos bigint,
  maximo integer,
  que text
) returns void
language plpgsql
set search_path = ''
as $$
begin
  if cuantos >= maximo then
    raise exception 'Vas demasiado rapido con %. Espera un poco.', que
      using errcode = 'program_limit_exceeded';
  end if;
end;
$$;

create or replace function privado.frena_mensajes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then return new; end if;
  perform privado.limitar(
    (select count(*) from public.direct_messages
      where sender_id = auth.uid() and created_at > now() - interval '1 minute'),
    30, 'los mensajes');
  return new;
end;
$$;

create or replace function privado.frena_sala()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then return new; end if;
  perform privado.limitar(
    (select count(*) from public.venue_messages
      where sender_id = auth.uid() and created_at > now() - interval '1 minute'),
    20, 'la sala');
  return new;
end;
$$;

create or replace function privado.frena_publicaciones()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then return new; end if;
  perform privado.limitar(
    (select count(*) from public.posts
      where author_id = auth.uid() and created_at > now() - interval '1 day'),
    40, 'las publicaciones');
  return new;
end;
$$;

create index if not exists venue_messages_por_autor_idx
  on public.venue_messages (sender_id, created_at desc);

drop trigger if exists direct_messages_frena on public.direct_messages;
create trigger direct_messages_frena before insert on public.direct_messages
  for each row execute function privado.frena_mensajes();

drop trigger if exists venue_messages_frena on public.venue_messages;
create trigger venue_messages_frena before insert on public.venue_messages
  for each row execute function privado.frena_sala();

drop trigger if exists posts_frena on public.posts;
create trigger posts_frena before insert on public.posts
  for each row execute function privado.frena_publicaciones();

-- 2. "Voy esta noche" es de esta noche -------------------------------------
--
-- Se aceptaba cualquier fecha. Eso dejaba entrar en la sala de un local
-- una noche pasada y convertia venue_plans en un calendario inventado.
-- Se admite tambien mañana para quien lo apunta antes de medianoche con
-- el reloj del telefono adelantado.
create or replace function privado.guardia_de_plan()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null
     and new.night not between privado.noche_actual() and privado.noche_actual() + 1 then
    raise exception 'Solo puedes decir que vas esta noche.'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists venue_plans_guardia on public.venue_plans;
create trigger venue_plans_guardia before insert on public.venue_plans
  for each row execute function privado.guardia_de_plan();

revoke execute on function privado.limitar(bigint, integer, text) from public;
revoke execute on function privado.frena_mensajes() from public;
revoke execute on function privado.frena_sala() from public;
revoke execute on function privado.frena_publicaciones() from public;
revoke execute on function privado.guardia_de_plan() from public;

-- 3. Los cubos no se listan -------------------------------------------------
--
-- Un cubo publico sirve sus URL sin ninguna politica de lectura. La que
-- habia solo servia para que cualquiera, incluso sin sesion, listara todos
-- los ficheros y sacara de las carpetas el id de cada usuario. Se sustituye
-- por una que deja a cada cual ver lo suyo, que es lo que necesita la
-- subida con reemplazo del avatar.
drop policy if exists "cualquiera ve la media" on storage.objects;
drop policy if exists "avatares visibles" on storage.objects;

create policy "ves solo tu carpeta"
  on storage.objects for select to authenticated
  using (
    bucket_id in ('publicaciones', 'avatares')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Las de UPDATE no tenian WITH CHECK: se podia mover un fichero propio a la
-- carpeta de otra persona.
drop policy if exists "actualizas solo lo tuyo" on storage.objects;
drop policy if exists "actualizo mi avatar" on storage.objects;

create policy "actualizas solo lo tuyo"
  on storage.objects for update to authenticated
  using (
    bucket_id in ('publicaciones', 'avatares')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id in ('publicaciones', 'avatares')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Duplicados de las generales de arriba.
drop policy if exists "subo mi avatar" on storage.objects;
drop policy if exists "borro mi avatar" on storage.objects;

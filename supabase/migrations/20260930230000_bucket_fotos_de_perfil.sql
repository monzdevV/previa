-- Fotos de perfil.
--
-- Bucket publico: las fotos se muestran en tarjetas, chat y valoraciones, y
-- firmar una URL por cada avatar encarece cada listado sin aportar nada, ya
-- que el perfil (nombre, foto, bio) ya es visible para cualquier usuario
-- autenticado. Lo que NO es publico es la escritura: cada persona solo puede
-- tocar la carpeta que lleva su propio id.
--
-- Limite de 2 MB y solo imagenes para evitar que el bucket se use como
-- almacen de ficheros arbitrarios.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- (storage.foldername(name))[1] es la primera carpeta de la ruta: el uid.
create policy "avatars_insertar_propio" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars'
              and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "avatars_actualizar_propio" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars'
         and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'avatars'
              and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "avatars_borrar_propio" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

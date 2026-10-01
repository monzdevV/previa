-- Lista de bloqueados con nombre.
--
-- La politica de profiles oculta el perfil de quien has bloqueado (es el
-- efecto buscado del bloqueo), asi que el cliente no puede hacer el join el
-- mismo. Esta funcion SECURITY DEFINER lo hace en el servidor y solo
-- devuelve los bloqueos del propio llamante, nunca los de otra persona.

create or replace function public.mis_bloqueados()
returns table (blocked_id uuid, display_name text, username text,
               avatar_url text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select b.blocked_id, p.display_name, p.username, p.avatar_url, b.created_at
  from public.blocks b
  join public.profiles p on p.id = b.blocked_id
  where b.blocker_id = (select auth.uid())
  order by b.created_at desc;
$$;

revoke all on function public.mis_bloqueados() from public, anon;
grant execute on function public.mis_bloqueados() to authenticated;

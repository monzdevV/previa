# Pendiente para el backend (pedido por el cliente)

## 1. RPC `mis_bloqueados()`

La pantalla "Usuarios bloqueados" necesita los nombres, pero la politica
"perfiles visibles salvo bloqueo" de `profiles` oculta justo a quien bloqueas,
asi que el cliente no puede hacer un join. Hasta que exista, el cliente cae a
leer `blocks` y muestra "Usuario bloqueado" sin nombre (funciona, pero es poco
claro).

Firma esperada (security definer, `set search_path = public`, solo `authenticated`):

```sql
create or replace function public.mis_bloqueados()
returns table (blocked_id uuid, display_name text, username text,
               avatar_url text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select b.blocked_id, p.display_name, p.username, p.avatar_url, b.created_at
  from public.blocks b join public.profiles p on p.id = b.blocked_id
  where b.blocker_id = auth.uid()
  order by b.created_at desc;
$$;
```

## 2. Sugerencias (no bloquean al cliente)

- `exportar_mis_datos` no incluye `reports` emitidos (auditoria B5).
- Comprobar que la politica de INSERT en `reports` permite `message_id` y
  `party_id` de una previa de la que soy miembro.

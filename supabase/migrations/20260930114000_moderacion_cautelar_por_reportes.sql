-- Previa · ocultacion / bloqueo cautelar automatico tras reportes distintos.
--
-- POR QUE: sin moderacion 24h, una previa o persona reportada por varias
-- personas seguiria visible hasta que alguien la revise a mano. Al llegar a
-- 3 personas DISTINTAS con reporte abierto, se aplica una cautela:
--   * previa: deja de verse en busquedas y para extranos (la ven su anfitrion
--     y sus miembros) y nadie puede escribir en su chat.
--   * persona: no puede crear previas, pedir plaza ni escribir en chats, y sus
--     previas dejan de verse para los demas.
-- La cautela NO borra nada: es reversible por el equipo de moderacion.
--
-- DISENO: tabla nueva aparte (moderacion_cautelar) en vez de columnas en
-- profiles/parties, porque profiles es compartida con otra aplicacion y asi
-- esta migracion es 100% aditiva. La tabla no es accesible a clientes.
--
-- Umbral: 3 personas distintas con reporte 'abierto' (previa) / en 30 dias
-- (persona, solo reportes sin post_id para no contar los de la otra app).
-- Limitacion conocida: tres cuentas falsas podrian ocultar una previa ajena;
-- se mitiga con el limite de reportes y la revision posterior.

create table if not exists public.moderacion_cautelar (
  id           uuid primary key default gen_random_uuid(),
  tipo         text not null check (tipo in ('previa', 'perfil')),
  objeto_id    uuid not null,
  motivo       text not null,
  creado_en    timestamptz not null default now(),
  levantado_en timestamptz
);

-- Como maximo una cautela vigente por objeto; permite ON CONFLICT DO NOTHING.
create unique index if not exists moderacion_cautelar_vigente
  on public.moderacion_cautelar (tipo, objeto_id) where levantado_en is null;

alter table public.moderacion_cautelar enable row level security;
-- Sin politicas: RLS deniega todo a anon/authenticated. El service role la
-- salta. Ademas se retiran los privilegios para que ni exista la via.
revoke all on public.moderacion_cautelar from anon, authenticated;

-- Consulta usada por las politicas. SECURITY DEFINER porque los clientes no
-- tienen acceso a la tabla; solo devuelve un booleano.
create or replace function privado.bajo_cautela(p_tipo text, p_objeto uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.moderacion_cautelar c
     where c.tipo = p_tipo and c.objeto_id = p_objeto and c.levantado_en is null
  );
$$;
revoke all on function privado.bajo_cautela(text, uuid) from public, anon;
grant execute on function privado.bajo_cautela(text, uuid) to authenticated;

-- Disparador: cuenta reportistas distintos tras cada reporte ---------------
create or replace function privado.aplicar_cautela_por_reportes()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  c_umbral constant int := 3;
  v_n int;
begin
  if new.party_id is not null then
    select count(distinct reporter_id) into v_n
      from public.reports
     where party_id = new.party_id and status = 'abierto';
    if v_n >= c_umbral then
      insert into public.moderacion_cautelar (tipo, objeto_id, motivo)
      values ('previa', new.party_id, v_n || ' reportes distintos abiertos')
      on conflict (tipo, objeto_id) where levantado_en is null do nothing;
    end if;
  end if;

  if new.reported_id is not null and new.post_id is null then
    select count(distinct reporter_id) into v_n
      from public.reports
     where reported_id = new.reported_id and post_id is null
       and status = 'abierto' and created_at > now() - interval '30 days';
    if v_n >= c_umbral then
      insert into public.moderacion_cautelar (tipo, objeto_id, motivo)
      values ('perfil', new.reported_id, v_n || ' reportes distintos abiertos')
      on conflict (tipo, objeto_id) where levantado_en is null do nothing;
    end if;
  end if;
  return null;
end;
$$;
revoke all on function privado.aplicar_cautela_por_reportes() from public, anon, authenticated;

drop trigger if exists reports_cautela on public.reports;
create trigger reports_cautela
  after insert on public.reports
  for each row execute function privado.aplicar_cautela_por_reportes();

-- Politicas RESTRICTIVAS: se combinan con AND con las existentes, asi que solo
-- pueden quitar acceso, nunca darlo. No se toca ninguna politica actual.
create policy "cautela: previa oculta o anfitrion bajo cautela" on public.parties
  as restrictive for select to authenticated
  using (
    host_id = (select auth.uid())
    or privado.es_miembro(id, (select auth.uid()))
    or (not privado.bajo_cautela('previa', id)
        and not privado.bajo_cautela('perfil', host_id))
  );

create policy "cautela: perfil bajo cautela no crea previas" on public.parties
  as restrictive for insert to authenticated
  with check (not privado.bajo_cautela('perfil', (select auth.uid())));

create policy "cautela: perfil bajo cautela no pide plaza" on public.join_requests
  as restrictive for insert to authenticated
  with check (not privado.bajo_cautela('perfil', (select auth.uid())));

create policy "cautela: sin chat en previa o perfil bajo cautela" on public.messages
  as restrictive for insert to authenticated
  with check (not privado.bajo_cautela('perfil', (select auth.uid()))
              and not privado.bajo_cautela('previa', party_id));

-- Revision de reportes: SOLO service role ------------------------------------
-- security_invoker: la vista se ejecuta con los permisos de quien consulta, asi
-- no es una puerta trasera a las tablas. Sin privilegios para anon/authenticated.
create or replace view public.revision_reportes
with (security_invoker = true) as
select r.id,
       r.created_at,
       r.status,
       r.reason,
       r.details,
       rp.username  as reportante,
       rd.username  as reportado,
       r.reported_id,
       r.party_id,
       f.title      as previa_titulo,
       m.body       as mensaje,
       r.post_id,
       (select count(distinct r2.reporter_id)
          from public.reports r2
         where r2.status = 'abierto'
           and ((r.party_id is not null and r2.party_id = r.party_id)
             or (r.reported_id is not null and r2.reported_id = r.reported_id))) as reportantes_distintos_abiertos,
       (r.party_id is not null and privado.bajo_cautela('previa', r.party_id)) as previa_bajo_cautela,
       (r.reported_id is not null and privado.bajo_cautela('perfil', r.reported_id)) as perfil_bajo_cautela
  from public.reports r
  left join public.profiles rp on rp.id = r.reporter_id
  left join public.profiles rd on rd.id = r.reported_id
  left join public.parties  f  on f.id  = r.party_id
  left join public.messages m  on m.id  = r.message_id
 order by (r.status = 'abierto') desc, r.created_at desc;

revoke all on public.revision_reportes from public, anon, authenticated;
grant select on public.revision_reportes to service_role;

-- Levantar cautela (revision humana): cierra tambien los reportes abiertos
-- para que no vuelvan a disparar la cautela al instante.
create or replace function public.levantar_cautela(p_tipo text, p_objeto uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  update public.moderacion_cautelar
     set levantado_en = now()
   where tipo = p_tipo and objeto_id = p_objeto and levantado_en is null;

  update public.reports set status = 'revisado'
   where status = 'abierto'
     and ((p_tipo = 'previa' and party_id = p_objeto)
       or (p_tipo = 'perfil' and reported_id = p_objeto and post_id is null));
end;
$$;
revoke all on function public.levantar_cautela(text, uuid) from public, anon, authenticated;
grant execute on function public.levantar_cautela(text, uuid) to service_role;

-- Cautela manual (p. ej. un caso grave con un solo reporte).
create or replace function public.poner_cautela(p_tipo text, p_objeto uuid, p_motivo text)
returns void
language sql security definer set search_path = ''
as $$
  insert into public.moderacion_cautelar (tipo, objeto_id, motivo)
  values (p_tipo, p_objeto, coalesce(p_motivo, 'manual'))
  on conflict (tipo, objeto_id) where levantado_en is null do nothing;
$$;
revoke all on function public.poner_cautela(text, uuid, text) from public, anon, authenticated;
grant execute on function public.poner_cautela(text, uuid, text) to service_role;

-- Previa · Migracion 9
-- Correccion detectada por la bateria de pruebas.
--
-- Al revocar EXECUTE sobre difuminar_ubicacion, la creacion de previas dejo
-- de funcionar: el disparador fijar_ubicacion_difuminada es SECURITY INVOKER,
-- asi que llamaba a difuminar_ubicacion con los privilegios del usuario, que
-- ya no los tenia.
--
-- Una funcion de disparador no necesita EXECUTE para dispararse, pero las
-- funciones que ella llama si se comprueban.
--
-- Arreglo: difuminar_ubicacion pasa al esquema privado y el disparador se
-- marca SECURITY DEFINER, de modo que se ejecuta como propietario.

create or replace function privado.difuminar_ubicacion(
  p_punto   extensions.geography,
  p_radio_m double precision default 300
)
returns extensions.geography
language plpgsql
volatile
set search_path = public, extensions
as $$
declare
  v_angulo    double precision := random() * 2 * pi();
  v_distancia double precision := sqrt(random()) * p_radio_m;
begin
  return extensions.ST_Project(p_punto, v_distancia, v_angulo);
end;
$$;

revoke all on function privado.difuminar_ubicacion(extensions.geography, double precision)
  from public, anon, authenticated;

create or replace function public.fijar_ubicacion_difuminada()
returns trigger
language plpgsql
security definer
set search_path = public, privado
as $$
begin
  if tg_op = 'INSERT' or new.location is distinct from old.location then
    new.location_fuzzed := privado.difuminar_ubicacion(new.location, 300);
  end if;
  return new;
end;
$$;

revoke all on function public.fijar_ubicacion_difuminada() from public, anon, authenticated;

drop function public.difuminar_ubicacion(extensions.geography, double precision);

-- caducar_previas la ejecuta una tarea programada como postgres,
-- nunca el cliente.
revoke all on function public.caducar_previas() from public, anon, authenticated;

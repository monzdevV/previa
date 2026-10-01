-- Previa · la fecha de nacimiento no se puede borrar ni cambiar tras fijarse.
--
-- POR QUE: la barrera de mayoria de edad (validar_mayoria_de_edad) solo mira el
-- valor nuevo. Un menor podia registrarse con una fecha falsa y luego ponerla a
-- NULL (perfil "sin completar") o cambiarla, o un adulto cambiarla a voluntad.
--
-- Reglas:
--   * NULL -> fecha   permitido (onboarding de quien se registro con Google).
--   * fecha -> otra o NULL   prohibido para cualquier sesion de usuario.
--   * Cambio controlado: solo con auth.uid() nulo, es decir service role o SQL
--     editor (p. ej. corregir un error tras verificar documentacion).
--   * Reescribir el mismo valor es inocuo y se admite (el cliente puede
--     reenviarlo al editar el perfil).

create or replace function public.proteger_fecha_nacimiento()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.birth_date is not null
     and new.birth_date is distinct from old.birth_date
     and auth.uid() is not null then
    raise exception 'La fecha de nacimiento no se puede modificar una vez fijada.'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$$;

revoke all on function public.proteger_fecha_nacimiento() from public, anon, authenticated;

drop trigger if exists profiles_fecha_nacimiento_fija on public.profiles;
create trigger profiles_fecha_nacimiento_fija
  before update of birth_date on public.profiles
  for each row execute function public.proteger_fecha_nacimiento();

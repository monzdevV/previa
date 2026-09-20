-- Previa · Migracion 8
-- Cierre del acceso anonimo a las funciones RPC.
--
-- PostgreSQL concede EXECUTE al pseudorrol PUBLIC al crear una funcion, y
-- anon lo hereda. Revocar "from anon" no basta: hay que revocar de PUBLIC
-- y volver a conceder solo a authenticated.

revoke all on function public.previas_cerca(double precision, double precision, integer, integer, smallint) from public;
revoke all on function public.ubicacion_exacta(uuid)   from public;
revoke all on function public.mi_fecha_nacimiento()    from public;
revoke all on function public.exportar_mis_datos()     from public;
revoke all on function public.eliminar_mi_cuenta()     from public;
revoke all on function public.edad(uuid)               from public;

revoke all on function privado.es_miembro(uuid, uuid)   from public;
revoke all on function privado.es_anfitrion(uuid, uuid) from public;
revoke all on function privado.hay_bloqueo(uuid, uuid)  from public;
revoke all on function privado.perfil_completo(uuid)    from public;

grant execute on function public.previas_cerca(double precision, double precision, integer, integer, smallint) to authenticated;
grant execute on function public.ubicacion_exacta(uuid)   to authenticated;
grant execute on function public.mi_fecha_nacimiento()    to authenticated;
grant execute on function public.exportar_mis_datos()     to authenticated;
grant execute on function public.eliminar_mi_cuenta()     to authenticated;
grant execute on function public.edad(uuid)               to authenticated;

grant execute on function privado.es_miembro(uuid, uuid)   to authenticated;
grant execute on function privado.es_anfitrion(uuid, uuid) to authenticated;
grant execute on function privado.hay_bloqueo(uuid, uuid)  to authenticated;
grant execute on function privado.perfil_completo(uuid)    to authenticated;

-- Estas cinco siguen figurando como ejecutables por authenticated, y es
-- intencionado: son la API publica de la aplicacion. Cada una valida por su
-- cuenta quien llama (auth.uid()) antes de devolver nada.
comment on function public.ubicacion_exacta(uuid) is
  'API. SECURITY DEFINER deliberado: comprueba la pertenencia antes de revelar la direccion exacta.';
comment on function public.exportar_mis_datos() is
  'API. RGPD art. 15 y 20. Solo devuelve datos de auth.uid().';
comment on function public.eliminar_mi_cuenta() is
  'API. RGPD art. 17. Solo borra la cuenta de auth.uid().';
comment on function public.mi_fecha_nacimiento() is
  'API. Unica via para que el titular lea su propia fecha de nacimiento.';
comment on function public.edad(uuid) is
  'API. Expone la edad en anos, nunca la fecha de nacimiento.';

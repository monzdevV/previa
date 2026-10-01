-- Previa · corrige los permisos de la vista de revision de reportes.
--
-- POR QUE: revision_reportes es una vista security_invoker, asi que se ejecuta
-- con los permisos de service_role. Usa privado.bajo_cautela(), cuyo EXECUTE se
-- habia retirado de PUBLIC, y service_role no lo tenia: la consulta fallaba.
-- Se concede solo a service_role (y ya estaba concedido a authenticated para
-- las politicas RLS). anon sigue sin acceso.

grant execute on function privado.bajo_cautela(text, uuid) to service_role;
grant usage on schema privado to service_role;

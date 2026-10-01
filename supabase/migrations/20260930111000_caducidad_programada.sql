-- Previa · caducar_previas() programada con pg_cron.
--
-- POR QUE: el RGPD (limitacion del plazo) y la promesa de la app exigen que las
-- previas pasadas se cierren y se borren solas. Sin programacion, la funcion
-- existia pero nadie la llamaba.
--
-- Idempotente: pg_cron ya estaba instalado y ya existia un job con este nombre.
-- cron.schedule(nombre, ...) ACTUALIZA el job si el nombre existe, asi que
-- reaplicar esta migracion no duplica nada. Se ejecuta cada hora, al minuto 7
-- (evita el pico del minuto 0, en el que coinciden muchos jobs).

create extension if not exists pg_cron;

select cron.schedule(
  'caducar-previas',
  '7 * * * *',
  $$select public.caducar_previas()$$
);

-- La funcion solo la debe ejecutar el planificador (rol postgres), nunca un cliente.
revoke all on function public.caducar_previas() from public, anon, authenticated;

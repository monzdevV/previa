-- Aviso nuevo para el minijuego "No hay huevos".
--
-- Va en su propia migracion porque Postgres no deja usar un valor de enum en
-- la misma transaccion que lo crea, y la migracion siguiente ya lo usa.
alter type public.notice_kind add value if not exists 'reto';

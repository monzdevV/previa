-- Previa · politica explicita "denegar todo" en moderacion_cautelar.
--
-- POR QUE: la tabla tenia RLS activada sin politicas (deniega todo de forma
-- implicita) y el asesor de seguridad lo marca como INFO por si fuese un olvido.
-- Una politica USING (false) deja escrito que es intencionado. No cambia el
-- comportamiento: el service role sigue saltandose RLS.

create policy "solo el service role gestiona cautelas" on public.moderacion_cautelar
  for all to anon, authenticated
  using (false) with check (false);

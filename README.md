# Previa

Red social de proximidad para encontrar y organizar **previas** antes de salir de fiesta.

> Trabajo de Fin de Grado — 2º de DAM (Desarrollo de Aplicaciones Multiplataforma)
> Curso 2025/2026 · Entrega: junio de 2026

---

## ¿Qué problema resuelve?

Salir de fiesta empieza mucho antes de la discoteca: empieza en la previa. Pero la previa
es un circuito cerrado — quedas siempre con los mismos, y si sois pocos, se cae el plan.
Al mismo tiempo, a dos calles hay un piso con sitio de sobra buscando exactamente lo mismo.

**Previa** conecta esas dos puntas: grupos que tienen sitio y grupos que buscan plan.

## ¿Cómo funciona?

1. **Publicas o buscas.** Un grupo que tiene casa publica una previa: cuántas plazas
   libres quedan, a qué hora, qué ambiente y a qué zona de la ciudad pertenece.
2. **Exploras el mapa.** Ves las previas abiertas cerca de ti como zonas aproximadas,
   nunca como una dirección exacta.
3. **Solicitas entrar.** Pides plaza para tu grupo ("somos 3") con un mensaje breve.
4. **El anfitrión decide.** Si acepta, se abre el chat y *solo entonces* se comparte
   la ubicación exacta.
5. **Conoces gente.** Al acabar, ambas partes se valoran. La reputación se acumula.

## Stack

| Capa | Tecnología |
|---|---|
| App móvil | Flutter (Dart) — Android e iOS con un solo código |
| Backend | Supabase (PostgreSQL + PostGIS) |
| Autenticación | Supabase Auth (email + Google) |
| Tiempo real | Supabase Realtime (chat y solicitudes) |
| Ficheros | Supabase Storage (fotos de perfil) |
| Mapa | flutter_map + OpenStreetMap |
| Notificaciones | Firebase Cloud Messaging |

## Documentación

| Documento | Contenido |
|---|---|
| [Concepto y alcance](docs/01-concepto.md) | Qué es, para quién, y qué queda fuera |
| [Arquitectura](docs/02-arquitectura.md) | Capas, decisiones técnicas y por qué |
| [Modelo de datos](docs/03-modelo-datos.md) | Tablas, relaciones y políticas de acceso |
| [Plan de desarrollo](docs/04-plan-desarrollo.md) | Fases y calendario hasta junio |
| [Seguridad y RGPD](docs/05-seguridad-y-rgpd.md) | Protección de menores, datos y moderación |

## Estado

🚧 Fase 0 — montando cimientos.
